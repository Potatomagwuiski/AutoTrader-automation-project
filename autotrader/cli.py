"""
Command Line Interface for AutoTrader.
"""

import argparse
import asyncio
import sys
from tabulate import tabulate
from autotrader.config.settings import settings
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.screening.screener import MultiStageScreener
from autotrader.strategies.momentum_breakout import MomentumBreakoutStrategy
from autotrader.strategies.vwap_pullback import VWAPPullbackStrategy
from autotrader.strategies.mean_reversion import MeanReversionStrategy
from autotrader.learning.optimizer import simulate_strategy, WalkForwardOptimizer
from autotrader.learning.strategy_mutator import StrategyMutator
from autotrader.learning.canary_sandbox import CanarySandbox
from autotrader.engine import AutoTraderEngine
from autotrader.telemetry.logger import console

def cmd_scan(args):
    """Runs multi-stage universe screener."""
    console.print(f"[bold cyan]Scanning universe ({len(settings.DEFAULT_WATCHLIST)} symbols)...[/bold cyan]")
    provider = YFinanceProvider()
    screener = MultiStageScreener(provider)
    qualified = screener.screen_universe(settings.DEFAULT_WATCHLIST, timeframe=args.timeframe)
    
    if not qualified:
        console.print("[yellow]No symbols met all 3 filtering criteria at this moment.[/yellow]")
        return

    table_data = []
    for q in qualified:
        table_data.append([
            q.symbol,
            f"${q.current_price:.2f}",
            f"{q.rvol:.2f}x",
            f"{q.metadata.shares_float / 1e6:.1f}M",
            q.metadata.sector,
            f"{q.metadata.interest_bearing_debt_pct:.1%}"
        ])

    headers = ["Symbol", "Price", "RVOL", "Float", "Sector", "Debt Ratio"]
    print("\n" + tabulate(table_data, headers=headers, tablefmt="fancy_grid"))

def cmd_backtest(args):
    """Runs backtest simulation on historical data (supports multi-year and multi-asset portfolio)."""
    provider = YFinanceProvider()
    symbols = [s.strip().upper() for s in args.symbol.split(",") if s.strip()]

    strat_map = {
        "momentum": MomentumBreakoutStrategy,
        "vwap": VWAPPullbackStrategy,
        "mean_reversion": MeanReversionStrategy
    }
    strat_cls = strat_map.get(args.strategy.lower(), MomentumBreakoutStrategy)

    if len(symbols) == 1:
        sym = symbols[0]
        console.print(f"[bold cyan]Running 5-Year Backtest on {sym} ({args.strategy}) | TF: {args.timeframe} | Period: {args.period}[/bold cyan]")
        df = provider.fetch_historical_bars(sym, timeframe=args.timeframe, period=args.period, limit=args.bars)
        
        if df.empty or len(df) < 50:
            console.print(f"[red]Insufficient historical data for {sym}.[/red]")
            return

        report = simulate_strategy(strat_cls, params={}, df=df, symbol=sym, initial_capital=args.capital)
    else:
        console.print(f"[bold cyan]Running 5-Year Portfolio Backtest across {len(symbols)} symbols: {', '.join(symbols)} | TF: {args.timeframe} | Period: {args.period}[/bold cyan]")
        symbol_data = {}
        for sym in symbols:
            df = provider.fetch_historical_bars(sym, timeframe=args.timeframe, period=args.period, limit=args.bars)
            if not df.empty and len(df) >= 50:
                symbol_data[sym] = df

        if not symbol_data:
            console.print("[red]No valid historical data retrieved for portfolio symbols.[/red]")
            return

        from autotrader.learning.optimizer import simulate_portfolio
        report, trades = simulate_portfolio(strat_cls, params={}, symbol_data=symbol_data, initial_capital=args.capital)

    results = [
        ["Initial Capital", f"${args.capital:,.2f}"],
        ["Total Trades", report.total_trades],
        ["Winning / Losing Trades", f"{report.winning_trades} / {report.losing_trades}"],
        ["Win Rate", f"{report.win_rate:.1%}"],
        ["Total Net PnL", f"${report.total_pnl:,.2f}"],
        ["Total Return", f"{report.total_return_pct:.2%}"],
        ["Profit Factor", f"{report.profit_factor:.2f}"],
        ["Average Win / Loss", f"${report.avg_win:,.2f} / ${report.avg_loss:,.2f}"],
        ["Payoff Ratio (R:R)", f"{report.payoff_ratio:.2f}"],
        ["Expectancy ($/Trade)", f"${report.expectancy:,.2f}"],
        ["Max Drawdown (%)", f"{report.max_drawdown_pct:.2%}"],
        ["Max Drawdown ($)", f"${report.max_drawdown_amount:,.2f}"],
        ["Sharpe Ratio", f"{report.sharpe_ratio:.2f}"],
        ["Sortino Ratio", f"{report.sortino_ratio:.2f}"],
        ["Calmar Ratio", f"{report.calmar_ratio:.2f}"]
    ]
    print("\n" + tabulate(results, headers=["Metric", "Value"], tablefmt="fancy_grid"))

def cmd_learn(args):
    """Executes parameter mutation and Canary Sandbox verification."""
    console.print(f"[bold cyan]Running Autonomous Learning & Adaptation on {args.symbol}...[/bold cyan]")
    provider = YFinanceProvider()
    df = provider.fetch_historical_bars(args.symbol, timeframe="5m", limit=300)
    
    if df.empty or len(df) < 100:
        console.print("[red]Insufficient data for training.[/red]")
        return

    mutator = StrategyMutator()
    canary = CanarySandbox()
    base_strat = MomentumBreakoutStrategy()
    
    population = mutator.generate_population(base_strat.params, population_size=6)
    console.print(f"[info]Generated {len(population)} mutated candidate parameter sets. Evaluating in Canary Sandbox...[/info]")

    for idx, params in enumerate(population, 1):
        promoted, report, rationale = canary.evaluate_candidate(
            strategy_cls=MomentumBreakoutStrategy,
            candidate_params=params,
            validation_df=df,
            symbol=args.symbol
        )
        status = "PROMOTED" if promoted else "REJECTED"
        color = "green" if promoted else "red"
        console.print(f"Candidate #{idx} [{status}]: {rationale}")

def cmd_run(args):
    """Runs the master trading engine."""
    engine = AutoTraderEngine()
    try:
        asyncio.run(engine.start())
    except KeyboardInterrupt:
        engine.stop()

def cmd_benchmark(args):
    """Runs comprehensive multi-strategy and multi-account benchmark."""
    symbols = [s.strip().upper() for s in args.symbol.split(",") if s.strip()]
    from benchmark import run_comprehensive_benchmark
    run_comprehensive_benchmark(symbols, period=args.period, timeframe=args.timeframe)

def main():
    parser = argparse.ArgumentParser(description="AutoTrader Autonomous System CLI")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Scan command
    scan_p = subparsers.add_parser("scan", help="Run 3-stage market universe screener")
    scan_p.add_argument("--timeframe", default="5m", help="Candle timeframe (1m, 5m, 15m, 1h, 1d)")

    # Backtest command
    bt_p = subparsers.add_parser("backtest", help="Run historical simulation backtest")
    bt_p.add_argument("--symbol", default="NVDA,AAPL,TSLA,AMD,MSFT", help="Ticker symbol(s) comma-separated")
    bt_p.add_argument("--strategy", default="momentum", choices=["momentum", "vwap", "mean_reversion", "trend", "catalyst", "sweep"])
    bt_p.add_argument("--timeframe", default="1d", help="Candle timeframe (1d, 1h, 15m, 5m)")
    bt_p.add_argument("--period", default="5y", help="Historical period (5y, 2y, 1y, 60d)")
    bt_p.add_argument("--bars", type=int, default=5000, help="Number of historical bars")
    bt_p.add_argument("--capital", type=float, default=100000.0, help="Starting capital")

    # Benchmark command
    bench_p = subparsers.add_parser("benchmark", help="Run multi-strategy multi-account benchmark")
    bench_p.add_argument("--symbol", default="NVDA,TSLA,AMD,AAPL,MSFT,AMZN,META,GOOGL", help="Ticker symbols")
    bench_p.add_argument("--period", default="5y", help="Historical period")
    bench_p.add_argument("--timeframe", default="1d", help="Candle timeframe")

    # Learn command
    learn_p = subparsers.add_parser("learn", help="Run self-improvement mutation & canary testing")
    learn_p.add_argument("--symbol", default="TSLA", help="Ticker symbol")

    # Run command
    run_p = subparsers.add_parser("run", help="Start the master autonomous engine")
    run_p.add_argument("--mode", default="paper", choices=["paper", "simulation", "live"])

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(0)

    if args.command == "scan":
        cmd_scan(args)
    elif args.command == "backtest":
        cmd_backtest(args)
    elif args.command == "benchmark":
        cmd_benchmark(args)
    elif args.command == "learn":
        cmd_learn(args)
    elif args.command == "run":
        cmd_run(args)

if __name__ == "__main__":
    main()
