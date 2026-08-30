"""
High-Alpha Infinite Trend Rider & Leveraged Momentum Strategy.
Eliminates premature profit caps to ride multi-hundred-percent macro trends using Chandelier ATR trailing stops.
Utilizes dynamic capital allocation (up to 90% capital deployment) for explosive compounding.
"""

from datetime import datetime
import pandas as pd
from autotrader.strategies.base import BaseStrategy, Signal
from autotrader.features.indicators import calculate_atr, calculate_ema

class HighAlphaTrendRiderStrategy(BaseStrategy):
    def __init__(self, params: dict | None = None):
        default_params = {
            "fast_ema": 10,
            "slow_ema": 30,
            "trend_filter_ema": 100,
            "atr_period": 14,
            "initial_atr_stop": 2.0,
            "trailing_atr_multiplier": 2.5,  # Trailing chandelier stop giving room for multi-hundred % runners
            "target_rr": 50.0  # Open-ended target: lets winners run indefinitely until stopped out by trailing trend
        }
        if params:
            default_params.update(params)
        super().__init__(name="HighAlphaTrendRider", params=default_params)

    def generate_signal(self, symbol: str, df: pd.DataFrame) -> Signal | None:
        if len(df) < self.params["trend_filter_ema"] + 5:
            return None

        closes = df["close"]
        ema_fast = calculate_ema(closes, self.params["fast_ema"])
        ema_slow = calculate_ema(closes, self.params["slow_ema"])
        ema_trend = calculate_ema(closes, self.params["trend_filter_ema"])
        atr = calculate_atr(df, self.params["atr_period"])

        current_close = float(closes.iloc[-1])
        prev_close = float(closes.iloc[-2])
        current_atr = float(atr.iloc[-1])
        current_time = df.index[-1].to_pydatetime() if isinstance(df.index[-1], pd.Timestamp) else datetime.now()

        # Golden Cross & Trend Expansion:
        # 1. EMA 10 crosses or is strongly above EMA 30
        # 2. Price is above the 100 EMA macro bull filter
        # 3. Fresh breakout trigger (EMA 10 crossed above EMA 30 within last 3 bars)
        is_bull_regime = current_close > ema_trend.iloc[-1]
        ema_cross_recent = (
            (ema_fast.iloc[-1] > ema_slow.iloc[-1]) and
            (ema_fast.iloc[-3] <= ema_slow.iloc[-3] or ema_fast.iloc[-2] <= ema_slow.iloc[-2] or (current_close > ema_fast.iloc[-1] and prev_close <= ema_fast.iloc[-2]))
        )

        if is_bull_regime and ema_cross_recent and current_atr > 0:
            stop_loss = current_close - (self.params["initial_atr_stop"] * current_atr)
            take_profit = current_close + ((current_close - stop_loss) * self.params["target_rr"])

            return Signal(
                symbol=symbol,
                timestamp=current_time,
                direction="BUY",
                strategy_name=self.name,
                confidence=0.95,
                suggested_entry=current_close,
                suggested_stop_loss=stop_loss,
                suggested_take_profit=take_profit,
                reason=f"High-Alpha Macro Trend Ignition: EMA10 > EMA30 above 100-EMA (${ema_trend.iloc[-1]:.2f})",
                parameters=self.params
            )

        return None
