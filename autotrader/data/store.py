"""
Local time-series cache and parquet data store.
"""

from pathlib import Path
import pandas as pd
from autotrader.config.settings import settings
from autotrader.telemetry.logger import log

class DataStore:
    def __init__(self, store_dir: Path | None = None):
        self.store_dir = store_dir or settings.DATA_DIR
        self.store_dir.mkdir(parents=True, exist_ok=True)

    def _get_path(self, symbol: str, timeframe: str) -> Path:
        return self.store_dir / f"{symbol}_{timeframe}.parquet"

    def save_bars(self, symbol: str, timeframe: str, df: pd.DataFrame) -> None:
        if df.empty:
            return
        path = self._get_path(symbol, timeframe)
        try:
            # If exists, merge without duplicates
            if path.exists():
                existing_df = pd.read_parquet(path)
                combined = pd.concat([existing_df, df])
                combined = combined[~combined.index.duplicated(keep="last")].sort_index()
                combined.to_parquet(path)
            else:
                df.to_parquet(path)
        except Exception as e:
            log.error(f"Failed to save {symbol} {timeframe} to datastore: {e}")

    def load_bars(self, symbol: str, timeframe: str) -> pd.DataFrame:
        path = self._get_path(symbol, timeframe)
        if not path.exists():
            return pd.DataFrame()
        try:
            return pd.read_parquet(path)
        except Exception as e:
            log.error(f"Failed to load {symbol} {timeframe} from datastore: {e}")
            return pd.DataFrame()
