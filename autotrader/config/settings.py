"""
System configuration and runtime settings.
"""

from pathlib import Path
from pydantic import BaseModel, Field
import os

class SystemSettings(BaseModel):
    # Directories
    BASE_DIR: Path = Path(__file__).resolve().parent.parent.parent
    DATA_DIR: Path = BASE_DIR / "data_store"
    LOG_DIR: Path = BASE_DIR / "logs"
    JOURNAL_DIR: Path = BASE_DIR / "journal"

    # Execution Mode: 'simulation', 'paper', 'live'
    EXECUTION_MODE: str = os.getenv("EXECUTION_MODE", "paper")

    # Timeframe defaults
    DEFAULT_BAR_TIMEFRAME: str = "5m"  # 1m, 5m, 15m, 1h, 1d
    SCANNER_INTERVAL_SECONDS: int = 60
    
    # Capital & Account
    INITIAL_CAPITAL: float = float(os.getenv("INITIAL_CAPITAL", "100000.0"))
    CURRENCY: str = "USD"

    # Screener universe defaults
    DEFAULT_WATCHLIST: list[str] = Field(default_factory=lambda: [
        "AAPL", "MSFT", "NVDA", "TSLA", "AMD", "META", "AMZN", "GOOGL",
        "PLTR", "SOFI", "MARA", "COIN", "DKNG", "RIVN", "LCID", "SMCI",
        "ARM", "HOOD", "BABA", "NIO", "PYPL", "INTC", "QCOM", "AVGO"
    ])

settings = SystemSettings()
settings.DATA_DIR.mkdir(parents=True, exist_ok=True)
settings.LOG_DIR.mkdir(parents=True, exist_ok=True)
settings.JOURNAL_DIR.mkdir(parents=True, exist_ok=True)
