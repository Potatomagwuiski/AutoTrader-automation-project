"""
Comprehensive 5-Year Halal Strategy Backtest with Year-by-Year Breakdown.
"""

from datetime import datetime
import pandas as pd
from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.screening.halal_screener import HalalShariahScreener
from autotrader.strategies.halal_trend_rotator import HalalTrendRotatorStrategy
from autotrader.learning.optimizer import simulate_high_alpha_portfolio
from autotrader.telemetry.metrics import calculate_performance

def main():
    halal_universe = ["NVDA", "AMD", "TSLA", "PLTR", "ASML", "QCOM", "CRWD"]
    provider = YFinanceProvider()
    screener = HalalShariahScreener()

    print("\n" + "="*80)
    print("  100% HALAL SPOT STRATEGY 5-YEAR BACKTEST (2021 - 2026)")
    print("="*80)

    symbol_data = {}
    for sym in halal_universe:
        df = provider.fetch_historical_bars(sym, timeframe="1d", period="5y")
        if not df.empty and len(df) >= 200:
            symbol_data[sym] = df

    initial_capital = 100000.0
    report, trades = simulate_high_alpha_portfolio(
        HalalTrendRotatorStrategy,
        params={},
        symbol_data=symbol_data,
        initial_capital=initial_capital,
        allocation_pct=0.40,
        trailing_atr_mult=2.4
    )

    final_capital = initial_capital + report.total_pnl

    # Overall Metrics Table
    overall_table = [
        ["Initial Capital", f"${initial_capital:,.2f}"],
        ["Final Account Balance", f"${final_capital:,.2f}"],
        ["Total Net Profit", f"${report.total_pnl:+,.2f}"],
        ["Total Net Return", f"{(report.total_pnl / initial_capital):+.2%}"],
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

    # Year-by-Year Performance Table
    print("\n" + "="*80)
    print("  YEAR-BY-YEAR PERFORMANCE BREAKDOWN (Market Cycle Analysis)")
    print("="*80)

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
            2021: "Late Bull Peak",
            2022: "Bear Market Crash (Protected in Cash)",
            2023: "AI Bull Market Ignition",
            2024: "Tech Expansion & Multi-Baggers",
            2025: "Parabolic AI Growth",
            2026: "Mature Momentum Continuation"
        }.get(yr, "Market Cycle")

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

    # Asset Performance Table
    print("\n" + "="*80)
    print("  ASSET-BY-ASSET BREAKDOWN")
    print("="*80)

    trades_by_asset = {}
    for t in trades:
        if t.symbol not in trades_by_asset:
            trades_by_asset[t.symbol] = []
        trades_by_asset[t.symbol].append(t)

    asset_rows = []
    for sym, s_trades in sorted(trades_by_asset.items()):
        s_pnls = [t.realized_pnl for t in s_trades]
        s_net_pnl = sum(s_pnls)
        s_wins = [p for p in s_pnls if p > 0]
        s_win_rate = len(s_wins) / len(s_trades) if s_trades else 0.0
        s_pf = (sum(s_wins) / abs(sum([p for p in s_pnls if p < 0]))) if any(p < 0 for p in s_pnls) else 999.0
        best_trade = max(s_pnls) if s_pnls else 0.0

        asset_rows.append([
            sym,
            len(s_trades),
            f"{s_win_rate:.1%}",
            f"${s_net_pnl:+,.2f}",
            f"{s_pf:.2f}",
            f"${best_trade:+,.2f}"
        ])

    headers_asset = ["Symbol", "Total Trades", "Win Rate", "Net Profit ($)", "Profit Factor", "Best Single Trade ($)"]
    print(tabulate(asset_rows, headers=headers_asset, tablefmt="fancy_grid"))

if __name__ == "__main__":
    main()
