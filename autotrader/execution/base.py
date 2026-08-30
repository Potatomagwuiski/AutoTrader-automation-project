"""
Base Execution Handler Interface.
"""

from abc import ABC, abstractmethod
from autotrader.execution.order_types import Order, Fill, Position

class BaseExecutionHandler(ABC):
    @abstractmethod
    def submit_order(self, order: Order) -> Fill | None:
        pass

    @abstractmethod
    def close_position(self, symbol: str, reason: str) -> Fill | None:
        pass

    @abstractmethod
    def get_open_positions(self) -> dict[str, Position]:
        pass

    @abstractmethod
    def get_account_equity(self) -> float:
        pass
