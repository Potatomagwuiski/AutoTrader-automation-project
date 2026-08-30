"""
Market Regime Classification Engine.
Classifies the market environment into distinct behavioral regimes:
- BULL_TRENDING (Strong upward momentum)
- BEAR_TRENDING (Strong downward momentum)
- HIGH_VOLATILITY_CHOP (Expansion with erratic reversals)
- LOW_VOLATILITY_RANGE (Consolidation / Mean Reversion)
"""

from typing import Literal
import numpy as np
import pandas as pd
from pydantic import BaseModel
from autotrader.features.indicators import calculate_atr, calculate_ema

RegimeType = Literal["BULL_TRENDING", "BEAR_TRENDING", "HIGH_VOLATILITY_CHOP", "LOW_VOLATILITY_RANGE"]

class RegimeAnalysis(BaseModel):
    regime: RegimeType
    trend_strength: float  # 0.0 to 1.0
    volatility_ratio: float
    recommended_strategy_types: list[str]

class MarketRegimeDetector:
    def __init__(self, ema_fast_period: int = 10, ema_slow_period: int = 30, atr_period: int = 14):
        self.ema_fast = ema_fast_period
        self.ema_slow = ema_slow_period
        self.atr_period = atr_period

    def detect_regime(self, df: pd.DataFrame) -> RegimeAnalysis:
        """
        Analyzes dataframe and detects current regime.
        """
        if len(df) < self.ema_slow + 10:
            return RegimeAnalysis(
                regime="LOW_VOLATILITY_RANGE",
                trend_strength=0.5,
                volatility_ratio=1.0,
                recommended_strategy_types=["MeanReversion", "VWAPPullback"]
            )

        closes = df["close"]
        ema_fast = calculate_ema(closes, self.ema_fast)
        ema_slow = calculate_ema(closes, self.ema_slow)
        atr = calculate_atr(df, self.atr_period)
        
        current_close = float(closes.iloc[-1])
        current_atr = float(atr.iloc[-1])
        avg_atr = float(atr.rolling(30).mean().iloc[-1]) if len(atr) >= 30 else current_atr
        
        volatility_ratio = current_atr / avg_atr if avg_atr > 0 else 1.0

        # Calculate slope of slow EMA
        ema_diff = (ema_fast.iloc[-1] - ema_slow.iloc[-1]) / ema_slow.iloc[-1]
        slope_pct = (ema_slow.iloc[-1] - ema_slow.iloc[-5]) / ema_slow.iloc[-5] if len(ema_slow) >= 5 else 0.0

        trend_strength = min(1.0, abs(ema_diff) * 100.0)

        # Classification logic
        if volatility_ratio > 1.4 and abs(slope_pct) < 0.002:
            regime: RegimeType = "HIGH_VOLATILITY_CHOP"
            recommended = ["MeanReversion", "HalalTrendRotator"]
        elif ema_diff > 0.005 and slope_pct > 0:
            regime = "BULL_TRENDING"
            recommended = ["HalalTrendRotator", "AdaptiveHighAlpha", "MomentumBreakout", "VWAPPullback"]
        elif ema_diff < -0.005 and slope_pct < 0:
            regime = "BEAR_TRENDING"
            recommended = []  # Cash Defense Mode
        else:
            regime = "LOW_VOLATILITY_RANGE"
            recommended = ["HalalTrendRotator", "MeanReversion", "VWAPPullback"]


        return RegimeAnalysis(
            regime=regime,
            trend_strength=float(trend_strength),
            volatility_ratio=float(volatility_ratio),
            recommended_strategy_types=recommended
        )
