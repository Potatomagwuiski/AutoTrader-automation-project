"""
Asymmetric Multi-Asset Trend-Following Strategy (Donchian + ATR Supertrend + Trailing Runners).
Designed to capture multi-week parabolic expansion trends with 4R - 10R asymmetric payoffs.
"""

from datetime import datetime
import numpy as np
import pandas as pd
from autotrader.strategies.base import BaseStrategy, Signal
from autotrader.features.indicators import calculate_atr, calculate_ema

class AsymmetricTrendFollowingStrategy(BaseStrategy):
    def __init__(self, params: dict | None = None):
        default_params = {
            "donchian_period": 20,
            "ema_trend_fast": 20,
            "ema_trend_slow": 50,
            "atr_period": 14,
            "atr_stop_multiplier": 2.0,
            "trailing_atr_step": 1.5,
            "target_rr": 5.0  # Asymmetric 1:5 Risk to Reward target
        }
        if params:
            default_params.update(params)
        super().__init__(name="AsymmetricTrendFollowing", params=default_params)

    def generate_signal(self, symbol: str, df: pd.DataFrame) -> Signal | None:
        if len(df) < max(self.params["donchian_period"], self.params["ema_trend_slow"]) + 5:
            return None

        closes = df["close"]
        highs = df["high"]
        lows = df["low"]

        # 20-period Donchian Upper Band (Highest high of previous N bars)
        donchian_high = highs.iloc[-self.params["donchian_period"]-1:-1].max()
        
        # Trend filters
        ema_fast = calculate_ema(closes, self.params["ema_trend_fast"]).iloc[-1]
        ema_slow = calculate_ema(closes, self.params["ema_trend_slow"]).iloc[-1]
        atr = float(calculate_atr(df, self.params["atr_period"]).iloc[-1])

        current_close = float(closes.iloc[-1])
        current_time = df.index[-1].to_pydatetime() if isinstance(df.index[-1], pd.Timestamp) else datetime.now()

        # Breakout condition: Current Close > 20-bar Donchian High AND EMA 20 > EMA 50
        is_donchian_breakout = current_close > donchian_high
        is_bull_trend = ema_fast > ema_slow and current_close > ema_fast

        if is_donchian_breakout and is_bull_trend and atr > 0:
            stop_loss = current_close - (self.params["atr_stop_multiplier"] * atr)
            risk_distance = current_close - stop_loss
            take_profit = current_close + (risk_distance * self.params["target_rr"])

            return Signal(
                symbol=symbol,
                timestamp=current_time,
                direction="BUY",
                strategy_name=self.name,
                confidence=0.85,
                suggested_entry=current_close,
                suggested_stop_loss=stop_loss,
                suggested_take_profit=take_profit,
                reason=f"Donchian 20 High Breakout (${donchian_high:.2f}) with Bull Trend (EMA20 > EMA50) targeting +5R",
                parameters=self.params
            )

        return None
