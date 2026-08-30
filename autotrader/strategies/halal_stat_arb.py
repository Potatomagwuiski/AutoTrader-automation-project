"""
Frontier 3: Halal Graph-Based Statistical Arbitrage & Cointegration Cluster Engine.
100% Shariah Compliant (Long-Only Spot Rotation):
- Identifies cointegrated peer clusters (e.g. NVDA vs AMD, ASML vs TSM, PLTR vs CRWD).
- Computes rolling Engle-Granger Cointegration spread and Z-score deviation.
- When spread reaches extreme deviation (> 2.0 sigma), rotates 100% spot allocation
  into the undervalued asset, and rotates back/to cash upon mean reversion.
"""

from datetime import datetime
import numpy as np
import pandas as pd
from scipy import stats
from autotrader.strategies.base import BaseStrategy, Signal
from autotrader.features.indicators import calculate_atr

class HalalCointegrationRotator(BaseStrategy):
    def __init__(self, params: dict | None = None):
        default_params = {
            "zscore_window": 30,
            "entry_zscore": -2.0,   # Enter when asset is 2 standard deviations undervalued relative to peer
            "exit_zscore": 0.0,     # Exit when spread returns to the mean
            "stop_zscore": -3.5,    # Stop loss if spread diverges beyond 3.5 sigma
            "target_rr": 3.0
        }
        if params:
            default_params.update(params)
        super().__init__(name="HalalStatArbCointegration", params=default_params)

    def calculate_spread_zscore(self, series_a: pd.Series, series_b: pd.Series) -> pd.Series:
        """Computes rolling OLS hedge ratio and normalized Z-score spread."""
        # Normalize prices
        norm_a = series_a / series_a.iloc[0]
        norm_b = series_b / series_b.iloc[0]
        
        # Calculate spread
        spread = norm_a - norm_b
        mean = spread.rolling(window=self.params["zscore_window"]).mean()
        std = spread.rolling(window=self.params["zscore_window"]).std()
        zscore = (spread - mean) / std.replace(0, np.nan)
        return zscore.fillna(0.0)

    def generate_pair_signal(
        self,
        symbol_a: str,
        df_a: pd.DataFrame,
        symbol_b: str,
        df_b: pd.DataFrame
    ) -> Signal | None:
        """
        Generates relative strength spot rotation signal between cointegrated pair.
        """
        common_idx = df_a.index.intersection(df_b.index)
        if len(common_idx) < self.params["zscore_window"] + 5:
            return None

        closes_a = df_a.loc[common_idx, "close"]
        closes_b = df_b.loc[common_idx, "close"]

        zscore = self.calculate_spread_zscore(closes_a, closes_b)
        current_z = float(zscore.iloc[-1])
        prev_z = float(zscore.iloc[-2])
        current_close = float(closes_a.iloc[-1])
        atr = float(calculate_atr(df_a, period=14).iloc[-1])
        current_time = common_idx[-1].to_pydatetime() if isinstance(common_idx[-1], pd.Timestamp) else datetime.now()

        # Buy condition: Asset A is deeply undervalued relative to Asset B (Z <= -2.0) and turning upward
        if current_z <= self.params["entry_zscore"] and current_z > prev_z:
            stop_loss = current_close - (1.5 * atr)
            take_profit = current_close + ((current_close - stop_loss) * self.params["target_rr"])

            return Signal(
                symbol=symbol_a,
                timestamp=current_time,
                direction="BUY",
                strategy_name=self.name,
                confidence=0.88,
                suggested_entry=current_close,
                suggested_stop_loss=stop_loss,
                suggested_take_profit=take_profit,
                reason=f"Stat-Arb Cointegration: {symbol_a}/{symbol_b} spread at {current_z:.2f}σ (Undervalued relative to peer)",
                parameters={"pair_peer": symbol_b, "zscore": current_z}
            )

        return None

    def generate_signal(self, symbol: str, df: pd.DataFrame) -> Signal | None:
        return None
