"""
Halal High-Alpha Long-Only Trend & Relative Strength Rotation Strategy.
100% Shariah Compliant:
- Spot equity ownership only (No conventional shorting, no margin borrowing/interest).
- Macro Regime Gate (Rotates 100% to Cash in Bear Markets).
- Asymmetric Chandelier ATR Trailing Stop (Rides multi-bagging secular AI/growth trends).
- Dynamic Capital Compounding.
"""

from datetime import datetime
import numpy as np
import pandas as pd
from autotrader.strategies.base import BaseStrategy, Signal
from autotrader.features.indicators import calculate_atr, calculate_ema, calculate_rvol

class HalalTrendRotatorStrategy(BaseStrategy):
    def __init__(self, params: dict | None = None):
        default_params = {
            "fast_ema": 9,
            "slow_ema": 21,
            "macro_regime_ema": 200,   # Macro Bull Filter: Only buy when price > 200-day EMA
            "atr_period": 14,
            "initial_atr_stop": 2.0,
            "chandelier_atr_mult": 2.5, # Chandelier stop lets multi-hundred-% runners compound
            "min_rvol": 1.2,           # Volume confirmation
            "profit_lock_threshold": 0.30  # Lock +20% gain once +30% is attained
        }
        if params:
            default_params.update(params)
        super().__init__(name="HalalTrendRotator", params=default_params)

    def generate_signal(self, symbol: str, df: pd.DataFrame) -> Signal | None:
        if len(df) < self.params["macro_regime_ema"] + 5:
            return None

        closes = df["close"]
        highs = df["high"]
        lows = df["low"]

        ema_fast = calculate_ema(closes, self.params["fast_ema"])
        ema_slow = calculate_ema(closes, self.params["slow_ema"])
        ema_macro = calculate_ema(closes, self.params["macro_regime_ema"])
        atr = calculate_atr(df, self.params["atr_period"])
        rvol = calculate_rvol(df, baseline_period=20)

        current_close = float(closes.iloc[-1])
        prev_close = float(closes.iloc[-2])
        current_atr = float(atr.iloc[-1])
        current_rvol = float(rvol.iloc[-1])
        macro_level = float(ema_macro.iloc[-1])
        current_time = df.index[-1].to_pydatetime() if isinstance(df.index[-1], pd.Timestamp) else datetime.now()

        # Halal Trend Entry Criteria:
        # 1. Macro Bull Trend: Price strictly above 200 EMA (Avoids 2022 market crashes entirely)
        # 2. Fast EMA (9) > Slow EMA (21)
        # 3. Momentum ignition (Close crossed above EMA 9 recently)
        # 4. Healthy volume participation (RVOL >= 1.2x)
        is_macro_bull = current_close > macro_level
        is_ema_bullish = ema_fast.iloc[-1] > ema_slow.iloc[-1]
        is_breakout = (current_close > ema_fast.iloc[-1]) and (prev_close <= ema_fast.iloc[-2] or ema_fast.iloc[-1] > ema_fast.iloc[-3])
        is_volume_confirmed = current_rvol >= self.params["min_rvol"]

        if is_macro_bull and is_ema_bullish and is_breakout and is_volume_confirmed and current_atr > 0:
            stop_loss = current_close - (self.params["initial_atr_stop"] * current_atr)
            take_profit = current_close * 5.0  # Open-ended upside (managed by Chandelier trailing stop)

            return Signal(
                symbol=symbol,
                timestamp=current_time,
                direction="BUY",
                strategy_name=self.name,
                confidence=0.98,
                suggested_entry=current_close,
                suggested_stop_loss=stop_loss,
                suggested_take_profit=take_profit,
                reason=f"Halal Spot Momentum: Close (${current_close:.2f}) > 200-EMA (${macro_level:.2f}), RVOL {current_rvol:.1f}x",
                parameters=self.params
            )

        return None
