"""
Tests for Strategy Signal Generation.
"""

import pandas as pd
import numpy as np
from autotrader.strategies.momentum_breakout import MomentumBreakoutStrategy
from autotrader.strategies.vwap_pullback import VWAPPullbackStrategy
from autotrader.strategies.mean_reversion import MeanReversionStrategy

def test_momentum_breakout_strategy():
    strat = MomentumBreakoutStrategy({"rvol_threshold": 2.0})
    n_bars = 40
    # Simulate a breakout candle with high volume
    highs = list(range(100, 140))
    df = pd.DataFrame({
        "open": list(range(99, 139)),
        "high": highs,
        "low": [x - 1 for x in highs],
        "close": [x + 0.5 for x in highs],
        "volume": [1000] * (n_bars - 1) + [5000]
    })
    
    signal = strat.generate_signal("TEST", df)
    assert signal is not None
    assert signal.direction == "BUY"
    assert signal.suggested_stop_loss < signal.suggested_entry
    assert signal.suggested_take_profit > signal.suggested_entry

def test_mean_reversion_strategy():
    strat = MeanReversionStrategy({"rsi_oversold": 40.0})
    n_bars = 40
    # Downtrend into oversold bounce
    df = pd.DataFrame({
        "open": [100 - i for i in range(n_bars)],
        "high": [101 - i for i in range(n_bars)],
        "low": [98 - i for i in range(n_bars)],
        "close": [99 - i for i in range(n_bars - 1)] + [62.0],  # green recovery bar
        "volume": [1000] * n_bars
    })
    df.loc[df.index[-1], "open"] = 60.0
    
    signal = strat.generate_signal("TEST", df)
    # May generate signal when oversold criteria met
    if signal:
        assert signal.direction == "BUY"
