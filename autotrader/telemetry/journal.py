"""
Persistent trade journal and trade audit recorder.
"""

import json
from datetime import datetime
from pathlib import Path
from pydantic import BaseModel, Field
from autotrader.config.settings import settings
from autotrader.telemetry.logger import log

class TradeRecord(BaseModel):
    trade_id: str
    symbol: str
    direction: str  # 'LONG' or 'SHORT'
    strategy_name: str
    entry_time: datetime
    exit_time: datetime | None = None
    entry_price: float
    exit_price: float | None = None
    shares: float
    initial_stop_loss: float
    initial_take_profit: float
    
    realized_pnl: float = 0.0
    realized_return_pct: float = 0.0
    r_multiple: float = 0.0
    exit_reason: str = ""  # 'STOP_LOSS', 'TAKE_PROFIT', 'TRAILING_STOP', 'TIME_LIMIT', 'CIRCUIT_BREAKER'
    
    fees: float = 0.0
    slippage: float = 0.0
    market_regime: str = "UNKNOWN"
    metadata: dict = Field(default_factory=dict)

class TradeJournal:
    def __init__(self, journal_file: Path | None = None):
        self.journal_file = journal_file or (settings.JOURNAL_DIR / "trade_journal.jsonl")
        self.trades: list[TradeRecord] = []
        self._load_journal()

    def _load_journal(self) -> None:
        if self.journal_file.exists():
            try:
                with open(self.journal_file, "r") as f:
                    for line in f:
                        if line.strip():
                            data = json.loads(line.strip())
                            self.trades.append(TradeRecord.model_validate(data))
                log.info(f"Loaded {len(self.trades)} trades from journal: {self.journal_file}")
            except Exception as e:
                log.error(f"Error loading trade journal: {e}")

    def record_trade(self, trade: TradeRecord) -> None:
        self.trades.append(trade)
        try:
            with open(self.journal_file, "a") as f:
                f.write(trade.model_dump_json() + "\n")
            log.info(f"Recorded trade {trade.trade_id} [{trade.symbol} {trade.direction}] PnL: ${trade.realized_pnl:.2f} ({trade.r_multiple:.2f}R)")
        except Exception as e:
            log.error(f"Failed to record trade to journal file: {e}")

    def get_pnls(self) -> list[float]:
        return [t.realized_pnl for t in self.trades if t.exit_time is not None]

    def get_r_multiples(self) -> list[float]:
        return [t.r_multiple for t in self.trades if t.exit_time is not None]
