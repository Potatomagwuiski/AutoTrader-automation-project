"""
Tests for Market Regime Detection, Optimization, Strategy Mutation, and Canary Sandbox.
"""

import pandas as pd
import numpy as np
from autotrader.learning.regime_detector import MarketRegimeDetector
from autotrader.learning.strategy_mutator import StrategyMutator
from autotrader.learning.canary_sandbox import CanarySandbox, CanaryPromotionHurdles
from autotrader.strategies.momentum_breakout import MomentumBreakoutStrategy

def test_market_regime_detector():
    detector = MarketRegimeDetector()

    # Generate Bull Trend Data
    n_bars = 60
    df_bull = pd.DataFrame({
        "open": np.linspace(100, 150, n_bars),
        "high": np.linspace(101, 152, n_bars),
        "low": np.linspace(99, 149, n_bars),
        "close": np.linspace(100.5, 151.5, n_bars),
        "volume": np.random.uniform(1000, 2000, n_bars)
    })

    analysis = detector.detect_regime(df_bull)
    assert analysis.regime == "BULL_TRENDING"
    assert "MomentumBreakout" in analysis.recommended_strategy_types

def test_strategy_mutator():
    mutator = StrategyMutator(mutation_rate=0.5)
    base_params = {"lookback_bars": 20, "rvol_threshold": 3.0, "vwap_filter": True}
    
    population = mutator.generate_population(base_params, population_size=5)
    assert len(population) == 5
    assert population[0] == base_params

def test_canary_sandbox_rejection():
    # Strict hurdles
    hurdles = CanaryPromotionHurdles(MIN_TRADES=5, MIN_PROFIT_FACTOR=2.0)
    canary = CanarySandbox(hurdles=hurdles)

    # Flat unmoving data
    n_bars = 100
    df_flat = pd.DataFrame({
        "open": [100.0] * n_bars,
        "high": [100.1] * n_bars,
        "low": [99.9] * n_bars,
        "close": [100.0] * n_bars,
        "volume": [100.0] * n_bars
    })

    promoted, report, reason = canary.evaluate_candidate(
        strategy_cls=MomentumBreakoutStrategy,
        candidate_params={"lookback_bars": 20, "rvol_threshold": 3.0},
        validation_df=df_flat,
        symbol="TEST"
    )
    assert promoted is False
    assert "Insufficient trade sample" in reason or "hurdle" in reason
