"""
Algorithmic Position Sizer: Fixed 2 Concentrated Positions Alpha Mode.
Allocates exactly 48.5% of account equity per trade (2 concurrent positions max)
with a 3.0% cash buffer to eliminate Alpaca price-drift order rejections.
"""

from pydantic import BaseModel
from autotrader.config.risk_params import risk_params
from autotrader.telemetry.logger import log

class DynamicAccountTier(BaseModel):
    tier_name: str
    max_concurrent_positions: int
    allocation_pct_per_trade: float
    cash_buffer_pct: float
    description: str

class PositionSizer:
    def __init__(
        self,
        max_risk_pct: float = risk_params.MAX_RISK_PER_TRADE_PCT,
        fixed_two_positions: bool = True
    ):
        self.max_risk_pct = max_risk_pct
        self.fixed_two_positions = fixed_two_positions

    def get_dynamic_account_tier(self, account_equity: float) -> DynamicAccountTier:
        """
        Fixed 2-Position Alpha Mode:
        Allocates 48.5% per trade across 2 non-correlated leaders with 3% cash buffer.
        """
        return DynamicAccountTier(
            tier_name="Fixed 2-Position Alpha Compounding Mode",
            max_concurrent_positions=2,
            allocation_pct_per_trade=0.485,
            cash_buffer_pct=0.03,
            description="Concentrated 2-position alpha compounding (48.5% per trade)"
        )

    def calculate_notional_dollars(self, account_equity: float) -> float:
        """Computes exact fractional dollar amount for Alpaca notional orders."""
        tier = self.get_dynamic_account_tier(account_equity)
        notional = account_equity * tier.allocation_pct_per_trade
        log.debug(f"Position Sizer [{tier.tier_name}]: Equity=${account_equity:,.2f} -> Allocated ${notional:,.2f}/trade")
        return round(notional, 2)

    def calculate_shares(
        self,
        account_equity: float,
        entry_price: float,
        stop_loss_price: float,
        max_position_notional_pct: float | None = None
    ) -> int:
        """
        Computes integer number of shares based on 2-position allocation.
        """
        if account_equity <= 0 or entry_price <= 0 or stop_loss_price >= entry_price:
            return 0

        risk_per_share = entry_price - stop_loss_price
        if risk_per_share <= 0:
            return 0

        risk_dollar_amount = account_equity * self.max_risk_pct
        shares_by_risk = int(risk_dollar_amount / risk_per_share)

        tier = self.get_dynamic_account_tier(account_equity)
        alloc_pct = max_position_notional_pct if max_position_notional_pct is not None else tier.allocation_pct_per_trade
        max_notional = account_equity * alloc_pct
        shares_by_notional = int(max_notional / entry_price)
        # Must never exceed either the risk budget (1% equity) OR the notional allocation (48.5% equity)
        final_shares = min(shares_by_risk, shares_by_notional)
        return max(0, final_shares)
