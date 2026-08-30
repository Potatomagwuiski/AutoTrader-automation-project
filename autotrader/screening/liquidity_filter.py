"""
Stage 2 Filter: Liquidity, Float, and Price Safety Sieve.
Prevents sub-dollar slippage traps, illiquid order books, and micro-float pump-and-dumps.
"""

from pydantic import BaseModel
from autotrader.data.base import AssetMetadata

class LiquidityFilterConfig(BaseModel):
    MIN_PRICE: float = 1.00          # Rule: Price must be at least $1.00
    MAX_PRICE: float = 1000.00
    MIN_FLOAT: float = 20_000_000.0  # Rule: Float >= 20M shares to avoid illiquid whipsaws
    MIN_AVG_DAILY_VOLUME: float = 500_000.0  # 500k shares/day

class LiquidityFilter:
    def __init__(self, config: LiquidityFilterConfig | None = None):
        self.config = config or LiquidityFilterConfig()

    def evaluate(self, meta: AssetMetadata) -> tuple[bool, str]:
        """
        Evaluates liquidity, float, and price criteria.
        Returns (passed: bool, reason: str).
        """
        # Price constraint
        if meta.current_price < self.config.MIN_PRICE:
            return False, f"Price below ${self.config.MIN_PRICE:.2f} threshold: ${meta.current_price:.2f}"
            
        if meta.current_price > self.config.MAX_PRICE:
            return False, f"Price above ${self.config.MAX_PRICE:.2f} ceiling"

        # Float constraint
        if 0 < meta.shares_float < self.config.MIN_FLOAT:
            return False, f"Float too low ({meta.shares_float:,.0f} < {self.config.MIN_FLOAT:,.0f})"

        # Average volume constraint
        if 0 < meta.avg_daily_volume < self.config.MIN_AVG_DAILY_VOLUME:
            return False, f"Average daily volume too low ({meta.avg_daily_volume:,.0f} < {self.config.MIN_AVG_DAILY_VOLUME:,.0f})"

        return True, "Passed liquidity and float requirements"
