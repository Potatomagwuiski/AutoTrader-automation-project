"""
Halal Hourly (1h) Swing & Catalyst Rotator Strategy Backtest.
Combines the cleanliness of macro trends with higher trade frequency on 1-hour candles.
"""

from datetime import datetime
import pandas as pd
from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.strategies.halal_trend_rotator import HalalTrendRotatorStrategy
from autotrader.learning.optimizer import simulate_high_alpha_portfolio

def main():
    halal_universe = ["NVDA", "AMD", "TSLA", "PLTR", "ASML", "CRWD", "ARM"]
    provider = YFinanceProvider()

    print("\n" + "="*80)
    print("  HALAL HOURLY (1H) HIGH-ALPHA SWING ROTATOR BACKTEST (2-Year Window)")
    print("  (Eliminates 5m noise • Captures Multi-Day Swings • 100% Halal Spot Ownership)")
    print("="*80)

    symbol_data = {}
    for sym in halal_universe:
        df = provider.fetch_historical_bars(sym, timeframe="1h", period="730d")
        if not df.empty and len(df) >= 200:
            symbol_data[sym] = df

    initial_capital = 100000.0
    report, trades = simulate_high_alpha_portfolio(
        HalalTrendRotatorStrategy,
        params={"macro_regime_ema": 100, "fast_ema": 9, "slow_ema": 21, "chandelier_atr_mult": 2.2},
        symbol_data=symbol_data,
        initial_capital=initial_capital,
        allocation_pct=0.40,
        trailing_atr_mult=2.2
    )

    final_capital = initial_capital + report.total_pnl

    results = [
        ["Initial Capital", f"${initial_capital:,.2f}"],
        ["Final Account Balance", f"${final_capital:,.2f}"],
        ["Total Net Realized Profit", f"${report.total_pnl:+,.2f}"],
        ["2-Year Cumulative Return", f"{(report.total_pnl / initial_capital):+.2%}"],
        ["Estimated Annualized Return (CAGR)", f"{((1 + (report.total_pnl / initial_capital))**0.5 - 1):+.2%}"],
        ["Total Closed Trades", report.total_trades],
        ["Winning / Losing Trades", f"{report.winning_trades} / {report.losing_trades}"],
        ["Win Rate", f"{report.win_rate:.1%}"],
        ["Profit Factor", f"{report.profit_factor:.2f}"],
        ["Average Win / Loss", f"${report.avg_win:,.2f} / ${report.avg_loss:,.2f}"],
        ["Payoff Ratio (R:R)", f"{report.payoff_ratio:.2f}"],
        ["Sharpe Ratio", f"{report.sharpe_ratio:.2f}"],
        ["Max Drawdown (%)", f"{report.max_drawdown_pct:.2%}"]
    ]
    print(tabulate(results, headers=["1-Hour Swing Metric", "Value"], tablefmt="fancy_grid"))

    print("\n--- Top Winning 1-Hour Swing Trades ---")
    sorted_trades = sorted(trades, key=lambda t: t.realized_pnl, reverse=True)
    top_trades = []
    for t in sorted_trades[:8]:
        top_trades.append([
            t.symbol,
            t.entry_time.strftime('%Y-%m-%d %H:%M'),
            t.exit_time.strftime('%Y-%m-%d %H:%M') if t.exit_time else 'OPEN',
            f"${t.entry_price:.2f}",
            f"${t.exit_price:.2f}" if t.exit_price else 'N/A',
            f"${t.realized_pnl:+,.2f}",
            f"{t.realized_return_pct:+.1%}"
        ])
    print(tabulate(top_trades, headers=["Symbol", "Entry", "Exit", "Entry $", "Exit $", "Net Profit ($)", "Gain %"], tablefmt="fancy_grid"))

if __name__ == "__main__":
    main()
