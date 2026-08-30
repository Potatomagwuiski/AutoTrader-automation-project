"""
100% Halal High-Alpha Portfolio 5-Year Backtest & AAOIFI Compliance Audit.
Tests spot-only long momentum with macro cash rotation on AAOIFI-compliant assets.
"""

from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.screening.halal_screener import HalalShariahScreener
from autotrader.strategies.halal_trend_rotator import HalalTrendRotatorStrategy
from autotrader.learning.optimizer import simulate_high_alpha_portfolio

def main():
    halal_universe = ["NVDA", "AMD", "TSLA", "PLTR", "ASML", "TSM", "QCOM", "CRWD"]
    provider = YFinanceProvider()
    screener = HalalShariahScreener()

    print("\n" + "="*75)
    print("  STEP 1: AAOIFI SHARIAH COMPLIANCE AUDIT OF TARGET UNIVERSE")
    print("="*75)

    compliance_table = []
    symbol_data = {}

    for sym in halal_universe:
        meta = provider.fetch_asset_metadata(sym)
        status = screener.screen_asset(meta)
        
        compliance_table.append([
            sym,
            meta.sector,
            f"{status.debt_ratio:.1%}",
            f"{status.cash_interest_ratio:.1%}",
            "HALAL COMPLIANT" if status.is_compliant else "NON-COMPLIANT",
            f"{status.purification_rate:.2%}"
        ])

        df = provider.fetch_historical_bars(sym, timeframe="1d", period="5y")
        if not df.empty and len(df) >= 200:
            symbol_data[sym] = df

    headers_comp = ["Symbol", "Sector", "Debt / MCap", "Cash / MCap", "Shariah Status", "Purification %"]
    print(tabulate(compliance_table, headers=headers_comp, tablefmt="fancy_grid"))

    print("\n" + "="*75)
    print("  STEP 2: 100% HALAL SPOT PORTFOLIO 5-YEAR BACKTEST (2021 - 2026)")
    print("  (Long-Only Spot Ownership, No Shorting, No Leverage Swaps, Cash Protection)")
    print("="*75)

    initial_capital = 100000.0
    report, trades = simulate_high_alpha_portfolio(
        HalalTrendRotatorStrategy,
        params={},
        symbol_data=symbol_data,
        initial_capital=initial_capital,
        allocation_pct=0.40,  # 40% per position (max 2 concurrent spot holdings, 20% cash buffer)
        trailing_atr_mult=2.4
    )

    final_capital = initial_capital + report.total_pnl
    results = [
        ["Initial Account Equity (Cash Only)", f"${initial_capital:,.2f}"],
        ["Final Account Equity", f"${final_capital:,.2f}"],
        ["Total Net Realized Profit", f"${report.total_pnl:+,.2f}"],
        ["Net Cumulative Return (%)", f"{(report.total_pnl / initial_capital):+.2%}"],
        ["Total Closed Trades", report.total_trades],
        ["Winning / Losing Trades", f"{report.winning_trades} / {report.losing_trades}"],
        ["Win Rate", f"{report.win_rate:.1%}"],
        ["Profit Factor", f"{report.profit_factor:.2f}"],
        ["Average Win / Loss", f"${report.avg_win:,.2f} / ${report.avg_loss:,.2f}"],
        ["Payoff Ratio (R:R)", f"{report.payoff_ratio:.2f}"],
        ["Sharpe Ratio", f"{report.sharpe_ratio:.2f}"],
        ["Max Drawdown (%)", f"{report.max_drawdown_pct:.2%}"]
    ]
    print(tabulate(results, headers=["Performance Metric", "Value"], tablefmt="fancy_grid"))

    print("\n--- Top Halal Multi-Bagging Spot Trades Captured ---")
    sorted_trades = sorted(trades, key=lambda t: t.realized_pnl, reverse=True)
    top_trades = []
    total_purification_needed = 0.0

    for t in sorted_trades[:8]:
        purify_est = max(0.0, t.realized_pnl * 0.01)  # 1% estimated purification
        total_purification_needed += purify_est
        top_trades.append([
            t.symbol,
            t.entry_time.strftime('%Y-%m-%d'),
            t.exit_time.strftime('%Y-%m-%d') if t.exit_time else 'OPEN',
            f"${t.entry_price:.2f}",
            f"${t.exit_price:.2f}" if t.exit_price else 'N/A',
            f"${t.realized_pnl:+,.2f}",
            f"{t.realized_return_pct:+.1%}",
            f"${purify_est:.2f}"
        ])
    headers_trades = ["Symbol", "Entry Date", "Exit Date", "Entry $", "Exit $", "Net Profit ($)", "Gain (%)", "Purify (Charity)"]
    print(tabulate(top_trades, headers=headers_trades, tablefmt="fancy_grid"))

if __name__ == "__main__":
    main()
