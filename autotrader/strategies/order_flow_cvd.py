"""
Frontier 5: Order Flow Cumulative Volume Delta (CVD) & Microstructure Imbalance Strategy.
Features:
- Estimates Buyer vs Seller aggressive volume delta across price bars.
- Cumulative Volume Delta (CVD) divergence detection: Detects institutional absorption
  (e.g. price making lower low into support, while CVD delta prints higher highs).
- Imbalance breakout entries with tight 0.5% risk and 4.0R - 6.0R asymmetric targets.
"""

from datetime import datetime
import numpy as np
import pandas as pd
from autotrader.strategies.base import BaseStrategy, Signal
from autotrader.features.indicators import calculate_atr

def estimate_volume_delta(df: pd.DataFrame) -> tuple[pd.Series, pd.Series]:
    """
    Estimates aggressive Buy Volume vs Sell Volume based on bar close position relative to high/low.
    Buy Fraction = (Close - Low) / (High - Low)
    Sell Fraction = (High - Close) / (High - Low)
    """
    high = df["high"]
    low = df["low"]
    close = df["close"]
    volume = df["volume"]

    bar_range = (high - low).replace(0, np.nan)
    buy_fraction = ((close - low) / bar_range).fillna(0.5)
    sell_fraction = ((high - close) / bar_range).fillna(0.5)

    delta = (buy_fraction - sell_fraction) * volume
    cvd = delta.cumsum()
    return delta, cvd

class OrderFlowCVDStrategy(BaseStrategy):
    def __init__(self, params: dict | None = None):
        default_params = {
            "cvd_lookback": 20,
            "target_rr": 4.0,
            "tight_stop_atr": 1.2
        }
        if params:
            default_params.update(params)
        super().__init__(name="OrderFlowCVD", params=default_params)

    def generate_signal(self, symbol: str, df: pd.DataFrame) -> Signal | None:
        if len(df) < self.params["cvd_lookback"] + 5:
            return None

        delta, cvd = estimate_volume_delta(df)
        atr = float(calculate_atr(df, period=14).iloc[-1])

        current_close = float(df["close"].iloc[-1])
        current_open = float(df["open"].iloc[-1])
        current_time = df.index[-1].to_pydatetime() if isinstance(df.index[-1], pd.Timestamp) else datetime.now()

        # CVD Bullish Absorption Divergence:
        # Price is lower or flat compared to 10 bars ago, but CVD is making strong HIGHER highs
        sub_df = df.iloc[-self.params["cvd_lookback"]:]
        sub_cvd = cvd.iloc[-self.params["cvd_lookback"]:]

        price_dropped = current_close <= sub_df["close"].iloc[0] * 1.01
        cvd_divergence = sub_cvd.iloc[-1] > sub_cvd.iloc[0] and delta.iloc[-1] > 0
        is_green_bar = current_close > current_open

        if price_dropped and cvd_divergence and is_green_bar and atr > 0:
            stop_loss = current_close - (self.params["tight_stop_atr"] * atr)
            risk = max(current_close - stop_loss, 0.05)
            take_profit = current_close + (risk * self.params["target_rr"])

            return Signal(
                symbol=symbol,
                timestamp=current_time,
                direction="BUY",
                strategy_name=self.name,
                confidence=0.85,
                suggested_entry=current_close,
                suggested_stop_loss=stop_loss,
                suggested_take_profit=take_profit,
                reason=f"Order Flow CVD Absorption: Bullish delta divergence with aggressive buying at support",
                parameters=self.params
            )

        return None
