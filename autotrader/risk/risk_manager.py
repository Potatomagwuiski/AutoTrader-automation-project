"""
Master Risk Management & Circuit Breaker Engine.
Monitors daily drawdown, total drawdown, consecutive losses, and position limits.
"""

from datetime import datetime, date
from pydantic import BaseModel
from autotrader.config.risk_params import RiskParameters, risk_params
from autotrader.strategies.base import Signal
from autotrader.risk.position_sizer import PositionSizer
from autotrader.telemetry.logger import log, console

class RiskCheckResult(BaseModel):
    approved: bool
    shares: int = 0
    reason: str

class RiskManager:
    def __init__(self, params: RiskParameters | None = None):
        self.params = params or risk_params
        self.position_sizer = PositionSizer(self.params.MAX_RISK_PER_TRADE_PCT)
        
        # State tracking
        self.starting_daily_equity: float = 0.0
        self.current_day: date | None = None
        self.peak_historical_equity: float = 0.0
        self.consecutive_losses: int = 0
        self.cooldown_until: datetime | None = None
        self.circuit_breaker_tripped: bool = False
        self.circuit_breaker_reason: str = ""

    def sync_account_state(self, current_equity: float, current_time: datetime) -> None:
        """Updates equity tracking, resets daily baseline at session start, and checks drawdown limits."""
        today = current_time.date()
        if self.current_day != today:
            self.current_day = today
            self.starting_daily_equity = current_equity
            # Reset daily circuit breaker on new session if total system drawdown hasn't been breached
            if not (self.peak_historical_equity > 0 and (self.peak_historical_equity - current_equity) / self.peak_historical_equity >= self.params.MAX_SYSTEM_DRAWDOWN_PCT):
                self.circuit_breaker_tripped = False
                self.circuit_breaker_reason = ""
            log.info(f"New session date: {today}. Baseline equity set to ${self.starting_daily_equity:,.2f}")

        if current_equity > self.peak_historical_equity:
            self.peak_historical_equity = current_equity

        # Daily Drawdown Circuit Breaker Check
        if self.starting_daily_equity > 0:
            daily_loss = self.starting_daily_equity - current_equity
            daily_dd_pct = daily_loss / self.starting_daily_equity
            if daily_dd_pct >= self.params.MAX_DAILY_DRAWDOWN_PCT:
                self.circuit_breaker_tripped = True
                self.circuit_breaker_reason = f"Max Daily Drawdown Reached ({daily_dd_pct:.2%} >= {self.params.MAX_DAILY_DRAWDOWN_PCT:.2%})"
                log.warning(self.circuit_breaker_reason)

        # Max Total Drawdown Circuit Breaker Check
        if self.peak_historical_equity > 0:
            total_loss = self.peak_historical_equity - current_equity
            total_dd_pct = total_loss / self.peak_historical_equity
            if total_dd_pct >= self.params.MAX_SYSTEM_DRAWDOWN_PCT:
                self.circuit_breaker_tripped = True
                self.circuit_breaker_reason = f"Max Historical Drawdown Reached ({total_dd_pct:.2%} >= {self.params.MAX_SYSTEM_DRAWDOWN_PCT:.2%})"
                log.critical(self.circuit_breaker_reason)

    def record_trade_result(self, pnl: float, exit_time: datetime) -> None:
        """Tracks consecutive losses and triggers cooldown if limit is reached."""
        if pnl < 0:
            self.consecutive_losses += 1
            log.warning(f"Trade loss recorded. Consecutive losses: {self.consecutive_losses}")
            if self.consecutive_losses >= self.params.CONSECUTIVE_LOSS_LIMIT:
                from datetime import timedelta
                self.cooldown_until = exit_time + timedelta(minutes=self.params.COOLDOWN_MINUTES)
                log.warning(f"Cooldown active until {self.cooldown_until} due to {self.consecutive_losses} consecutive losses")
        else:
            self.consecutive_losses = 0

    def evaluate_order(
        self,
        signal: Signal,
        account_equity: float,
        open_positions_count: int,
        current_time: datetime
    ) -> RiskCheckResult:
        """
        Comprehensive pre-trade risk evaluation gate.
        """
        self.sync_account_state(account_equity, current_time)

        # 1. Check Circuit Breaker
        if self.circuit_breaker_tripped:
            return RiskCheckResult(approved=False, reason=f"Trading Halted: {self.circuit_breaker_reason}")

        # 2. Check Cooldown
        if self.cooldown_until and current_time < self.cooldown_until:
            return RiskCheckResult(approved=False, reason=f"Under cooldown until {self.cooldown_until}")

        # 3. Check Max Open Positions
        if open_positions_count >= self.params.MAX_OPEN_POSITIONS:
            return RiskCheckResult(
                approved=False,
                reason=f"Max open positions reached ({open_positions_count}/{self.params.MAX_OPEN_POSITIONS})"
            )

        # 4. Sizing Calculation
        shares = self.position_sizer.calculate_shares(
            account_equity=account_equity,
            entry_price=signal.suggested_entry,
            stop_loss_price=signal.suggested_stop_loss
        )

        if shares <= 0:
            return RiskCheckResult(approved=False, reason="Calculated position size is 0 shares")

        return RiskCheckResult(
            approved=True,
            shares=shares,
            reason=f"Approved: Size {shares} shares risking max {self.params.MAX_RISK_PER_TRADE_PCT:.1%}"
        )
