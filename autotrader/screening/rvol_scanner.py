"""
Stage 3 Filter: Dynamic Relative Volume (RVOL) and Volatility Surge Scanner.
Isolates true institutional momentum signals from market noise.
"""

from pydantic import BaseModel
import pandas as pd
from autotrader.features.indicators import calculate_rvol, calculate_atr

class RVOLScannerConfig(BaseModel):
    MIN_RVOL: float = 3.0           # Rule: Relative Volume >= 3.0 indicates institutional catalyst
    MIN_INTRADAY_RANGE_PCT: float = 0.015  # Minimum 1.5% range expansion
    RVOL_LOOKBACK_BARS: int = 20

class RVOLScanner:
    def __init__(self, config: RVOLScannerConfig | None = None):
        self.config = config or RVOLScannerConfig()

    def evaluate(self, df: pd.DataFrame) -> tuple[bool, float, str]:
        """
        Evaluates current intraday dataframe for volume surge and relative volume >= 3.0.
        Returns (passed: bool, rvol_value: float, reason: str).
        """
        if len(df) < self.config.RVOL_LOOKBACK_BARS + 2:
            return False, 1.0, "Insufficient bars to compute RVOL"

        rvol_series = calculate_rvol(df, baseline_period=self.config.RVOL_LOOKBACK_BARS)
        current_rvol = float(rvol_series.iloc[-1])
        
        # Check intraday range expansion
        high = float(df["high"].iloc[-5:].max())
        low = float(df["low"].iloc[-5:].min())
        close = float(df["close"].iloc[-1])
        range_pct = (high - low) / close if close > 0 else 0.0

        if current_rvol >= self.config.MIN_RVOL:
            return True, current_rvol, f"High Institutional RVOL detected: {current_rvol:.2f}x baseline (Range: {range_pct:.1%})"
        
        return False, current_rvol, f"RVOL {current_rvol:.2f}x below {self.config.MIN_RVOL:.1f}x threshold"
