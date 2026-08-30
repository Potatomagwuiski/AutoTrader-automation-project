"""
High-Fidelity Paper Trading and Backtest Simulation Execution Engine.
Simulates market fills with slippage, commissions, trailing stops, and profit targets.
"""

from datetime import datetime
import uuid
from autotrader.config.settings import settings
from autotrader.config.risk_params import risk_params
from autotrader.execution.base import BaseExecutionHandler
from autotrader.execution.order_types import Order, Fill, Position
from autotrader.telemetry.journal import TradeJournal, TradeRecord
from autotrader.risk.stop_loss import TrailingStopEngine, TrailingStopState
from autotrader.telemetry.logger import log, console

class PaperExecutionEngine(BaseExecutionHandler):
    def __init__(
        self,
        initial_capital: float = settings.INITIAL_CAPITAL,
        slippage_bps: float = risk_params.ESTIMATED_SLIPPAGE_BPS,
        commission_per_share: float = risk_params.ESTIMATED_COMMISSION_PER_SHARE,
        journal: TradeJournal | None = None
    ):
        self.cash = initial_capital
        self.initial_capital = initial_capital
        self.slippage_bps = slippage_bps
        self.commission_per_share = commission_per_share
        self.journal = journal or TradeJournal()
        self.trailing_stop_engine = TrailingStopEngine()

        self.positions: dict[str, Position] = {}
        self.trailing_states: dict[str, TrailingStopState] = {}
        self.closed_trades: list[TradeRecord] = []
        self.equity_history: list[tuple[datetime, float]] = []

    def get_account_equity(self) -> float:
        unrealized = sum(p.unrealized_pnl for p in self.positions.values())
        return self.cash + unrealized

    def get_open_positions(self) -> dict[str, Position]:
        return self.positions

    def _apply_slippage(self, price: float, direction: str) -> tuple[float, float]:
        """Calculates fill price with slippage (basis points)."""
        slip_pct = self.slippage_bps / 10000.0
        if direction == "BUY":
            fill_price = price * (1.0 + slip_pct)
            slippage_amount = fill_price - price
        else:
            fill_price = price * (1.0 - slip_pct)
            slippage_amount = price - fill_price
        return fill_price, slippage_amount

    def submit_order(self, order: Order) -> Fill | None:
        """Executes a market order with simulated friction."""
        if order.shares <= 0 or order.price is None or order.price <= 0:
            log.warning(f"Rejected invalid order for {order.symbol}: shares={order.shares}, price={order.price}")
            return None

        fill_price, slippage = self._apply_slippage(order.price, order.direction)
        commission = order.shares * self.commission_per_share
        total_cost = (fill_price * order.shares) + commission

        if order.direction == "BUY":
            if total_cost > self.cash:
                log.warning(f"Insufficient cash for order {order.order_id}: Needed ${total_cost:.2f}, Cash: ${self.cash:.2f}")
                return None

            self.cash -= total_cost
            fill = Fill(
                fill_id=str(uuid.uuid4())[:8],
                order_id=order.order_id,
                symbol=order.symbol,
                direction="BUY",
                shares=order.shares,
                fill_price=fill_price,
                timestamp=order.created_at,
                fee=commission,
                slippage=slippage * order.shares
            )

            stop_loss = order.stop_price or (fill_price * 0.98)
            take_profit = order.metadata.get("take_profit", fill_price * 1.04)

            pos = Position(
                symbol=order.symbol,
                direction="LONG",
                shares=order.shares,
                entry_price=fill_price,
                current_price=fill_price,
                entry_time=order.created_at,
                initial_stop_loss=stop_loss,
                current_stop_loss=stop_loss,
                take_profit=take_profit,
                strategy_name=order.strategy_name,
                highest_price=fill_price
            )
            self.positions[order.symbol] = pos
            self.trailing_states[order.symbol] = self.trailing_stop_engine.initialize_state(
                symbol=order.symbol, entry_price=fill_price, initial_stop=stop_loss
            )

            log.info(f"[EXEC] BOUGHT {order.shares} {order.symbol} @ ${fill_price:.2f} (Stop: ${stop_loss:.2f}, TP: ${take_profit:.2f})")
            return fill

        return None

    def update_and_check_exits(
        self,
        symbol: str,
        current_bar: dict,
        current_time: datetime,
        current_atr: float = 1.0
    ) -> TradeRecord | None:
        """
        Updates open position with current bar OHLC and checks for Stop Loss, Take Profit, or Trailing Stop triggers.
        """
        if symbol not in self.positions:
            return None

        pos = self.positions[symbol]
        high = float(current_bar["high"])
        low = float(current_bar["low"])
        close = float(current_bar["close"])

        # Update position market price
        pos.update_market_price(close)

        # Update trailing stop state
        if symbol in self.trailing_states:
            state, moved = self.trailing_stop_engine.update_stop(
                self.trailing_states[symbol], current_price=high, current_atr=current_atr
            )
            pos.current_stop_loss = state.current_stop

        # Check Take Profit
        if high >= pos.take_profit:
            return self._close_position_internal(
                symbol=symbol,
                exit_price=pos.take_profit,
                exit_time=current_time,
                reason="TAKE_PROFIT"
            )

        # Check Stop Loss / Trailing Stop
        if low <= pos.current_stop_loss:
            reason = "TRAILING_STOP" if pos.current_stop_loss > pos.initial_stop_loss else "STOP_LOSS"
            return self._close_position_internal(
                symbol=symbol,
                exit_price=pos.current_stop_loss,
                exit_time=current_time,
                reason=reason
            )

        return None

    def close_position(self, symbol: str, reason: str = "MANUAL_OR_TIME_LIMIT") -> Fill | None:
        """Closes position at current market price."""
        if symbol not in self.positions:
            return None
        pos = self.positions[symbol]
        record = self._close_position_internal(
            symbol=symbol,
            exit_price=pos.current_price,
            exit_time=datetime.now(),
            reason=reason
        )
        return None

    def _close_position_internal(
        self,
        symbol: str,
        exit_price: float,
        exit_time: datetime,
        reason: str
    ) -> TradeRecord:
        pos = self.positions.pop(symbol)
        self.trailing_states.pop(symbol, None)

        fill_price, slippage = self._apply_slippage(exit_price, "SELL")
        commission = pos.shares * self.commission_per_share
        proceeds = (fill_price * pos.shares) - commission
        self.cash += proceeds

        realized_pnl = proceeds - (pos.entry_price * pos.shares)
        realized_return_pct = (fill_price - pos.entry_price) / pos.entry_price
        
        # 1R calculation
        risk_per_share = max(pos.entry_price - pos.initial_stop_loss, 0.01)
        r_multiple = (fill_price - pos.entry_price) / risk_per_share

        trade_record = TradeRecord(
            trade_id=str(uuid.uuid4())[:8],
            symbol=symbol,
            direction="LONG",
            strategy_name=pos.strategy_name,
            entry_time=pos.entry_time,
            exit_time=exit_time,
            entry_price=pos.entry_price,
            exit_price=fill_price,
            shares=pos.shares,
            initial_stop_loss=pos.initial_stop_loss,
            initial_take_profit=pos.take_profit,
            realized_pnl=realized_pnl,
            realized_return_pct=realized_return_pct,
            r_multiple=r_multiple,
            exit_reason=reason,
            fees=commission * 2,
            slippage=slippage * pos.shares
        )

        self.closed_trades.append(trade_record)
        self.journal.record_trade(trade_record)
        log.info(
            f"[EXIT] CLOSED {pos.shares} {symbol} @ ${fill_price:.2f} | Reason: {reason} | PnL: ${realized_pnl:.2f} ({r_multiple:.2f}R)"
        )
        return trade_record
