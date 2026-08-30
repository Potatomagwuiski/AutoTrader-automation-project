"""
Yahoo Finance Market Data Provider.
"""

from datetime import datetime, timedelta
import pandas as pd
import yfinance as yf
from autotrader.data.base import BaseMarketDataProvider, AssetMetadata, Bar
from autotrader.telemetry.logger import log

class YFinanceProvider(BaseMarketDataProvider):
    def __init__(self):
        self._metadata_cache: dict[str, AssetMetadata] = {}

    def fetch_historical_bars(
        self,
        symbol: str,
        timeframe: str = "5m",
        start: str | datetime | None = None,
        end: str | datetime | None = None,
        period: str | None = None,
        limit: int = 10000
    ) -> pd.DataFrame:
        """Fetches historical bars for a symbol with interval mapping."""
        # yfinance timeframe mapping
        valid_intervals = {
            "1m": "1m", "2m": "2m", "5m": "5m", "15m": "15m", "30m": "30m",
            "60m": "60m", "1h": "1h", "1d": "1d", "1wk": "1wk"
        }
        interval = valid_intervals.get(timeframe, "5m")

        ticker = yf.Ticker(symbol)
        
        # Determine period if start/end not provided
        if not start and not end:
            if period:
                fetch_period = period
            else:
                period_map = {"1m": "7d", "5m": "60d", "15m": "60d", "1h": "730d", "1d": "5y", "1wk": "max"}
                fetch_period = period_map.get(interval, "1mo")
            df = ticker.history(period=fetch_period, interval=interval, auto_adjust=False)
        else:
            df = ticker.history(start=start, end=end, interval=interval, auto_adjust=False)
            
        if df.empty:
            log.warning(f"No historical data returned for {symbol} ({interval})")
            return pd.DataFrame()

        # Standardize column names to lowercase
        df.columns = [c.lower() for c in df.columns]
        if "adj close" in df.columns:
            df = df.rename(columns={"adj close": "adj_close"})
            
        # Ensure UTC or localized index
        if df.index.tz is None:
            df.index = df.index.tz_localize("UTC")
        else:
            df.index = df.index.tz_convert("UTC")

        # Keep relevant columns and ensure numeric
        cols = [c for c in ["open", "high", "low", "close", "volume"] if c in df.columns]
        df = df[cols].astype(float)
        
        if limit and len(df) > limit:
            df = df.iloc[-limit:]
            
        return df

    def fetch_asset_metadata(self, symbol: str) -> AssetMetadata:
        """Fetches fundamental data and float/debt metrics."""
        if symbol in self._metadata_cache:
            return self._metadata_cache[symbol]

        ticker = yf.Ticker(symbol)
        info = ticker.info or {}
        
        market_cap = float(info.get("marketCap", 0.0) or 0.0)
        total_debt = float(info.get("totalDebt", 0.0) or 0.0)
        total_cash = float(info.get("totalCash", 0.0) or 0.0)
        shares_float = float(info.get("floatShares", 0.0) or info.get("sharesOutstanding", 0.0) or 0.0)
        shares_outstanding = float(info.get("sharesOutstanding", 0.0) or 0.0)
        debt_to_equity = float(info.get("debtToEquity", 0.0) or 0.0)
        current_price = float(info.get("regularMarketPrice", 0.0) or info.get("currentPrice", 0.0) or 0.0)
        avg_vol = float(info.get("averageVolume", 0.0) or info.get("averageVolume10days", 0.0) or 0.0)

        # Estimate interest-bearing debt percentage (total debt / market cap)
        interest_bearing_debt_pct = (total_debt / market_cap) if market_cap > 0 else 0.0

        meta = AssetMetadata(
            symbol=symbol,
            name=info.get("shortName", symbol) or symbol,
            sector=info.get("sector", "Unknown") or "Unknown",
            industry=info.get("industry", "Unknown") or "Unknown",
            market_cap=market_cap,
            shares_float=shares_float,
            shares_outstanding=shares_outstanding,
            total_debt=total_debt,
            total_cash=total_cash,
            debt_to_equity=debt_to_equity,
            interest_bearing_debt_pct=interest_bearing_debt_pct,
            current_price=current_price,
            avg_daily_volume=avg_vol
        )
        self._metadata_cache[symbol] = meta
        return meta

    def fetch_realtime_bar(self, symbol: str) -> Bar | None:
        """Fetches latest quote bar."""
        df = self.fetch_historical_bars(symbol, timeframe="1m", limit=2)
        if df.empty:
            return None
        latest = df.iloc[-1]
        return Bar(
            symbol=symbol,
            timestamp=df.index[-1].to_pydatetime(),
            open=float(latest["open"]),
            high=float(latest["high"]),
            low=float(latest["low"]),
            close=float(latest["close"]),
            volume=float(latest["volume"])
        )
