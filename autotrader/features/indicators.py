"""
Technical indicators and feature computation engine.
Computes VWAP, ATR, EMA, RSI, Bollinger Bands, and Volume Metrics.
"""

import numpy as np
import pandas as pd

def calculate_vwap(df: pd.DataFrame) -> pd.Series:
    """
    Computes Intraday Rolling Anchored VWAP.
    If intraday timestamps exist, resets at the beginning of each session.
    """
    typical_price = (df["high"] + df["low"] + df["close"]) / 3.0
    vol = df["volume"]

    # Check if index is DatetimeIndex for session grouping
    if isinstance(df.index, pd.DatetimeIndex):
        dates = df.index.date
        # Group cumulative product and volume by day
        cum_vol_price = (typical_price * vol).groupby(dates).cumsum()
        cum_vol = vol.groupby(dates).cumsum()
        vwap = cum_vol_price / cum_vol.replace(0, np.nan)
        return vwap.ffill().fillna(typical_price)
    else:
        cum_vol_price = (typical_price * vol).cumsum()
        cum_vol = vol.cumsum()
        return (cum_vol_price / cum_vol.replace(0, np.nan)).ffill().fillna(typical_price)

def calculate_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """Computes Average True Range (ATR)."""
    high = df["high"]
    low = df["low"]
    close = df["close"]
    prev_close = close.shift(1)
    
    tr1 = high - low
    tr2 = (high - prev_close).abs()
    tr3 = (low - prev_close).abs()
    
    true_range = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    atr = true_range.ewm(span=period, adjust=False).mean()
    return atr

def calculate_ema(series: pd.Series, span: int) -> pd.Series:
    """Computes Exponential Moving Average."""
    return series.ewm(span=span, adjust=False).mean()

def calculate_rsi(series: pd.Series, period: int = 14) -> pd.Series:
    """Computes Relative Strength Index (RSI)."""
    delta = series.diff()
    gain = (delta.where(delta > 0, 0)).ewm(alpha=1/period, adjust=False).mean()
    loss = ((-delta.where(delta < 0, 0))).ewm(alpha=1/period, adjust=False).mean()
    
    rs = gain / loss.replace(0, np.nan)
    rsi = 100 - (100 / (1 + rs))
    return rsi.fillna(50.0)

def calculate_bollinger_bands(series: pd.Series, period: int = 20, num_std: float = 2.0) -> tuple[pd.Series, pd.Series, pd.Series]:
    """Computes (Upper Band, Middle Band, Lower Band)."""
    middle = series.rolling(window=period).mean()
    std = series.rolling(window=period).std()
    upper = middle + (std * num_std)
    lower = middle - (std * num_std)
    return upper, middle, lower

def calculate_rvol(df: pd.DataFrame, baseline_period: int = 20) -> pd.Series:
    """
    Computes Relative Volume (RVOL) = current bar volume / rolling average volume of past N periods.
    """
    avg_vol = df["volume"].rolling(window=baseline_period).mean().shift(1)
    rvol = df["volume"] / avg_vol.replace(0, np.nan)
    return rvol.fillna(1.0)
