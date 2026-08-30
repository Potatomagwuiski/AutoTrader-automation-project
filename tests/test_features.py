"""
Tests for Feature Computation & Technical Indicators.
"""

import pandas as pd
import numpy as np
from autotrader.features.indicators import calculate_vwap, calculate_atr, calculate_rsi, calculate_bollinger_bands, calculate_rvol
from autotrader.features.price_action import analyze_price_action

def test_indicators():
    n_bars = 50
    df = pd.DataFrame({
        "open": np.linspace(100, 110, n_bars),
        "high": np.linspace(101, 112, n_bars),
        "low": np.linspace(99, 109, n_bars),
        "close": np.linspace(100.5, 111.5, n_bars),
        "volume": np.random.uniform(500, 2000, n_bars)
    })

    vwap = calculate_vwap(df)
    assert len(vwap) == n_bars
    assert vwap.iloc[-1] > 0

    atr = calculate_atr(df, period=14)
    assert len(atr) == n_bars
    assert atr.iloc[-1] > 0

    rsi = calculate_rsi(df["close"], period=14)
    assert len(rsi) == n_bars
    assert 0 <= rsi.iloc[-1] <= 100

    upper, mid, lower = calculate_bollinger_bands(df["close"])
    assert upper.iloc[-1] > mid.iloc[-1] > lower.iloc[-1]

    rvol = calculate_rvol(df)
    assert len(rvol) == n_bars

def test_price_action_analysis():
    n_bars = 40
    # Strong uptrend breakout
    df = pd.DataFrame({
        "open": list(range(100, 140)),
        "high": [x + 2 for x in range(100, 140)],
        "low": [x - 1 for x in range(100, 140)],
        "close": [x + 1.5 for x in range(100, 140)],
        "volume": [1000] * n_bars
    })

    pa = analyze_price_action(df, lookback=20)
    assert pa.trend == "UPTREND"
    assert pa.is_breaking_out is True
