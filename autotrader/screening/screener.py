"""
Multi-Stage Screening Pipeline Orchestrator.
Combines Fundamental, Liquidity, and RVOL scanners to produce active trading watchlists.
"""

from pydantic import BaseModel, Field
import pandas as pd
from autotrader.data.base import BaseMarketDataProvider, AssetMetadata
from autotrader.screening.fundamental_filter import FundamentalFilter, FundamentalFilterConfig
from autotrader.screening.liquidity_filter import LiquidityFilter, LiquidityFilterConfig
from autotrader.screening.rvol_scanner import RVOLScanner, RVOLScannerConfig
from autotrader.telemetry.logger import log

class QualifiedAsset(BaseModel):
    symbol: str
    metadata: AssetMetadata
    rvol: float
    current_price: float
    reason: str

class MultiStageScreener:
    def __init__(
        self,
        data_provider: BaseMarketDataProvider,
        fund_cfg: FundamentalFilterConfig | None = None,
        liq_cfg: LiquidityFilterConfig | None = None,
        rvol_cfg: RVOLScannerConfig | None = None
    ):
        self.data_provider = data_provider
        self.fundamental_filter = FundamentalFilter(fund_cfg)
        self.liquidity_filter = LiquidityFilter(liq_cfg)
        self.rvol_scanner = RVOLScanner(rvol_cfg)

    def screen_universe(self, symbols: list[str], timeframe: str = "5m") -> list[QualifiedAsset]:
        """
        Runs the full 3-stage filtration pipeline on a list of symbols.
        """
        qualified: list[QualifiedAsset] = []
        log.info(f"Screening universe of {len(symbols)} symbols...")

        for symbol in symbols:
            try:
                # Stage 1: Fundamental Screening
                meta = self.data_provider.fetch_asset_metadata(symbol)
                passed_fund, reason_fund = self.fundamental_filter.evaluate(meta)
                if not passed_fund:
                    log.debug(f"[{symbol}] Failed Stage 1 (Fundamental): {reason_fund}")
                    continue

                # Stage 2: Liquidity & Float Screening
                passed_liq, reason_liq = self.liquidity_filter.evaluate(meta)
                if not passed_liq:
                    log.debug(f"[{symbol}] Failed Stage 2 (Liquidity): {reason_liq}")
                    continue

                # Stage 3: Intraday RVOL and Catalyst Scan
                df = self.data_provider.fetch_historical_bars(symbol, timeframe=timeframe, limit=50)
                if df.empty:
                    continue

                passed_rvol, rvol_val, reason_rvol = self.rvol_scanner.evaluate(df)
                if not passed_rvol:
                    log.debug(f"[{symbol}] Failed Stage 3 (RVOL): {reason_rvol}")
                    continue

                # Asset passed all 3 stages!
                current_price = float(df["close"].iloc[-1])
                qualified.append(QualifiedAsset(
                    symbol=symbol,
                    metadata=meta,
                    rvol=rvol_val,
                    current_price=current_price,
                    reason=f"Passed all filters (RVOL: {rvol_val:.2f}x, Float: {meta.shares_float/1e6:.1f}M)"
                ))
                log.info(f"==> QUALIFIED: {symbol} | Price: ${current_price:.2f} | RVOL: {rvol_val:.2f}x")

            except Exception as e:
                log.error(f"Error screening {symbol}: {e}")

        # Sort by RVOL descending
        qualified.sort(key=lambda x: x.rvol, reverse=True)
        return qualified
