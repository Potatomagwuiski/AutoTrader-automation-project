"""
Strategy Base Interfaces and Signal Models.
"""

from abc import ABC, abstractmethod
from datetime import datetime
from typing import Literal
from pydantic import BaseModel, Field
import pandas as pd

class Signal(BaseModel):
    symbol: str
    timestamp: datetime
    direction: Literal["BUY", "SELL", "HOLD"]
    strategy_name: str
    confidence: float = 1.0  # 0.0 to 1.0
    suggested_entry: float
    suggested_stop_loss: float
    suggested_take_profit: float
    reason: str
    parameters: dict = Field(default_factory=dict)

class BaseStrategy(ABC):
    def __init__(self, name: str, params: dict | None = None):
        self.name = name
        self.params = params or {}
        self.enabled = True

    @abstractmethod
    def generate_signal(self, symbol: str, df: pd.DataFrame) -> Signal | None:
        """
        Generates trading signal from dataframe containing OHLCV and technical features.
        """
        pass

    def update_parameters(self, new_params: dict) -> None:
        """Dynamically update strategy parameters during learning iterations."""
        self.params.update(new_params)
