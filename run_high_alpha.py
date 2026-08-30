"""
High-Alpha 5-Year Portfolio Backtest Runner.
"""

from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.strategies.high_alpha_trend import HighAlphaTrendRiderStrategy
from autotrader.learning.optimizer import simulate_high_alpha_portfolio

def main():
    symbols = ['NVDA', 'TSLA', 'AMD', 'AAPL', 'MSFT', 'AMZN', 'META', 'GOOGL']
    provider = YFinanceProvider()
    data = {}
    for s in symbols:
        df = provider.fetch_historical_bars(s, timeframe='1d', period='5y')
        if not df.empty and len(df) >= 100:
            data[s] = df

    report, trades = simulate_high_alpha_portfolio(
        HighAlphaTrendRiderStrategy,
        params={},
        symbol_data=data,
        initial_capital=100000.0,
        allocation_pct=0.50,
        trailing_atr_mult=2.5
    )

    print("\n" + "="*65)
    print("  HIGH-ALPHA INFINITE TREND RIDER: 5-YEAR PORTFOLIO RESULTS")
    print("="*65)
    results = [
        ["Initial Capital", "$100,000.00"],
        ["Final Capital", f"${100000.0 + report.total_pnl:,.2f}"],
        ["Total Net Profit", f"${report.total_pnl:+,.2f}"],
        ["Total Cumulative Return", f"{report.total_return_pct:+.2%}"],
        ["Total Trades", report.total_trades],
        ["Winning / Losing Trades", f"{report.winning_trades} / {report.losing_trades}"],
        ["Win Rate", f"{report.win_rate:.1%}"],
        ["Profit Factor", f"{report.profit_factor:.2f}"],
        ["Average Winning Trade", f"${report.avg_win:,.2f}"],
        ["Average Losing Trade", f"${report.avg_loss:,.2f}"],
        ["Payoff Ratio (R:R)", f"{report.payoff_ratio:.2f}"],
        ["Sharpe Ratio", f"{report.sharpe_ratio:.2f}"],
        ["Max Drawdown (%)", f"{report.max_drawdown_pct:.2%}"]
    ]
    print(tabulate(results, headers=["Metric", "Value"], tablefmt="fancy_grid"))

    print("\n--- Top Winning Multi-Bagging Trades ---")
    sorted_trades = sorted(trades, key=lambda t: t.realized_pnl, reverse=True)
    top_trades = []
    for t in sorted_trades[:5]:
        top_trades.append([
            t.symbol,
            t.entry_time.strftime('%Y-%m-%d'),
            t.exit_time.strftime('%Y-%m-%d') if t.exit_time else 'OPEN',
            f"${t.entry_price:.2f}",
            f"${t.exit_price:.2f}" if t.exit_price else 'N/A',
            f"${t.realized_pnl:+,.2f}",
            f"{t.realized_return_pct:+.1%}"
        ])
    print(tabulate(top_trades, headers=["Symbol", "Entry", "Exit", "Entry $", "Exit $", "PnL", "Gain %"], tablefmt="fancy_grid"))

if __name__ == "__main__":
    main()
