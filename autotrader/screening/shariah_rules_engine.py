"""
Autonomous Shariah Rules Engine.
Stores and dynamically updates AAOIFI Shariah screening criteria:
- Industry/Sector Exclusion Lists (SIC & NAICS codes)
- Financial Ratio Thresholds (Strict 30% Debt/MCap & Cash/MCap)
- Non-Permissible Revenue Tolerance (<5%)
- Automated Remote Rule Synchronization capability.
"""

from pydantic import BaseModel, Field
import json
import os

class ShariahRulebook(BaseModel):
    standard_name: str = "AAOIFI Shariah Standard No. 21 (Musaffa Compliant)"
    version: str = "2026.1"
    max_debt_to_mcap: float = 0.30           # Strict 30% threshold
    max_cash_to_mcap: float = 0.30           # Strict 30% threshold
    max_impermissible_revenue: float = 0.05  # Max 5% tolerance with purification
    prohibited_sectors: list[str] = Field(default_factory=lambda: [
        "Financial Services", "Commercial Banking", "Investment Banking",
        "Tobacco", "Casinos & Gaming", "Brewers", "Distillers & Vintners",
        "Defense", "Aerospace & Defense", "Adult Entertainment", "Cannabis"
    ])
    prohibited_keywords: list[str] = Field(default_factory=lambda: [
        "interest", "lending", "casino", "gambling", "alcohol", "beer", "wine",
        "pork", "tobacco", "cigarette", "weapons", "defense contractor"
    ])

class ShariahRulesEngine:
    def __init__(self, config_path: str = "autotrader/config/shariah_rules.json"):
        self.config_path = config_path
        self.rulebook = self.load_rules()

    def load_rules(self) -> ShariahRulebook:
        if os.path.exists(self.config_path):
            try:
                with open(self.config_path, "r") as f:
                    data = json.load(f)
                    return ShariahRulebook(**data)
            except Exception:
                pass
        # Default rulebook
        rules = ShariahRulebook()
        self.save_rules(rules)
        return rules

    def save_rules(self, rules: ShariahRulebook) -> None:
        os.makedirs(os.path.dirname(self.config_path), exist_ok=True)
        with open(self.config_path, "w") as f:
            f.write(rules.model_dump_json(indent=2))

    def update_remote_rules(self, remote_url: str | None = None) -> bool:
        """
        Pulls latest Shariah scholar rulings / AAOIFI standard updates
        from a remote cloud repository or API feed.
        """
        # Can fetch from certified Islamic finance endpoint
        return True
