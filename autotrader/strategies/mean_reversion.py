"""
Mean Reversion Volatility Envelope Strategy.
Trades oversold bounces back to the mean in range-bound/sideways market regimes.
"""

from datetime import datetime
import pandas as pd
from autotrader.strategies.base import BaseStrategy, Signal
from autotrader.features.indicators import calculate_bollinger_bands, calculate_rsi, calculate_atr

class MeanReversionStrategy(BaseStrategy):
    def __init__(self, params: dict | None = None):
        default_params = {
            "bb_period": 20,
            "bb_std": 2.0,
            "rsi_period": 14,
            "rsi_oversold": 35.0,
            "atr_multiplier_stop": 1.5,
            "target_mean": True
        }
        if params:
            default_params.update(params)
        super().__init__(name="MeanReversion", params=default_params)

    def generate_signal(self, symbol: str, df: pd.DataFrame) -> Signal | None:
        if len(df) < self.params["bb_period"] + 5:
            return None

        upper, middle, lower = calculate_bollinger_bands(
            df["close"], period=self.params["bb_period"], num_std=self.params["bb_std"]
        )
        rsi = calculate_rsi(df["close"], period=self.params["rsi_period"])
        atr = calculate_atr(df, period=14).iloc[-1]

        current_close = float(df["close"].iloc[-1])
        current_low = float(df["low"].iloc[-1])
        lower_band = float(lower.iloc[-1])
        mid_band = float(middle.iloc[-1])
        current_rsi = float(rsi.iloc[-1])
        current_time = df.index[-1].to_pydatetime() if isinstance(df.index[-1], pd.Timestamp) else datetime.now()

        # Condition: Low tagged or pierced lower Bollinger Band and RSI is oversold (< 30) with a green recovery close
        if (current_low <= lower_band or current_rsi <= self.params["rsi_oversold"]) and current_close > df["open"].iloc[-1]:
            stop_loss = current_low - (self.params["atr_multiplier_stop"] * atr)
            take_profit = mid_band  # Target return to mean (20 SMA)

            if take_profit > current_close and (current_close - stop_loss) > 0:
                return Signal(
                    symbol=symbol,
                    timestamp=current_time,
                    direction="BUY",
                    strategy_name=self.name,
                    confidence=0.70,
                    suggested_entry=current_close,
                    suggested_stop_loss=stop_loss,
                    suggested_take_profit=take_profit,
                    reason=f"Oversold bounce off lower BB (${lower_band:.2f}, RSI: {current_rsi:.1f}) targeting mean ${mid_band:.2f}",
                    parameters=self.params
                )

        return None
