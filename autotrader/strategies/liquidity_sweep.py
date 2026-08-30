"""
Institutional Liquidity Sweep & Fair Value Gap (FVG) Strategy.
Detects when price sweeps equal lows or structural support wicks, rejects liquidity,
and prints an imbalance expansion candle back inside the range.
"""

from datetime import datetime
import pandas as pd
from autotrader.strategies.base import BaseStrategy, Signal
from autotrader.features.indicators import calculate_atr

class LiquiditySweepStrategy(BaseStrategy):
    def __init__(self, params: dict | None = None):
        default_params = {
            "sweep_lookback": 15,
            "target_rr": 4.0,  # 1:4 Asymmetric target
            "min_rejection_wick_ratio": 0.35  # Lower wick must be >= 35% of total candle range
        }
        if params:
            default_params.update(params)
        super().__init__(name="LiquiditySweep", params=default_params)

    def generate_signal(self, symbol: str, df: pd.DataFrame) -> Signal | None:
        if len(df) < self.params["sweep_lookback"] + 5:
            return None

        recent_df = df.iloc[-self.params["sweep_lookback"]-1:-1]
        prior_support = float(recent_df["low"].min())

        current_bar = df.iloc[-1]
        current_open = float(current_bar["open"])
        current_high = float(current_bar["high"])
        current_low = float(current_bar["low"])
        current_close = float(current_bar["close"])
        current_time = df.index[-1].to_pydatetime() if isinstance(df.index[-1], pd.Timestamp) else datetime.now()

        total_range = max(current_high - current_low, 0.01)
        lower_wick = min(current_open, current_close) - current_low
        wick_ratio = lower_wick / total_range

        # Liquidity Sweep Conditions:
        # 1. Bar's low swept below prior support
        # 2. Bar closed back ABOVE prior support (strong rejection)
        # 3. Lower wick forms >= 35% of the total candle (liquidity capture signature)
        # 4. Bullish close (close > open)
        is_sweep = current_low < prior_support and current_close > prior_support
        is_strong_rejection = wick_ratio >= self.params["min_rejection_wick_ratio"]
        is_bullish = current_close > current_open

        if is_sweep and is_strong_rejection and is_bullish:
            stop_loss = current_low - 0.02  # Invalidation is just below the sweep low
            risk = max(current_close - stop_loss, 0.05)
            take_profit = current_close + (risk * self.params["target_rr"])

            return Signal(
                symbol=symbol,
                timestamp=current_time,
                direction="BUY",
                strategy_name=self.name,
                confidence=0.80,
                suggested_entry=current_close,
                suggested_stop_loss=stop_loss,
                suggested_take_profit=take_profit,
                reason=f"Liquidity Sweep of support (${prior_support:.2f}) with {wick_ratio:.0%} lower wick rejection targeting +4R",
                parameters=self.params
            )

        return None
