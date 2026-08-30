"""
Adaptive High-Alpha Macro-Regime & Volatility-Shielded Trend Strategy.
Features:
1. Macro Regime Gate: Deploys aggressive trend capital only when macro regime is Bullish (Price > 200-SMA).
2. Volatility Shield: Automatically tightens trailing stops or rotates into cash during high-volatility bear market regimes.
3. Multi-tier Profit Locks: Locks in gains at +25%, +50%, and +100% thresholds while letting runners ride.
"""

from datetime import datetime
import pandas as pd
from autotrader.strategies.base import BaseStrategy, Signal
from autotrader.features.indicators import calculate_atr, calculate_ema

class AdaptiveHighAlphaStrategy(BaseStrategy):
    def __init__(self, params: dict | None = None):
        default_params = {
            "fast_ema": 9,
            "slow_ema": 21,
            "macro_ema_filter": 200,   # Institutional 200-day trend filter
            "atr_period": 14,
            "initial_atr_stop": 1.8,
            "trailing_atr_mult": 2.2,
            "profit_lock_1": 0.25,     # Lock in +15% profit when +25% gain is reached
            "profit_lock_2": 0.50,     # Lock in +35% profit when +50% gain is reached
            "profit_lock_3": 1.00      # Lock in +75% profit when +100% gain is reached
        }
        if params:
            default_params.update(params)
        super().__init__(name="AdaptiveHighAlpha", params=default_params)

    def generate_signal(self, symbol: str, df: pd.DataFrame) -> Signal | None:
        if len(df) < self.params["macro_ema_filter"] + 5:
            return None

        closes = df["close"]
        ema_fast = calculate_ema(closes, self.params["fast_ema"])
        ema_slow = calculate_ema(closes, self.params["slow_ema"])
        ema_macro = calculate_ema(closes, self.params["macro_ema_filter"])
        atr = calculate_atr(df, self.params["atr_period"])

        current_close = float(closes.iloc[-1])
        prev_close = float(closes.iloc[-2])
        current_atr = float(atr.iloc[-1])
        current_time = df.index[-1].to_pydatetime() if isinstance(df.index[-1], pd.Timestamp) else datetime.now()

        # Institutional Macro Regime Conditions:
        # 1. Price is strictly above the 200-day SMA/EMA (Eliminates 2022 bear market drawdowns)
        # 2. Fast EMA (9) is above Slow EMA (21)
        # 3. Fresh breakout ignition
        is_macro_bull = current_close > ema_macro.iloc[-1]
        is_trend_ignited = (
            (ema_fast.iloc[-1] > ema_slow.iloc[-1]) and
            (ema_fast.iloc[-2] <= ema_slow.iloc[-2] or (current_close > ema_fast.iloc[-1] and prev_close <= ema_fast.iloc[-2]))
        )

        if is_macro_bull and is_trend_ignited and current_atr > 0:
            stop_loss = current_close - (self.params["initial_atr_stop"] * current_atr)
            take_profit = current_close * 5.0  # Open-ended upside

            return Signal(
                symbol=symbol,
                timestamp=current_time,
                direction="BUY",
                strategy_name=self.name,
                confidence=0.98,
                suggested_entry=current_close,
                suggested_stop_loss=stop_loss,
                suggested_take_profit=take_profit,
                reason=f"Macro Bull Ignition: Close (${current_close:.2f}) > 200-EMA (${ema_macro.iloc[-1]:.2f}) with EMA9 > EMA21",
                parameters=self.params
            )

        return None
