"""
Master Autonomous Engine Orchestrator.
Unifies Market Data Ingestion, Multi-Stage Screening, Regime Analysis, Strategy Signals,
Strict Risk Management, Order Execution, and Closed-Loop Self-Learning.
"""

import asyncio
from datetime import datetime
import pandas as pd
from autotrader.config.settings import settings
from autotrader.config.risk_params import risk_params
from autotrader.data.base import BaseMarketDataProvider
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.screening.screener import MultiStageScreener
from autotrader.features.indicators import calculate_atr
from autotrader.strategies import (
    BaseStrategy,
    MomentumBreakoutStrategy,
    VWAPPullbackStrategy,
    MeanReversionStrategy,
    AsymmetricTrendFollowingStrategy,
    CatalystScalperStrategy,
    LiquiditySweepStrategy,
    HighAlphaTrendRiderStrategy,
    AdaptiveHighAlphaStrategy,
    HalalTrendRotatorStrategy
)
from autotrader.risk.risk_manager import RiskManager
from autotrader.execution.base import BaseExecutionHandler
from autotrader.execution.paper_engine import PaperExecutionEngine
from autotrader.execution.order_types import Order
from autotrader.learning.regime_detector import MarketRegimeDetector
from autotrader.learning.strategy_mutator import StrategyMutator
from autotrader.learning.canary_sandbox import CanarySandbox
from autotrader.telemetry.logger import log, console

from autotrader.screening.dynamic_universe_scanner import DynamicHalalUniverseScanner

class AutoTraderEngine:
    def __init__(
        self,
        data_provider: BaseMarketDataProvider | None = None,
        execution_handler: BaseExecutionHandler | None = None,
        watchlist: list[str] | None = None
    ):
        self.data_provider = data_provider or YFinanceProvider()
        self.execution = execution_handler or PaperExecutionEngine()
        self.risk_manager = RiskManager()
        self.screener = MultiStageScreener(self.data_provider)
        self.halal_scanner = DynamicHalalUniverseScanner(self.data_provider)
        self.regime_detector = MarketRegimeDetector()
        self.mutator = StrategyMutator()
        self.canary = CanarySandbox()

        self.watchlist = watchlist or settings.DEFAULT_WATCHLIST
        self.is_running = False

        # Active strategy pool
        self.active_strategies: dict[str, BaseStrategy] = {
            "HalalTrendRotator": HalalTrendRotatorStrategy(),
            "AdaptiveHighAlpha": AdaptiveHighAlphaStrategy(),
            "HighAlphaTrendRider": HighAlphaTrendRiderStrategy(),
            "MomentumBreakout": MomentumBreakoutStrategy(),
            "CatalystScalper": CatalystScalperStrategy(),
            "LiquiditySweep": LiquiditySweepStrategy(),
            "VWAPPullback": VWAPPullbackStrategy(),
            "MeanReversion": MeanReversionStrategy()
        }

    async def run_screening_cycle(self) -> list[str]:
        """Autonomously audits balance sheets for AAOIFI Shariah compliance and selects top alpha leaders."""
        top_candidates, _ = self.halal_scanner.scan_and_rank_universe(top_n=2)
        symbols = [c.symbol for c in top_candidates]
        log.info(f"Autonomous Dynamic Halal Screener selected top picks: {symbols}")
        return symbols

    def evaluate_and_trade(self, symbol: str) -> None:
        """Processes real-time market data for a symbol and executes risk-approved signals."""
        df = self.data_provider.fetch_historical_bars(symbol, timeframe="5m", limit=60)
        if df.empty or len(df) < 30:
            return

        current_time = datetime.now()
        current_bar = df.iloc[-1].to_dict()
        current_atr = float(calculate_atr(df, period=14).iloc[-1])

        # 1. Update existing positions & check trailing stops/exits
        self.execution.update_and_check_exits(
            symbol=symbol,
            current_bar=current_bar,
            current_time=current_time,
            current_atr=current_atr
        )

        # 2. Check if we already have an open position in this asset
        open_positions = self.execution.get_open_positions()
        if symbol in open_positions:
            return

        # 3. Detect market regime
        regime = self.regime_detector.detect_regime(df)

        # 4. Generate signals from strategies suitable for the current regime
        for strat_name, strategy in self.active_strategies.items():
            if not strategy.enabled:
                continue

            # Align strategy with detected market regime
            if strat_name not in regime.recommended_strategy_types:
                continue

            signal = strategy.generate_signal(symbol, df)
            if not signal or signal.direction != "BUY":
                continue

            # 5. Pre-trade Risk Gate Check
            equity = self.execution.get_account_equity()
            risk_check = self.risk_manager.evaluate_order(
                signal=signal,
                account_equity=equity,
                open_positions_count=len(open_positions),
                current_time=current_time
            )

            if not risk_check.approved:
                log.info(f"Signal rejected by Risk Gate: {risk_check.reason}")
                continue

            # 6. Execute Approved Order
            order = Order(
                order_id=f"ord_{int(current_time.timestamp())}_{symbol}",
                symbol=symbol,
                direction="BUY",
                order_type="MARKET",
                shares=risk_check.shares,
                price=signal.suggested_entry,
                stop_price=signal.suggested_stop_loss,
                created_at=current_time,
                strategy_name=strat_name,
                metadata={"take_profit": signal.suggested_take_profit, "regime": regime.regime}
            )

            fill = self.execution.submit_order(order)
            if fill:
                console.print(
                    f"[trade]EXECUTED BUY: {fill.shares} {fill.symbol} @ ${fill.fill_price:.2f} | Strategy: {strat_name} | Regime: {regime.regime}[/trade]"
                )
            break

    async def self_improving_loop(self) -> None:
        """
        Background autonomous learning loop:
        1. Evaluates past trade performance
        2. Mutates strategy parameters
        3. Tests variations in the Canary Sandbox
        4. Promotes winning mutations to live pool
        """
        while self.is_running:
            try:
                log.info("Starting Autonomous Self-Learning & Adaptation Cycle...")
                # Test each active strategy
                for name, strategy in list(self.active_strategies.items()):
                    # Mutate strategy parameters
                    population = self.mutator.generate_population(strategy.params, population_size=4)
                    for candidate_params in population:
                        # Grab validation data on watchlist
                        if not self.watchlist:
                            log.warning("Watchlist is empty, skipping canary evaluation")
                            break
                        sample_symbol = self.watchlist[0]
                        val_df = self.data_provider.fetch_historical_bars(sample_symbol, timeframe="5m", limit=300)
                        if val_df.empty or len(val_df) < 100:
                            continue

                        promoted, report, reason = self.canary.evaluate_candidate(
                            strategy_cls=type(strategy),
                            candidate_params=candidate_params,
                            validation_df=val_df,
                            symbol=sample_symbol
                        )

                        if promoted:
                            strategy.update_parameters(candidate_params)
                            log.info(f"[AUTONOMOUS LEARNING] Promoted updated parameters for {name}: {candidate_params}")

                # Run learning every 15 minutes
                await asyncio.sleep(900)
            except Exception as e:
                log.error(f"Error in self-improving loop: {e}")
                await asyncio.sleep(60)

    async def start(self) -> None:
        """Starts the master trading loop."""
        self.is_running = True
        console.print("[success]AutoTrader Autonomous Engine Started.[/success]")
        
        # Launch self-improvement loop in background
        asyncio.create_task(self.self_improving_loop())

        while self.is_running:
            try:
                # 1. Screen active universe for high RVOL / setups
                active_symbols = await self.run_screening_cycle()
                scan_targets = active_symbols if active_symbols else self.watchlist[:5]
                
                # 2. Evaluate each target
                for sym in scan_targets:
                    self.evaluate_and_trade(sym)

                await asyncio.sleep(settings.SCANNER_INTERVAL_SECONDS)
            except KeyboardInterrupt:
                break
            except Exception as e:
                log.error(f"Engine iteration error: {e}")
                await asyncio.sleep(10)

    def stop(self) -> None:
        self.is_running = False
        console.print("[warning]AutoTrader Engine Stopped.[/warning]")
