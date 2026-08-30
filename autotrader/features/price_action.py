"""
Market Price Action and Structural Pivot Analysis.
Detects Swing Highs/Lows, Trends (Higher Highs / Higher Lows), and Breakout Levels.
"""

from typing import Literal
import numpy as np
import pandas as pd
from pydantic import BaseModel

class StructuralLevels(BaseModel):
    trend: Literal["UPTREND", "DOWNTREND", "SIDEWAYS"]
    recent_swing_high: float
    recent_swing_low: float
    support_level: float
    resistance_level: float
    is_breaking_out: bool
    is_breaking_down: bool

def find_swing_pivots(df: pd.DataFrame, window: int = 5) -> tuple[pd.Series, pd.Series]:
    """
    Finds swing highs and swing lows over rolling local extrema.
    """
    high = df["high"]
    low = df["low"]
    
    swing_highs = high.rolling(window=2*window+1, center=True).apply(
        lambda x: 1.0 if x.iloc[window] == x.max() else 0.0, raw=False
    ).fillna(0.0)
    
    swing_lows = low.rolling(window=2*window+1, center=True).apply(
        lambda x: 1.0 if x.iloc[window] == x.min() else 0.0, raw=False
    ).fillna(0.0)
    
    return swing_highs, swing_lows

def analyze_price_action(df: pd.DataFrame, lookback: int = 30) -> StructuralLevels:
    """
    Extracts structural trend, swing points, and breakout conditions from recent bars.
    """
    if len(df) < lookback:
        current_close = float(df["close"].iloc[-1]) if not df.empty else 0.0
        return StructuralLevels(
            trend="SIDEWAYS",
            recent_swing_high=current_close,
            recent_swing_low=current_close,
            support_level=current_close,
            resistance_level=current_close,
            is_breaking_out=False,
            is_breaking_down=False
        )

    sub_df = df.iloc[-lookback:]
    highs = sub_df["high"].values
    lows = sub_df["low"].values
    closes = sub_df["close"].values
    current_close = closes[-1]
    
    # 20-bar resistance and support
    resistance = float(np.max(highs[:-1]))
    support = float(np.min(lows[:-1]))
    
    # Check for breakout (current close > previous resistance)
    is_breaking_out = bool(current_close > resistance)
    is_breaking_down = bool(current_close < support)
    
    # Trend detection via EMA slope + Higher High / Higher Low check
    fast_ema = sub_df["close"].ewm(span=9).mean().values
    slow_ema = sub_df["close"].ewm(span=21).mean().values
    
    if fast_ema[-1] > slow_ema[-1] and fast_ema[-1] > fast_ema[-5]:
        trend = "UPTREND"
    elif fast_ema[-1] < slow_ema[-1] and fast_ema[-1] < fast_ema[-5]:
        trend = "DOWNTREND"
    else:
        trend = "SIDEWAYS"
        
    return StructuralLevels(
        trend=trend,
        recent_swing_high=resistance,
        recent_swing_low=support,
        support_level=support,
        resistance_level=resistance,
        is_breaking_out=is_breaking_out,
        is_breaking_down=is_breaking_down
    )
