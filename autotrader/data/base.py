"""
Market Data Base Interfaces and Models.
"""

from abc import ABC, abstractmethod
from datetime import datetime
from pydantic import BaseModel
import pandas as pd

class Bar(BaseModel):
    symbol: str
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float
    vwap: float | None = None

class AssetMetadata(BaseModel):
    symbol: str
    name: str = ""
    sector: str = ""
    industry: str = ""
    market_cap: float = 0.0
    shares_float: float = 0.0
    shares_outstanding: float = 0.0
    total_debt: float = 0.0
    total_cash: float = 0.0
    debt_to_equity: float = 0.0
    interest_bearing_debt_pct: float = 0.0
    current_price: float = 0.0
    avg_daily_volume: float = 0.0

class BaseMarketDataProvider(ABC):
    @abstractmethod
    def fetch_historical_bars(
        self,
        symbol: str,
        timeframe: str = "5m",
        start: str | datetime | None = None,
        end: str | datetime | None = None,
        limit: int = 1000
    ) -> pd.DataFrame:
        """Fetches OHLCV dataframe indexed by datetime."""
        pass

    @abstractmethod
    def fetch_asset_metadata(self, symbol: str) -> AssetMetadata:
        """Fetches fundamental and market metadata for symbol."""
        pass

    @abstractmethod
    def fetch_realtime_bar(self, symbol: str) -> Bar | None:
        """Fetches the latest real-time bar."""
        pass
