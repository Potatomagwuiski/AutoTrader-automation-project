"""
High-Velocity Intraday Halal Catalyst & Liquidity Scalper Strategy.
Operates on 5m / 15m intraday bars:
- High trade velocity: Enters on intraday RVOL >= 2.5x surges & VWAP bounces.
- Tight invalidation: Stop loss at recent swing pivot / 1.0 ATR (0.4% - 0.8% risk).
- Asymmetric Intraday Target: 3.0R - 4.0R expansion targets.
- High Capital Turnover: Closes positions within the session, recycling cash 100+ times/year.
"""

from datetime import datetime
import pandas as pd
from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.strategies.catalyst_scalper import CatalystScalperStrategy
from autotrader.strategies.liquidity_sweep import LiquiditySweepStrategy
from autotrader.learning.optimizer import simulate_high_alpha_portfolio

def main():
    halal_universe = ["NVDA", "TSLA", "AMD", "PLTR", "CRWD", "QCOM", "ARM"]
    provider = YFinanceProvider()

    print("\n" + "="*80)
    print("  HIGH-VELOCITY INTRADAY HALAL CATALYST SCALPING BACKTEST (5m / 15m Bars)")
    print("  (High Trade Frequency • Spot Cash Execution • Tight Asymmetric Invalidation)")
    print("="*80)

    # Fetch 60-day 5-minute intraday dataset (maximum available intraday bar resolution from Yahoo)
    symbol_data = {}
    for sym in halal_universe:
        df = provider.fetch_historical_bars(sym, timeframe="5m", period="60d")
        if not df.empty and len(df) >= 100:
            symbol_data[sym] = df

    if not symbol_data:
        print("No intraday data available.")
        return

    initial_capital = 50000.0
    report, trades = simulate_high_alpha_portfolio(
        CatalystScalperStrategy,
        params={"min_rvol": 1.8, "target_rr": 3.0, "tight_atr_stop": 1.0},
        symbol_data=symbol_data,
        initial_capital=initial_capital,
        allocation_pct=0.40,
        trailing_atr_mult=1.5
    )

    final_capital = initial_capital + report.total_pnl

    print(f"Loaded {sum(len(df) for df in symbol_data.values())} 5-minute intraday bars across {len(symbol_data)} Halal assets.\n")

    results = [
        ["Testing Period", "60-Day Intraday Active Window"],
        ["Initial Capital", f"${initial_capital:,.2f}"],
        ["Final Account Balance", f"${final_capital:,.2f}"],
        ["Total Realized Profit", f"${report.total_pnl:+,.2f}"],
        ["60-Day Net Return (%)", f"{(report.total_pnl / initial_capital):+.2%}"],
        ["Estimated Annualized Return (CAGR)", f"{((1 + (report.total_pnl / initial_capital))**6 - 1):+.2%}"],
        ["Total Intraday Trades", report.total_trades],
        ["Winning / Losing Trades", f"{report.winning_trades} / {report.losing_trades}"],
        ["Win Rate", f"{report.win_rate:.1%}"],
        ["Profit Factor", f"{report.profit_factor:.2f}"],
        ["Average Winning Trade", f"${report.avg_win:,.2f}"],
        ["Average Losing Trade", f"${report.avg_loss:,.2f}"],
        ["Payoff Ratio (R:R)", f"{report.payoff_ratio:.2f}"],
        ["Sharpe Ratio", f"{report.sharpe_ratio:.2f}"],
        ["Max Drawdown (%)", f"{report.max_drawdown_pct:.2%}"]
    ]
    print(tabulate(results, headers=["Intraday Metric", "Value"], tablefmt="fancy_grid"))

    print("\n--- Recent Top Winning Intraday Scalp Trades ---")
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
    print(tabulate(top_trades, headers=["Symbol", "Entry Time", "Exit Time", "Entry $", "Exit $", "Net Profit ($)", "Gain %"], tablefmt="fancy_grid"))

if __name__ == "__main__":
    main()
