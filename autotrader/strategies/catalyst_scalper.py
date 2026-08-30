"""
Intraday High-RVOL Catalyst Scalper Strategy.
Operates on 5m / 15m intraday bars, capturing high-velocity momentum expansions
on volume surges with tight risk and fast 2.5R - 4R profit targets.
"""

from datetime import datetime
import pandas as pd
from autotrader.strategies.base import BaseStrategy, Signal
from autotrader.features.indicators import calculate_rvol, calculate_atr, calculate_vwap, calculate_ema

class CatalystScalperStrategy(BaseStrategy):
    def __init__(self, params: dict | None = None):
        default_params = {
            "min_rvol": 2.0,
            "ema_fast": 9,
            "ema_slow": 21,
            "target_rr": 3.0,
            "tight_atr_stop": 1.0  # Tight 1.0 ATR stop for high asymmetric payoff
        }
        if params:
            default_params.update(params)
        super().__init__(name="CatalystScalper", params=default_params)

    def generate_signal(self, symbol: str, df: pd.DataFrame) -> Signal | None:
        if len(df) < 25:
            return None

        rvol_series = calculate_rvol(df, baseline_period=20)
        current_rvol = float(rvol_series.iloc[-1])
        atr = float(calculate_atr(df, period=14).iloc[-1])
        vwap = float(calculate_vwap(df).iloc[-1])
        
        ema_fast = calculate_ema(df["close"], self.params["ema_fast"]).iloc[-1]
        ema_slow = calculate_ema(df["close"], self.params["ema_slow"]).iloc[-1]

        current_close = float(df["close"].iloc[-1])
        current_open = float(df["open"].iloc[-1])
        prev_close = float(df["close"].iloc[-2])
        current_time = df.index[-1].to_pydatetime() if isinstance(df.index[-1], pd.Timestamp) else datetime.now()

        # Catalyst Scalp Conditions:
        # 1. Volume spike (RVOL >= 2.0x)
        # 2. Bullish momentum candle (close > open and close > prev_close)
        # 3. Price above VWAP and EMA Fast > EMA Slow
        is_volume_catalyst = current_rvol >= self.params["min_rvol"]
        is_bullish_bar = current_close > current_open and current_close > prev_close
        is_trend_aligned = current_close > vwap and ema_fast > ema_slow

        if is_volume_catalyst and is_bullish_bar and is_trend_aligned and atr > 0:
            stop_loss = current_close - (self.params["tight_atr_stop"] * atr)
            risk = max(current_close - stop_loss, 0.05)
            take_profit = current_close + (risk * self.params["target_rr"])

            return Signal(
                symbol=symbol,
                timestamp=current_time,
                direction="BUY",
                strategy_name=self.name,
                confidence=min(1.0, 0.7 + (current_rvol / 10.0)),
                suggested_entry=current_close,
                suggested_stop_loss=stop_loss,
                suggested_take_profit=take_profit,
                reason=f"Catalyst Surge: RVOL {current_rvol:.2f}x (> VWAP ${vwap:.2f}) targeting +{self.params['target_rr']:.1f}R",
                parameters=self.params
            )

        return None
