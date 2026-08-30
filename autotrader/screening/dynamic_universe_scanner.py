"""
Autonomous Halal Universe Discovery & Dynamic Asset Selector.
Features:
1. Dynamic Universe Ingestion: Pulls broad universe of liquid US equities (NASDAQ-100, S&P 500 tech/growth).
2. Live AAOIFI Shariah Audit: Automatically recalculates debt-to-market cap, cash-to-market cap, and business sector flags in real-time from live financial statements.
3. Automated Charity Purification: Calculates dynamic purification percentage on every trade/dividend.
4. Autonomous Momentum Ranking: Ranks compliant assets by Relative Volume (RVOL), 200-EMA Trend Distance, and ATR momentum to pick the top 2 highest-alpha leaders daily.
"""

from datetime import datetime
from pydantic import BaseModel, Field
import pandas as pd
from tabulate import tabulate
from autotrader.data.base import BaseMarketDataProvider
from autotrader.screening.halal_screener import HalalShariahScreener, HalalComplianceStatus
from autotrader.features.indicators import calculate_ema, calculate_atr, calculate_rvol
from autotrader.telemetry.logger import log

class QualifiedHalalCandidate(BaseModel):
    symbol: str
    company_name: str
    sector: str
    current_price: float
    debt_ratio: float
    cash_ratio: float
    purification_rate: float
    is_macro_bull: bool
    rvol: float
    momentum_score: float
    reasons: list[str] = Field(default_factory=list)

class DynamicHalalUniverseScanner:
    def __init__(
        self,
        data_provider: BaseMarketDataProvider,
        screener: HalalShariahScreener | None = None
    ):
        self.provider = data_provider
        self.screener = screener or HalalShariahScreener()

        # Dynamic broad candidate pool across US Growth, Tech, Health, and Mobility sectors
        self.broad_universe = [
            "NVDA", "AAPL", "MSFT", "GOOGL", "AMZN", "META", "TSLA",
            "AMD", "PLTR", "ARM", "AVGO", "ASML", "QCOM", "CRWD",
            "PANW", "SNOW", "ADBE", "INTC", "TXN", "AMAT", "LRCX",
            "MU", "MRVL", "KLAC", "CDNS", "SNPS", "FTNT", "ZS",
            "ABNB", "UBER", "SHOP", "SQ", "COIN", "JPM", "BAC", "WFC"
        ]

    def scan_and_rank_universe(
        self,
        universe: list[str] | None = None,
        top_n: int = 2
    ) -> tuple[list[QualifiedHalalCandidate], list[dict]]:
        """
        Autonomously audits the entire universe for Shariah compliance and ranks by live alpha momentum.
        Returns:
            (top_ranked_candidates, full_compliance_audit_log)
        """
        symbols_to_scan = universe or self.broad_universe
        log.info(f"Starting autonomous Shariah audit across {len(symbols_to_scan)} market assets...")

        compliant_candidates: list[QualifiedHalalCandidate] = []
        audit_log = []

        for symbol in symbols_to_scan:
            try:
                # 1. Fetch live balance sheet metadata
                meta = self.provider.fetch_asset_metadata(symbol)
                status: HalalComplianceStatus = self.screener.screen_asset(meta)

                audit_entry = {
                    "symbol": symbol,
                    "name": meta.name,
                    "sector": meta.sector,
                    "debt_ratio": status.debt_ratio,
                    "cash_ratio": status.cash_interest_ratio,
                    "is_compliant": status.is_compliant,
                    "purification_pct": status.purification_rate,
                    "failure_reasons": status.reasons
                }
                audit_log.append(audit_entry)

                if not status.is_compliant:
                    continue

                # 2. Fetch live multi-day historical bars for trend & momentum scoring
                df = self.provider.fetch_historical_bars(symbol, timeframe="1d", period="1y")
                if df.empty or len(df) < 205:
                    continue

                closes = df["close"]
                current_close = float(closes.iloc[-1])
                ema_macro = calculate_ema(closes, span=200)
                ema_fast = calculate_ema(closes, span=9)
                ema_slow = calculate_ema(closes, span=21)
                rvol_series = calculate_rvol(df, baseline_period=20)
                atr_series = calculate_atr(df, period=14)

                current_macro = float(ema_macro.iloc[-1])
                current_rvol = float(rvol_series.iloc[-1])
                current_atr = float(atr_series.iloc[-1])
                is_macro_bull = current_close > current_macro

                if not is_macro_bull:
                    continue

                # Momentum Score Calculation:
                # Weighted composite of: (Distance above 200 EMA) + (RVOL acceleration) + (EMA9/EMA21 slope)
                dist_200_pct = (current_close - current_macro) / current_macro
                ema_spread_pct = (ema_fast.iloc[-1] - ema_slow.iloc[-1]) / ema_slow.iloc[-1]
                atr_volatility_pct = (current_atr / current_close) if current_close > 0 else 0.0

                momentum_score = (dist_200_pct * 0.40) + (current_rvol * 0.30) + (ema_spread_pct * 0.20) + (atr_volatility_pct * 0.10)

                reasons = [
                    f"AAOIFI Compliant (Debt {status.debt_ratio:.1%}, Cash {status.cash_interest_ratio:.1%})",
                    f"Macro Bull: ${current_close:.2f} > 200-EMA (${current_macro:.2f})",
                    f"RVOL: {current_rvol:.2f}x, Momentum Score: {momentum_score:.2f}"
                ]

                candidate = QualifiedHalalCandidate(
                    symbol=symbol,
                    company_name=meta.name,
                    sector=meta.sector,
                    current_price=current_close,
                    debt_ratio=status.debt_ratio,
                    cash_ratio=status.cash_interest_ratio,
                    purification_rate=status.purification_rate,
                    is_macro_bull=is_macro_bull,
                    rvol=current_rvol,
                    momentum_score=momentum_score,
                    reasons=reasons
                )
                compliant_candidates.append(candidate)

            except Exception as e:
                log.warning(f"Error evaluating asset {symbol}: {e}")

        # Rank compliant candidates by live momentum score
        ranked_candidates = sorted(compliant_candidates, key=lambda c: c.momentum_score, reverse=True)
        top_candidates = ranked_candidates[:top_n]

        log.info(f"Autonomous screening completed: {len(compliant_candidates)} compliant assets found. Top {top_n} picked: {[c.symbol for c in top_candidates]}")
        return top_candidates, audit_log
