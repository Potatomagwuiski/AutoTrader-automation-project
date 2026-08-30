"""
Tests for Multi-Stage Screening Pipeline and Shariah Compliance Engine.
"""

import pandas as pd
import numpy as np
from autotrader.data.base import AssetMetadata
from autotrader.screening.fundamental_filter import FundamentalFilter
from autotrader.screening.liquidity_filter import LiquidityFilter
from autotrader.screening.rvol_scanner import RVOLScanner, RVOLScannerConfig
from autotrader.screening.shariah_rules_engine import ShariahRulesEngine
from autotrader.screening.shariah_compliance_daemon import ShariahComplianceDaemon

def test_fundamental_filter():
    ff = FundamentalFilter()
    
    # Compliant asset
    good_meta = AssetMetadata(
        symbol="NVDA",
        sector="Technology",
        industry="Semiconductors",
        market_cap=2_000_000_000_000.0,
        shares_float=2_400_000_000.0,
        total_debt=10_000_000_000.0,
        interest_bearing_debt_pct=0.005,
        current_price=120.0
    )
    passed, reason = ff.evaluate(good_meta)
    assert passed is True

    # High debt asset (fails)
    bad_debt_meta = good_meta.model_copy(update={"interest_bearing_debt_pct": 0.45})
    passed, reason = ff.evaluate(bad_debt_meta)
    assert passed is False
    assert "Excessive debt ratio" in reason

    # Excluded sector asset (fails)
    bad_sector_meta = good_meta.model_copy(update={"sector": "Commercial Banking"})
    passed, reason = ff.evaluate(bad_sector_meta)
    assert passed is False
    assert "Excluded sector" in reason

def test_liquidity_filter():
    lf = LiquidityFilter()

    good_meta = AssetMetadata(
        symbol="AAPL",
        sector="Technology",
        industry="Consumer Electronics",
        market_cap=3_000_000_000_000.0,
        shares_float=15_000_000_000.0,
        total_debt=100_000_000_000.0,
        interest_bearing_debt_pct=0.03,
        current_price=220.0
    )
    passed, _ = lf.evaluate(good_meta)
    assert passed is True

    # Sub-dollar asset (fails)
    penny_meta = good_meta.model_copy(update={"current_price": 0.85})
    passed, reason = lf.evaluate(penny_meta)
    assert passed is False
    assert "Price below" in reason

    # Float below 20M (fails)
    low_float_meta = good_meta.model_copy(update={"shares_float": 5_000_000.0})
    passed, reason = lf.evaluate(low_float_meta)
    assert passed is False
    assert "Float too low" in reason

def test_rvol_scanner():
    scanner = RVOLScanner(RVOLScannerConfig(MIN_RVOL=3.0))

    # Generate synthetic OHLCV with a 4.5x volume spike at the end
    n_bars = 40
    data = {
        "open": np.linspace(100, 105, n_bars),
        "high": np.linspace(101, 107, n_bars),
        "low": np.linspace(99, 104, n_bars),
        "close": np.linspace(100.5, 106.5, n_bars),
        "volume": [1000.0] * (n_bars - 1) + [4500.0]  # 4.5x surge
    }
    df = pd.DataFrame(data)
    
    passed, rvol_val, reason = scanner.evaluate(df)
    assert passed is True
    assert rvol_val >= 3.0
    assert "High Institutional RVOL" in reason

def test_shariah_rules_engine_and_daemon():
    engine = ShariahRulesEngine()
    assert engine.rulebook.max_debt_to_mcap == 0.30
    assert "Commercial Banking" in engine.rulebook.prohibited_sectors

    class MockProvider:
        def fetch_asset_metadata(self, symbol: str) -> AssetMetadata:
            return AssetMetadata(
                symbol=symbol,
                sector="Technology",
                industry="Semiconductors",
                market_cap=2_000_000_000_000.0,
                shares_float=2_400_000_000.0,
                total_debt=10_000_000_000.0,
                interest_bearing_debt_pct=0.005,
                current_price=120.0
            )

    provider = MockProvider()
    daemon = ShariahComplianceDaemon(data_provider=provider)
    status = daemon.audit_single_asset("NVDA")
    assert status.is_compliant is True

