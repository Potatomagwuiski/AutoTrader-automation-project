"""
High RVOL Momentum Breakout Strategy.
Capitalizes on high relative volume breakouts through multi-bar swing resistance.
"""

from datetime import datetime
import pandas as pd
from autotrader.strategies.base import BaseStrategy, Signal
from autotrader.features.indicators import calculate_rvol, calculate_atr, calculate_vwap
from autotrader.features.price_action import analyze_price_action

class MomentumBreakoutStrategy(BaseStrategy):
    def __init__(self, params: dict | None = None):
        default_params = {
            "rvol_threshold": 1.3,
            "lookback_bars": 20,
            "atr_multiplier_stop": 1.5,
            "rr_ratio": 2.0,
            "vwap_filter": True  # Only go long if price > VWAP
        }
        if params:
            default_params.update(params)
        super().__init__(name="MomentumBreakout", params=default_params)

    def generate_signal(self, symbol: str, df: pd.DataFrame) -> Signal | None:
        if len(df) < self.params["lookback_bars"] + 10:
            return None

        # Calculate features
        rvol = calculate_rvol(df, baseline_period=self.params["lookback_bars"]).iloc[-1]
        atr = calculate_atr(df, period=14).iloc[-1]
        vwap = calculate_vwap(df).iloc[-1]
        pa = analyze_price_action(df, lookback=self.params["lookback_bars"])

        current_close = float(df["close"].iloc[-1])
        current_time = df.index[-1].to_pydatetime() if isinstance(df.index[-1], pd.Timestamp) else datetime.now()

        # Breakout condition: RVOL >= threshold, breaking out of resistance, price above VWAP
        is_rvol_surge = rvol >= self.params["rvol_threshold"]
        is_above_vwap = current_close > vwap if self.params["vwap_filter"] else True

        if pa.is_breaking_out and is_rvol_surge and is_above_vwap:
            stop_loss = current_close - (self.params["atr_multiplier_stop"] * atr)
            risk_per_share = current_close - stop_loss
            take_profit = current_close + (risk_per_share * self.params["rr_ratio"])

            return Signal(
                symbol=symbol,
                timestamp=current_time,
                direction="BUY",
                strategy_name=self.name,
                confidence=min(1.0, 0.6 + (rvol / 10.0)),
                suggested_entry=current_close,
                suggested_stop_loss=stop_loss,
                suggested_take_profit=take_profit,
                reason=f"Breakout above {pa.resistance_level:.2f} with {rvol:.2f}x RVOL (> VWAP {vwap:.2f})",
                parameters=self.params
            )

        return None
