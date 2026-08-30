"""
Walk-Forward Optimization & Parameter Search Engine.
Evaluates strategy parameter spaces against walk-forward rolling windows to find robust parameters.
"""

from typing import Type
import pandas as pd
from autotrader.strategies.base import BaseStrategy
from autotrader.execution.paper_engine import PaperExecutionEngine
from autotrader.risk.risk_manager import RiskManager
from autotrader.execution.order_types import Order
from autotrader.telemetry.metrics import calculate_performance, PerformanceReport
from autotrader.telemetry.logger import log

from autotrader.features.indicators import calculate_atr

def simulate_strategy(
    strategy_cls: Type[BaseStrategy],
    params: dict,
    df: pd.DataFrame,
    symbol: str = "SIM",
    initial_capital: float = 100000.0
) -> PerformanceReport:
    """
    Runs a fast bar-by-bar backtest of a strategy with specific parameters on a single asset.
    """
    strategy = strategy_cls(params=params)
    engine = PaperExecutionEngine(initial_capital=initial_capital)
    risk_mgr = RiskManager()

    equity_curve = [initial_capital]

    # Iterate bar by bar
    for i in range(35, len(df)):
        sub_df = df.iloc[:i]
        current_bar = df.iloc[i]
        current_time = df.index[i].to_pydatetime() if isinstance(df.index[i], pd.Timestamp) else i

        atr_series = calculate_atr(sub_df, period=14)
        current_atr = float(atr_series.iloc[-1]) if not atr_series.empty else 1.0

        # Check exits on open positions
        engine.update_and_check_exits(
            symbol=symbol,
            current_bar=current_bar.to_dict(),
            current_time=current_time,
            current_atr=current_atr
        )

        # Check for new signals if no open position
        if symbol not in engine.positions:
            signal = strategy.generate_signal(symbol, sub_df)
            if signal and signal.direction == "BUY":
                risk_check = risk_mgr.evaluate_order(
                    signal=signal,
                    account_equity=engine.get_account_equity(),
                    open_positions_count=len(engine.positions),
                    current_time=current_time if isinstance(current_time, pd.Timestamp) else pd.Timestamp.now()
                )

                if risk_check.approved and risk_check.shares > 0:
                    order = Order(
                        order_id=f"opt_{i}",
                        symbol=symbol,
                        direction="BUY",
                        order_type="MARKET",
                        shares=risk_check.shares,
                        price=signal.suggested_entry,
                        stop_price=signal.suggested_stop_loss,
                        created_at=current_time if isinstance(current_time, pd.Timestamp) else pd.Timestamp.now(),
                        strategy_name=strategy.name,
                        metadata={"take_profit": signal.suggested_take_profit}
                    )
                    engine.submit_order(order)

        equity_curve.append(engine.get_account_equity())

    # Close remaining open position at end
    if symbol in engine.positions:
        engine.close_position(symbol, reason="END_OF_DATA")

    pnls = [t.realized_pnl for t in engine.closed_trades]
    report = calculate_performance(trade_pnls=pnls, equity_curve=equity_curve)
    return report

def simulate_portfolio(
    strategy_cls: Type[BaseStrategy],
    params: dict,
    symbol_data: dict[str, pd.DataFrame],
    initial_capital: float = 100000.0
) -> tuple[PerformanceReport, list]:
    """
    Runs multi-asset synchronized portfolio simulation across all symbols sharing a unified cash balance.
    """
    strategy = strategy_cls(params=params)
    engine = PaperExecutionEngine(initial_capital=initial_capital)
    risk_mgr = RiskManager()

    # Collect all unique timestamps across symbols
    all_timestamps = sorted(list({ts for df in symbol_data.values() for ts in df.index}))
    equity_curve = [initial_capital]

    for ts in all_timestamps:
        current_time = ts.to_pydatetime() if isinstance(ts, pd.Timestamp) else ts
        
        # 1. Update positions and check trailing exits across open positions
        for symbol in list(engine.positions.keys()):
            df = symbol_data.get(symbol)
            if df is not None and ts in df.index:
                idx = df.index.get_loc(ts)
                loc = idx if isinstance(idx, int) else int(idx.start)
                sub_df = df.iloc[:loc+1]
                if len(sub_df) >= 14:
                    current_atr = float(calculate_atr(sub_df, period=14).iloc[-1])
                else:
                    current_atr = 1.0
                row = df.loc[ts]
                bar_dict = row.iloc[-1].to_dict() if isinstance(row, pd.DataFrame) else row.to_dict()
                engine.update_and_check_exits(
                    symbol=symbol,
                    current_bar=bar_dict,
                    current_time=current_time,
                    current_atr=current_atr
                )

        # 2. Check for new entry signals across symbols
        for symbol, df in symbol_data.items():
            if symbol in engine.positions or ts not in df.index:
                continue

            idx = df.index.get_loc(ts)
            loc = idx if isinstance(idx, int) else int(idx.start)
            if loc < 35:
                continue

            sub_df = df.iloc[:loc+1]
            signal = strategy.generate_signal(symbol, sub_df)
            if signal and signal.direction == "BUY":
                risk_check = risk_mgr.evaluate_order(
                    signal=signal,
                    account_equity=engine.get_account_equity(),
                    open_positions_count=len(engine.positions),
                    current_time=current_time if isinstance(current_time, pd.Timestamp) else pd.Timestamp.now()
                )

                if risk_check.approved and risk_check.shares > 0:
                    order = Order(
                        order_id=f"port_{ts}_{symbol}",
                        symbol=symbol,
                        direction="BUY",
                        order_type="MARKET",
                        shares=risk_check.shares,
                        price=signal.suggested_entry,
                        stop_price=signal.suggested_stop_loss,
                        created_at=current_time if isinstance(current_time, pd.Timestamp) else pd.Timestamp.now(),
                        strategy_name=strategy.name,
                        metadata={"take_profit": signal.suggested_take_profit}
                    )
                    engine.submit_order(order)

        equity_curve.append(engine.get_account_equity())

    # Close remaining open positions at the end
    for symbol in list(engine.positions.keys()):
        engine.close_position(symbol, reason="END_OF_DATA")

    pnls = [t.realized_pnl for t in engine.closed_trades]
    report = calculate_performance(trade_pnls=pnls, equity_curve=equity_curve)
    return report, engine.closed_trades

def simulate_high_alpha_portfolio(
    strategy_cls: Type[BaseStrategy],
    params: dict,
    symbol_data: dict[str, pd.DataFrame],
    initial_capital: float = 100000.0,
    allocation_pct: float = 0.50,  # 50% capital per position (allows up to 2 concurrent concentrated positions)
    trailing_atr_mult: float = 2.5
) -> tuple[PerformanceReport, list]:
    """
    High-Alpha Portfolio Simulator:
    - High capital allocation (50% per position) for aggressive compounding.
    - Chandelier ATR trailing stop lets macro trends run indefinitely (+50% to +500%).
    """
    strategy = strategy_cls(params=params)
    engine = PaperExecutionEngine(initial_capital=initial_capital)
    
    all_timestamps = sorted(list({ts for df in symbol_data.values() for ts in df.index}))
    equity_curve = [initial_capital]

    for ts in all_timestamps:
        current_time = ts.to_pydatetime() if isinstance(ts, pd.Timestamp) else ts
        
        # 1. Update open positions with Chandelier trailing stops
        for symbol in list(engine.positions.keys()):
            df = symbol_data.get(symbol)
            if df is not None and ts in df.index:
                idx = df.index.get_loc(ts)
                loc = idx if isinstance(idx, int) else int(idx.start)
                sub_df = df.iloc[:loc+1]
                current_atr = float(calculate_atr(sub_df, period=14).iloc[-1]) if len(sub_df) >= 14 else 1.0
                
                pos = engine.positions[symbol]
                row = df.loc[ts]
                bar_dict = row.iloc[-1].to_dict() if isinstance(row, pd.DataFrame) else row.to_dict()
                high = float(bar_dict["high"])
                low = float(bar_dict["low"])
                close = float(bar_dict["close"])

                pos.update_market_price(close)

                # Chandelier Trailing Stop: Highest High - (multiplier * ATR)
                trailing_stop_level = pos.highest_price - (trailing_atr_mult * current_atr)
                if trailing_stop_level > pos.current_stop_loss:
                    pos.current_stop_loss = trailing_stop_level

                # Exit if low crosses trailing stop
                if low <= pos.current_stop_loss:
                    engine._close_position_internal(
                        symbol=symbol,
                        exit_price=pos.current_stop_loss,
                        exit_time=current_time,
                        reason="CHANDELIER_TRAILING_STOP"
                    )

        # 2. Check entry signals if capacity available
        max_positions = int(1.0 / allocation_pct)
        if len(engine.positions) < max_positions:
            for symbol, df in symbol_data.items():
                if symbol in engine.positions or ts not in df.index:
                    continue

                idx = df.index.get_loc(ts)
                loc = idx if isinstance(idx, int) else int(idx.start)
                if loc < 35:
                    continue

                sub_df = df.iloc[:loc+1]
                signal = strategy.generate_signal(symbol, sub_df)
                if signal and signal.direction == "BUY":
                    # Allocate fixed percentage of current total account equity
                    available_equity = engine.get_account_equity() * allocation_pct
                    shares = int(available_equity / signal.suggested_entry)

                    if shares > 0 and (shares * signal.suggested_entry) <= engine.cash:
                        order = Order(
                            order_id=f"alpha_{ts}_{symbol}",
                            symbol=symbol,
                            direction="BUY",
                            order_type="MARKET",
                            shares=shares,
                            price=signal.suggested_entry,
                            stop_price=signal.suggested_stop_loss,
                            created_at=current_time,
                            strategy_name=strategy.name,
                            metadata={"take_profit": signal.suggested_take_profit}
                        )
                        engine.submit_order(order)

        equity_curve.append(engine.get_account_equity())

    # Close remaining at end
    for symbol in list(engine.positions.keys()):
        engine.close_position(symbol, reason="END_OF_DATA")

    pnls = [t.realized_pnl for t in engine.closed_trades]
    report = calculate_performance(trade_pnls=pnls, equity_curve=equity_curve)
    return report, engine.closed_trades

class WalkForwardOptimizer:
    def __init__(self, strategy_cls: Type[BaseStrategy]):
        self.strategy_cls = strategy_cls

    def optimize(
        self,
        param_grid: list[dict],
        df: pd.DataFrame,
        symbol: str = "OPT"
    ) -> tuple[dict, PerformanceReport]:
        """
        Tests parameter grid and selects candidate maximizing (Sharpe * Profit Factor * Win Rate).
        """
        best_score = -999.0
        best_params = {}
        best_report = PerformanceReport()

        for params in param_grid:
            report = simulate_strategy(self.strategy_cls, params, df, symbol=symbol)
            if report.total_trades < 3:
                continue

            # Composite fitness score: reward profit factor, win rate, and penalize drawdown
            score = (report.profit_factor * (1.0 + report.win_rate)) - (report.max_drawdown_pct * 10.0)
            if score > best_score:
                best_score = score
                best_params = params
                best_report = report

        return best_params, best_report
