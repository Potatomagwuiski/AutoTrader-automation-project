"""
Canary Sandbox & Strategy Darwinism Engine.
Isolates candidate strategies in a paper/simulation sandbox and verifies statistical robustness
before automatically promoting them into active live execution.
"""

from typing import Type
from pydantic import BaseModel
import pandas as pd
from autotrader.strategies.base import BaseStrategy
from autotrader.learning.optimizer import simulate_strategy
from autotrader.telemetry.metrics import PerformanceReport
from autotrader.telemetry.logger import log, console

class CanaryPromotionHurdles(BaseModel):
    MIN_TRADES: int = 5
    MIN_PROFIT_FACTOR: float = 1.30
    MIN_WIN_RATE: float = 0.40
    MAX_DRAWDOWN_PCT: float = 0.05
    MIN_EXPECTANCY: float = 0.0

class CanarySandbox:
    def __init__(self, hurdles: CanaryPromotionHurdles | None = None):
        self.hurdles = hurdles or CanaryPromotionHurdles()

    def evaluate_candidate(
        self,
        strategy_cls: Type[BaseStrategy],
        candidate_params: dict,
        validation_df: pd.DataFrame,
        symbol: str = "SANDBOX"
    ) -> tuple[bool, PerformanceReport, str]:
        """
        Evaluates candidate strategy against out-of-sample data.
        Returns (promoted: bool, report: PerformanceReport, rationale: str).
        """
        report = simulate_strategy(strategy_cls, candidate_params, validation_df, symbol=symbol)

        if report.total_trades < self.hurdles.MIN_TRADES:
            return False, report, f"Insufficient trade sample ({report.total_trades} < {self.hurdles.MIN_TRADES})"

        if report.profit_factor < self.hurdles.MIN_PROFIT_FACTOR:
            return False, report, f"Profit factor below hurdle ({report.profit_factor:.2f} < {self.hurdles.MIN_PROFIT_FACTOR:.2f})"

        if report.win_rate < self.hurdles.MIN_WIN_RATE:
            return False, report, f"Win rate below hurdle ({report.win_rate:.1%} < {self.hurdles.MIN_WIN_RATE:.1%})"

        if report.max_drawdown_pct > self.hurdles.MAX_DRAWDOWN_PCT:
            return False, report, f"Drawdown exceeded hurdle ({report.max_drawdown_pct:.2%} > {self.hurdles.MAX_DRAWDOWN_PCT:.2%})"

        if report.expectancy < self.hurdles.MIN_EXPECTANCY:
            return False, report, f"Negative expectancy (${report.expectancy:.2f})"

        rationale = (
            f"PASSED CANARY HURDLES: PF={report.profit_factor:.2f}, WinRate={report.win_rate:.1%}, "
            f"MaxDD={report.max_drawdown_pct:.2%}, Trades={report.total_trades}"
        )
        log.info(f"Canary Promotion Granted: {strategy_cls.__name__} with params {candidate_params} | {rationale}")
        console.print(f"[success]{rationale}[/success]")
        return True, report, rationale
