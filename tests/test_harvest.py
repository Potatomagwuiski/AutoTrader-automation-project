import pytest
from autotrader.risk.harvest_manager import ProfitHarvestAdvisor

def test_profit_harvest_tier1():
    advisor = ProfitHarvestAdvisor()
    # At $500k -> Tier 1 ($80k salary)
    decision = advisor.evaluate_harvest(current_equity=500000.0, withdrawn_ytd=0.0)
    assert decision.current_tier_name == "Tier 1: Foundation Freedom"
    assert decision.annual_salary_target == 80000.0
    assert decision.recommended_harvest_amount == 80000.0

def test_profit_harvest_tier2_scaling():
    advisor = ProfitHarvestAdvisor()
    # At $1,000,000 -> Auto-scales to Tier 2 ($150k salary)
    decision = advisor.evaluate_harvest(current_equity=1000000.0, withdrawn_ytd=0.0)
    assert decision.current_tier_name == "Tier 2: Millionaire Status"
    assert decision.annual_salary_target == 150000.0
    assert decision.recommended_harvest_amount == 150000.0
    assert decision.next_tier_name == "Tier 3: Multi-Millionaire"

def test_profit_harvest_tier3_scaling():
    advisor = ProfitHarvestAdvisor()
    # At $2.5M -> Auto-scales to Tier 3 ($300k salary)
    decision = advisor.evaluate_harvest(current_equity=2500000.0, withdrawn_ytd=0.0)
    assert decision.current_tier_name == "Tier 3: Multi-Millionaire"
    assert decision.annual_salary_target == 300000.0
    assert decision.recommended_harvest_amount == 300000.0
