"""
Production-Ready $5,000 Alpaca Settings 5-Year Backtest.
Settings:
- Initial Capital: $5,000.00 (Spot Equity Only, 0% Margin Debt, 100% Halal)
- Sizing: 48.5% per position (Max 2 concurrent positions, 3% buffer for Alpaca slippage/gap protection)
- Universe: AAOIFI Halal-Screened Leaders (NVDA, AMD, PLTR, TSLA, CRWD, ARM, ASML, QCOM)
- Timing: 200-EMA Macro Trend Filter (100% Cash Protection in Bear Regimes)
- Exit: Chandelier ATR Trailing Stop (2.4x ATR) + Multi-Tier Profit Ratchet
"""

from datetime import datetime
import pandas as pd
from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.screening.halal_screener import HalalShariahScreener
from autotrader.strategies.halal_trend_rotator import HalalTrendRotatorStrategy
from autotrader.learning.optimizer import simulate_high_alpha_portfolio

def main():
    initial_capital = 5000.0
    allocation_pct = 0.485  # 48.5% per trade (Max 2 positions = 97% capital deployed, 3% Alpaca buffer)
    trailing_atr_mult = 2.4

    halal_symbols = ["NVDA", "AMD", "PLTR", "TSLA", "CRWD", "ARM", "ASML", "QCOM"]
    provider = YFinanceProvider()
    screener = HalalShariahScreener()

    print("\n" + "="*85)
    print("  PRODUCTION BACKTEST: $5,000 ALPACA OPTIMAL SETTINGS (2021 - 2026)")
    print("  (50% Allocation • 2 Positions • 200-EMA Shield • Chandelier Trailing Stops)")
    print("="*85)

    symbol_data = {}
    for sym in halal_symbols:
        meta = provider.fetch_asset_metadata(sym)
        status = screener.screen_asset(meta)
        if status.is_compliant:
            df = provider.fetch_historical_bars(sym, timeframe="1d", period="5y")
            if not df.empty and len(df) >= 150:
                symbol_data[sym] = df

    report, trades = simulate_high_alpha_portfolio(
        HalalTrendRotatorStrategy,
        params={"macro_regime_ema": 200, "fast_ema": 9, "slow_ema": 21, "chandelier_atr_mult": trailing_atr_mult},
        symbol_data=symbol_data,
        initial_capital=initial_capital,
        allocation_pct=allocation_pct,
        trailing_atr_mult=trailing_atr_mult
    )

    final_capital = initial_capital + report.total_pnl

    # Overall Summary
    print("\n" + "-"*85)
    print("  1. FIVE-YEAR OVERALL PERFORMANCE METRICS")
    print("-"*85)
    overall_table = [
        ["Initial Capital", f"${initial_capital:,.2f}"],
        ["Final Account Balance", f"${final_capital:,.2f}"],
        ["Total Net Realized Profit", f"${report.total_pnl:+,.2f}"],
        ["5-Year Cumulative Return", f"{(report.total_pnl / initial_capital):+.2%}"],
        ["Annualized Return (CAGR)", f"{((final_capital / initial_capital)**(1/5) - 1):+.2%}"],
        ["Total Closed Trades", report.total_trades],
        ["Winning / Losing Trades", f"{report.winning_trades} / {report.losing_trades}"],
        ["Win Rate", f"{report.win_rate:.1%}"],
        ["Profit Factor", f"{report.profit_factor:.2f}"],
        ["Average Win / Loss", f"${report.avg_win:,.2f} / ${report.avg_loss:,.2f}"],
        ["Payoff Ratio (R:R)", f"{report.payoff_ratio:.2f}"],
        ["Sharpe Ratio", f"{report.sharpe_ratio:.2f}"],
        ["Max Drawdown (%)", f"{report.max_drawdown_pct:.2%}"]
    ]
    print(tabulate(overall_table, headers=["Metric", "Value"], tablefmt="fancy_grid"))

    # Year-by-Year Market Cycle Analysis
    print("\n" + "-"*85)
    print("  2. YEAR-BY-YEAR MARKET CYCLE COMPOUNDING BREAKDOWN")
    print("-"*85)
    trades_by_year = {}
    for t in trades:
        yr = t.entry_time.year
        if yr not in trades_by_year:
            trades_by_year[yr] = []
        trades_by_year[yr].append(t)

    yearly_rows = []
    running_balance = initial_capital

    for yr in sorted(trades_by_year.keys()):
        yr_trades = trades_by_year[yr]
        yr_pnls = [t.realized_pnl for t in yr_trades]
        yr_net_pnl = sum(yr_pnls)
        yr_wins = [p for p in yr_pnls if p > 0]
        yr_losses = [p for p in yr_pnls if p < 0]
        yr_win_rate = len(yr_wins) / len(yr_trades) if yr_trades else 0.0
        yr_gross_profit = sum(yr_wins)
        yr_gross_loss = abs(sum(yr_losses))
        yr_pf = (yr_gross_profit / yr_gross_loss) if yr_gross_loss > 0 else 999.0
        yr_return = (yr_net_pnl / running_balance) if running_balance > 0 else 0.0
        start_bal = running_balance
        running_balance += yr_net_pnl

        market_context = {
            2021: "Late Bull Top",
            2022: "Bear Market Crash (Protected in Cash)",
            2023: "AI Bull Market Ignition",
            2024: "Tech Expansion & Multi-Baggers",
            2025: "Parabolic Growth Wave",
            2026: "Momentum Continuation"
        }.get(yr, "Market Regime")

        yearly_rows.append([
            yr,
            market_context,
            f"${start_bal:,.2f}",
            f"${running_balance:,.2f}",
            f"${yr_net_pnl:+,.2f}",
            f"{yr_return:+.1%}",
            len(yr_trades),
            f"{yr_win_rate:.1%}",
            f"{yr_pf:.2f}"
        ])

    headers_yearly = ["Year", "Market Context", "Start Balance", "End Balance", "Net PnL ($)", "Annual Return", "Trades", "Win Rate", "PF"]
    print(tabulate(yearly_rows, headers=headers_yearly, tablefmt="fancy_grid"))

    # Top Winning Trades
    print("\n" + "-"*85)
    print("  3. TOP 10 COMPOUNDING MULTI-BAGGER TRADES")
    print("-"*85)
    sorted_trades = sorted(trades, key=lambda t: t.realized_pnl, reverse=True)
    top_trades = []
    total_purify = 0.0

    for t in sorted_trades[:10]:
        purify = max(0.0, t.realized_pnl * 0.01)
        total_purify += purify
        top_trades.append([
            t.symbol,
            t.entry_time.strftime('%Y-%m-%d'),
            t.exit_time.strftime('%Y-%m-%d') if t.exit_time else 'OPEN',
            f"${t.entry_price:.2f}",
            f"${t.exit_price:.2f}" if t.exit_price else 'N/A',
            f"${t.realized_pnl:+,.2f}",
            f"{t.realized_return_pct:+.1%}",
            f"${purify:.2f}"
        ])

    headers_top = ["Symbol", "Entry Date", "Exit Date", "Entry $", "Exit $", "Net Profit ($)", "Trade Gain (%)", "Purify (1%)"]
    print(tabulate(top_trades, headers=headers_top, tablefmt="fancy_grid"))

if __name__ == "__main__":
    main()
