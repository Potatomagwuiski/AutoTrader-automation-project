"""
Order, Fill, Position, and Trade Data Structures.
Supports fractional shares for Alpaca notional order execution.
"""

from datetime import datetime
from typing import Literal
from pydantic import BaseModel, Field

class Order(BaseModel):
    order_id: str
    symbol: str
    direction: Literal["BUY", "SELL"]
    order_type: Literal["MARKET", "LIMIT", "STOP"]
    shares: float = Field(..., description="Number of shares (supports integer and fractional)")
    price: float | None = None
    stop_price: float | None = None
    status: Literal["PENDING", "FILLED", "CANCELLED", "REJECTED"] = "PENDING"
    created_at: datetime
    strategy_name: str
    metadata: dict = Field(default_factory=dict)

class Fill(BaseModel):
    fill_id: str
    order_id: str
    symbol: str
    direction: Literal["BUY", "SELL"]
    shares: float
    fill_price: float
    timestamp: datetime
    fee: float = 0.0
    slippage: float = 0.0

class Position(BaseModel):
    symbol: str
    direction: Literal["LONG", "SHORT"]
    shares: float
    entry_price: float
    current_price: float
    entry_time: datetime
    initial_stop_loss: float
    current_stop_loss: float
    take_profit: float
    strategy_name: str
    highest_price: float
    unrealized_pnl: float = 0.0
    realized_pnl: float = 0.0

    def update_market_price(self, price: float) -> None:
        self.current_price = price
        if self.direction == "LONG":
            self.unrealized_pnl = (price - self.entry_price) * self.shares
            if price > self.highest_price:
                self.highest_price = price
        else:
            self.unrealized_pnl = (self.entry_price - price) * self.shares
            if price < self.highest_price:
                self.highest_price = price

class Trade(BaseModel):
    trade_id: str
    symbol: str
    direction: Literal["LONG", "SHORT"]
    shares: float
    entry_price: float
    exit_price: float
    entry_time: datetime
    exit_time: datetime
    realized_pnl: float
    realized_return_pct: float
    exit_reason: str
    strategy_name: str
