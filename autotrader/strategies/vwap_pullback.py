"""
Institutional VWAP Pullback / Bounce Strategy.
Trades high-probability pullbacks to VWAP in an established uptrend.
"""

from datetime import datetime
import pandas as pd
from autotrader.strategies.base import BaseStrategy, Signal
from autotrader.features.indicators import calculate_vwap, calculate_atr, calculate_ema
from autotrader.features.price_action import analyze_price_action

class VWAPPullbackStrategy(BaseStrategy):
    def __init__(self, params: dict | None = None):
        default_params = {
            "vwap_tolerance_pct": 0.015,  # Within 1.5% of VWAP / 20-MA
            "atr_multiplier_stop": 1.2,
            "rr_ratio": 2.5,
            "trend_ema_fast": 9,
            "trend_ema_slow": 21
        }
        if params:
            default_params.update(params)
        super().__init__(name="VWAPPullback", params=default_params)

    def generate_signal(self, symbol: str, df: pd.DataFrame) -> Signal | None:
        if len(df) < 30:
            return None

        vwap_series = calculate_vwap(df)
        atr_series = calculate_atr(df, period=14)
        ema_fast = calculate_ema(df["close"], self.params["trend_ema_fast"])
        ema_slow = calculate_ema(df["close"], self.params["trend_ema_slow"])

        current_close = float(df["close"].iloc[-1])
        current_low = float(df["low"].iloc[-1])
        vwap = float(vwap_series.iloc[-1])
        atr = float(atr_series.iloc[-1])
        current_time = df.index[-1].to_pydatetime() if isinstance(df.index[-1], pd.Timestamp) else datetime.now()

        # Uptrend filter: EMA Fast > EMA Slow
        is_uptrend = ema_fast.iloc[-1] > ema_slow.iloc[-1]
        
        # Pullback test: Low dipped near or slightly below VWAP, but close remains above or bouncing off VWAP
        distance_to_vwap = abs(current_low - vwap) / vwap
        is_near_vwap = distance_to_vwap <= self.params["vwap_tolerance_pct"]
        is_bullish_bounce = current_close >= vwap and current_close > df["open"].iloc[-1]

        if is_uptrend and (is_near_vwap or (df["low"].iloc[-2] <= vwap and current_close > vwap)) and is_bullish_bounce:
            stop_loss = min(current_low, vwap) - (self.params["atr_multiplier_stop"] * atr)
            risk_per_share = max(current_close - stop_loss, 0.05)
            take_profit = current_close + (risk_per_share * self.params["rr_ratio"])

            return Signal(
                symbol=symbol,
                timestamp=current_time,
                direction="BUY",
                strategy_name=self.name,
                confidence=0.75,
                suggested_entry=current_close,
                suggested_stop_loss=stop_loss,
                suggested_take_profit=take_profit,
                reason=f"VWAP bounce at ${vwap:.2f} in Uptrend (EMA9 > EMA21)",
                parameters=self.params
            )

        return None
