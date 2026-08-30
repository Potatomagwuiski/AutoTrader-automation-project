"""
Stage 1 Filter: Fundamental Health and Sector Compliance Filter.
Filters out overleveraged entities, non-compliant sectors, and financially unstable companies.
"""

from pydantic import BaseModel
from autotrader.data.base import AssetMetadata

class FundamentalFilterConfig(BaseModel):
    # Max allowed debt to market cap / assets ratio (e.g. max 33% interest debt)
    MAX_INTEREST_DEBT_RATIO: float = 0.33
    
    # Excluded prohibited business sectors (e.g. pure financial interest/usury, gambling, tobacco)
    EXCLUDED_SECTORS: list[str] = [
        "Financial Services", "Commercial Banking", "Tobacco", "Casinos & Gaming"
    ]
    
    MIN_MARKET_CAP: float = 50_000_000.0  # $50M min market cap

class FundamentalFilter:
    def __init__(self, config: FundamentalFilterConfig | None = None):
        self.config = config or FundamentalFilterConfig()

    def evaluate(self, meta: AssetMetadata) -> tuple[bool, str]:
        """
        Evaluates an asset's fundamental eligibility.
        Returns (passed: bool, reason: str).
        """
        # Check excluded sectors
        for excluded in self.config.EXCLUDED_SECTORS:
            if excluded.lower() in meta.sector.lower() or excluded.lower() in meta.industry.lower():
                return False, f"Excluded sector/industry: {meta.sector} / {meta.industry}"
                
        # Check debt ratio
        if meta.interest_bearing_debt_pct > self.config.MAX_INTEREST_DEBT_RATIO:
            return False, f"Excessive debt ratio: {meta.interest_bearing_debt_pct:.1%} > {self.config.MAX_INTEREST_DEBT_RATIO:.1%}"
            
        # Check market cap
        if meta.market_cap > 0 and meta.market_cap < self.config.MIN_MARKET_CAP:
            return False, f"Market cap too low: ${meta.market_cap:,.0f} < ${self.config.MIN_MARKET_CAP:,.0f}"

        return True, "Passed fundamental screening"
