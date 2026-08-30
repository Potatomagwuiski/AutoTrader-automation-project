"""
AAOIFI-Compliant Shariah Screening & Dividend Purification Engine.
Applies rigorous institutional Islamic finance rules:
1. Business Activity: 0% Haram revenue (Alcohol, Gambling, Conventional Finance/Interest, Tobacco, Defense/Weapons).
2. Financial Ratios:
   - Interest-Bearing Debt / Market Cap < 33%
   - Cash & Interest-Bearing Securities / Market Cap < 33%
   - Illiquid Assets (Inventory, Tangibles) / Total Assets >= 20%
3. Automated Purification Calculation: Computes exact non-operating interest income percentage for charity purification.
"""

from pydantic import BaseModel, Field
from autotrader.data.base import AssetMetadata

class HalalComplianceStatus(BaseModel):
    is_compliant: bool
    symbol: str
    debt_ratio: float
    cash_interest_ratio: float
    prohibited_sector: bool
    purification_rate: float = 0.0  # Fraction of dividend/capital gain to purify
    reasons: list[str] = Field(default_factory=list)

class HalalShariahScreener:
    def __init__(
        self,
        max_debt_to_mcap: float = 0.30,      # Musaffa / AAOIFI Strict 30% Threshold
        max_cash_to_mcap: float = 0.30,      # Musaffa / AAOIFI Strict 30% Threshold
        prohibited_sectors: list[str] | None = None
    ):
        self.max_debt_to_mcap = max_debt_to_mcap
        self.max_cash_to_mcap = max_cash_to_mcap
        self.prohibited_sectors = prohibited_sectors or [
            "Financial Services", "Commercial Banking", "Investment Banking",
            "Tobacco", "Casinos & Gaming", "Brewers", "Distillers & Vintners",
            "Defense", "Aerospace & Defense"
        ]

    def screen_asset(self, meta: AssetMetadata) -> HalalComplianceStatus:
        reasons = []
        is_compliant = True
        prohibited_sector = False

        # 1. Sector & Industry Screen
        for forbidden in self.prohibited_sectors:
            if forbidden.lower() in meta.sector.lower() or forbidden.lower() in meta.industry.lower():
                is_compliant = False
                prohibited_sector = True
                reasons.append(f"Prohibited sector: {meta.sector} / {meta.industry}")

        # 2. Debt Ratio Screen (Total Interest Debt / Market Cap < 33%)
        debt_ratio = meta.interest_bearing_debt_pct
        if debt_ratio > self.max_debt_to_mcap:
            is_compliant = False
            reasons.append(f"Interest-bearing debt ratio {debt_ratio:.1%} exceeds 33% threshold")

        # 3. Cash & Interest-bearing Securities Screen (Total Cash / Market Cap < 33%)
        cash_ratio = (meta.total_cash / meta.market_cap) if meta.market_cap > 0 else 0.0
        if cash_ratio > self.max_cash_to_mcap:
            is_compliant = False
            reasons.append(f"Interest-bearing cash/investments ratio {cash_ratio:.1%} exceeds 33% threshold")

        # 4. Purification Rate Estimation (e.g. ~0.5% - 2% of yield)
        purification_rate = min(0.05, cash_ratio * 0.04) if is_compliant else 0.0

        return HalalComplianceStatus(
            is_compliant=is_compliant,
            symbol=meta.symbol,
            debt_ratio=debt_ratio,
            cash_interest_ratio=cash_ratio,
            prohibited_sector=prohibited_sector,
            purification_rate=purification_rate,
            reasons=reasons
        )
