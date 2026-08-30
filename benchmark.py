"""
Comprehensive Multi-Strategy & Multi-Account-Tier Benchmark Engine.
Tests all strategies across Small ($5k), Mid ($50k), and Big ($250k) capital accounts.
"""

from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.strategies.momentum_breakout import MomentumBreakoutStrategy
from autotrader.strategies.trend_following import AsymmetricTrendFollowingStrategy
from autotrader.strategies.catalyst_scalper import CatalystScalperStrategy
from autotrader.strategies.liquidity_sweep import LiquiditySweepStrategy
from autotrader.strategies.vwap_pullback import VWAPPullbackStrategy
from autotrader.strategies.mean_reversion import MeanReversionStrategy
from autotrader.learning.optimizer import simulate_portfolio
from autotrader.telemetry.logger import console

ACCOUNT_TIERS = {
    "Small Account ($5K)": 5000.0,
    "Mid Account ($50K)": 50000.0,
    "Big Account ($250K)": 250000.0
}

STRATEGIES = {
    "Asymmetric Trend-Following (5R)": AsymmetricTrendFollowingStrategy,
    "Catalyst Scalper (3R)": CatalystScalperStrategy,
    "Liquidity Sweep / Order Flow (4R)": LiquiditySweepStrategy,
    "Momentum Breakout (2R)": MomentumBreakoutStrategy,
    "VWAP Pullback (2.5R)": VWAPPullbackStrategy,
    "Mean Reversion": MeanReversionStrategy
}

def run_comprehensive_benchmark(symbols: list[str], period: str = "5y", timeframe: str = "1d"):
    """
    Executes benchmark matrix across all strategies and account tiers.
    """
    console.print(f"[bold cyan]Fetching {period} historical data for {len(symbols)} symbols: {', '.join(symbols)}...[/bold cyan]")
    provider = YFinanceProvider()
    symbol_data = {}
    for sym in symbols:
        df = provider.fetch_historical_bars(sym, timeframe=timeframe, period=period)
        if not df.empty and len(df) >= 50:
            symbol_data[sym] = df

    if not symbol_data:
        console.print("[red]Failed to load market data for benchmark.[/red]")
        return

    console.print(f"[green]Successfully loaded data for {len(symbol_data)} assets. Running benchmark simulations...[/green]\n")

    # Table 1: Strategy comparison on standard Mid Account ($50k)
    mid_capital = 50000.0
    mid_table = []
    strat_reports = {}

    for strat_name, strat_cls in STRATEGIES.items():
        report, _ = simulate_portfolio(strat_cls, params={}, symbol_data=symbol_data, initial_capital=mid_capital)
        strat_reports[strat_name] = report
        mid_table.append([
            strat_name,
            f"${report.total_pnl:+,.2f}",
            f"{report.total_return_pct:+.2%}",
            f"{report.win_rate:.1%}",
            report.total_trades,
            f"{report.profit_factor:.2f}",
            f"${report.avg_win:,.2f} / ${report.avg_loss:,.2f}",
            f"{report.sharpe_ratio:.2f}",
            f"{report.max_drawdown_pct:.2%}"
        ])

    console.print("[bold yellow]========================================================================[/bold yellow]")
    console.print("[bold yellow]  1. STRATEGY COMPARISON BENCHMARK (Mid Account: $50,000 Base)          [/bold yellow]")
    console.print("[bold yellow]========================================================================[/bold yellow]")
    headers1 = ["Strategy", "Net PnL ($)", "Return (%)", "Win Rate", "Trades", "Profit Factor", "Avg Win/Loss", "Sharpe", "Max DD"]
    print(tabulate(mid_table, headers=headers1, tablefmt="fancy_grid"))

    # Table 2: Multi-Account Tier Growth Comparison
    tier_table = []
    for tier_name, initial_cap in ACCOUNT_TIERS.items():
        for strat_name in ["Asymmetric Trend-Following (5R)", "Catalyst Scalper (3R)", "Momentum Breakout (2R)"]:
            strat_cls = STRATEGIES[strat_name]
            report, _ = simulate_portfolio(strat_cls, params={}, symbol_data=symbol_data, initial_capital=initial_cap)
            final_equity = initial_cap + report.total_pnl
            tier_table.append([
                tier_name,
                strat_name,
                f"${initial_cap:,.0f}",
                f"${final_equity:,.2f}",
                f"${report.total_pnl:+,.2f}",
                f"{report.total_return_pct:+.2%}",
                f"{report.win_rate:.1%}",
                report.total_trades,
                f"{report.profit_factor:.2f}"
            ])

    console.print("\n[bold yellow]========================================================================[/bold yellow]")
    console.print("[bold yellow]  2. MULTI-ACCOUNT CAPITAL SCALING COMPARISON ($5K vs $50K vs $250K)    [/bold yellow]")
    console.print("[bold yellow]========================================================================[/bold yellow]")
    headers2 = ["Account Tier", "Strategy", "Initial", "Final Balance", "Net PnL", "Return (%)", "Win Rate", "Trades", "PF"]
    print(tabulate(tier_table, headers=headers2, tablefmt="fancy_grid"))

if __name__ == "__main__":
    test_symbols = ["NVDA", "TSLA", "AMD", "AAPL", "MSFT", "AMZN", "META", "GOOGL"]
    run_comprehensive_benchmark(test_symbols, period="5y", timeframe="1d")
