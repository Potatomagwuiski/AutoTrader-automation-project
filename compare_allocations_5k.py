"""
Allocation Percentage Sensitivity Analysis on $5,000 Small Account.
Compares 25%, 40%, 50%, 75%, and 100% capital allocation per position.
"""

from datetime import datetime
import pandas as pd
from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.strategies.halal_trend_rotator import HalalTrendRotatorStrategy
from autotrader.learning.optimizer import simulate_high_alpha_portfolio

def main():
    initial_capital = 5000.0
    provider = YFinanceProvider()

    halal_symbols = ["NVDA", "AMD", "TSLA", "PLTR", "CRWD", "ARM"]
    symbol_data = {}
    for s in halal_symbols:
        df = provider.fetch_historical_bars(s, timeframe="1d", period="5y")
        if not df.empty and len(df) >= 150:
            symbol_data[s] = df

    allocations = [0.25, 0.40, 0.50, 0.75, 1.00]
    comparison_results = []

    for alloc in allocations:
        report, trades = simulate_high_alpha_portfolio(
            HalalTrendRotatorStrategy,
            params={},
            symbol_data=symbol_data,
            initial_capital=initial_capital,
            allocation_pct=alloc,
            trailing_atr_mult=2.4
        )

        final_balance = initial_capital + report.total_pnl
        max_positions = int(1.0 / alloc) if alloc > 0 else 1
        cash_buffer_pct = max(0.0, 1.0 - (max_positions * alloc))

        comparison_results.append([
            f"{alloc:.0%}",
            max_positions,
            f"{cash_buffer_pct:.0%}",
            f"${initial_capital:,.0f}",
            f"${final_balance:,.2f}",
            f"${report.total_pnl:+,.2f}",
            f"{(report.total_pnl / initial_capital):+.2%}",
            f"{report.win_rate:.1%}",
            report.total_trades,
            f"{report.profit_factor:.2f}",
            f"{report.sharpe_ratio:.2f}",
            f"{report.max_drawdown_pct:.1%}"
        ])

    print("\n" + "="*95)
    print("  ALLOCATION PERCENTAGE SENSITIVITY MATRIX ($5,000 SMALL ACCOUNT)")
    print("="*95)
    headers = [
        "Alloc / Trade",
        "Max Positions",
        "Cash Buffer",
        "Start $",
        "Final Balance",
        "Net Profit ($)",
        "5-Yr Return",
        "Win Rate",
        "Trades",
        "PF",
        "Sharpe",
        "Max DD"
    ]
    print(tabulate(comparison_results, headers=headers, tablefmt="fancy_grid"))

if __name__ == "__main__":
    main()
