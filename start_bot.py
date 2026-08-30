"""
AutoTrader Autonomous Master Launcher.
Unified CLI to launch:
1. Alpaca Live Paper Trading Bot (Autonomous Execution)
2. Alpaca Real Live Trading Bot (Production Funds)
3. 10-Year Historical Multi-Account Backtester
4. Live AAOIFI Shariah Compliance Audit & Dynamic Universe Scanner
"""

import sys
import os
import asyncio
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt

from autotrader.config.settings import settings
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.execution.alpaca_handler import AlpacaExecutionHandler
from autotrader.execution.paper_engine import PaperExecutionEngine
from autotrader.screening.shariah_rules_engine import ShariahRulesEngine
from autotrader.screening.shariah_compliance_daemon import ShariahComplianceDaemon
from autotrader.screening.dynamic_universe_scanner import DynamicHalalUniverseScanner
from autotrader.engine import AutoTraderEngine

console = Console()

async def launch_live_trading(is_paper: bool = True):
    mode_str = "PAPER TRADING (Sandbox)" if is_paper else "REAL PRODUCTION TRADING (Live Capital)"
    color = "green" if is_paper else "red"

    console.print(Panel.fit(
        f"[bold {color}]🚀 STARTING AUTOTRADER {mode_str}[/bold {color}]\n"
        "[cyan]Features: Fixed 2-Position Alpha Mode (48.5% Sizing) | Musaffa 30% AAOIFI Shariah Filter | Canary AI Sandbox[/cyan]",
        border_style=color
    ))

    api_key = settings.ALPACA_API_KEY
    secret_key = settings.ALPACA_SECRET_KEY

    provider = YFinanceProvider()

    if api_key and secret_key and "your_" not in api_key.lower():
        execution = AlpacaExecutionHandler(
            api_key=api_key,
            secret_key=secret_key,
            is_paper=is_paper
        )
        console.print(f"[bold green]✅ Connected to Alpaca ({'Paper' if is_paper else 'Live'}).[/bold green]")
    else:
        console.print("[yellow]⚠️ Alpaca API credentials not set in .env. Running local high-fidelity paper engine.[/yellow]")
        execution = PaperExecutionEngine(initial_capital=5000.0)

    # Initialize Engine & Daemon
    engine = AutoTraderEngine(
        data_provider=provider,
        execution_handler=execution
    )
    shariah_daemon = ShariahComplianceDaemon(
        data_provider=provider,
        execution_handler=execution
    )

    console.print("[bold cyan]🔄 Running initial universe scan & balance sheet audit...[/bold cyan]")
    symbols = await engine.run_screening_cycle()
    console.print(f"[bold green]🎯 Top 2 Active Momentum Leaders Selected: {symbols}[/bold green]")

    # Run trading loop
    console.print("\n[bold white]Press Ctrl+C to stop the bot at any time.[/bold white]\n")
    try:
        shariah_task = asyncio.create_task(shariah_daemon.run_daemon_loop(interval_seconds=3600))
        await engine.start()
    except (KeyboardInterrupt, asyncio.CancelledError):
        console.print("\n[bold yellow]🛑 Gracefully shutting down AutoTrader engine...[/bold yellow]")
        engine.stop()


def main():
    console.print(Panel.fit(
        "[bold cyan]AUTOTRADER AI: AUTONOMOUS HALAL ALGORITHMIC TRADING SYSTEM[/bold cyan]\n"
        "[white]100% Shariah Compliant (AAOIFI Standard) | Powered by Deep Learning & Evolutionary Quants[/white]",
        border_style="cyan"
    ))

    console.print("[bold white]Select an operation to run:[/bold white]")
    console.print("  [1] Launch Alpaca Paper Trading (Simulated Sandbox)")
    console.print("  [2] Launch Alpaca Live Real Trading (Real Funds)")
    console.print("  [3] Run 10-Year Multi-Account Master Backtest ($1k, $5k, $50k)")
    console.print("  [4] Run Live Shariah Balance Sheet Audit & Dynamic Scanner")
    console.print("  [5] 💰 Autonomous Profit Harvest & Salary Withdrawal Advisor")
    console.print("  [6] Exit")

    choice = Prompt.ask("\nEnter choice", choices=["1", "2", "3", "4", "5", "6"], default="1")

    if choice == "1":
        asyncio.run(launch_live_trading(is_paper=True))
    elif choice == "2":
        confirm = Prompt.ask("[bold red]Are you sure you want to run with REAL money?[/bold red]", choices=["y", "n"], default="n")
        if confirm == "y":
            asyncio.run(launch_live_trading(is_paper=False))
        else:
            console.print("[yellow]Cancelled real trading launch.[/yellow]")
    elif choice == "3":
        from backtest_master_verification import main as run_master_bt
        run_master_bt()
    elif choice == "4":
        from run_live_system_verification import run_system_test
        run_system_test()
    elif choice == "5":
        from autotrader.risk.harvest_manager import ProfitHarvestAdvisor
        from autotrader.execution.paper_engine import PaperExecutionEngine
        
        # Check current equity from Alpaca if configured, else prompt or use default
        api_key = settings.ALPACA_API_KEY
        secret_key = settings.ALPACA_SECRET_KEY
        current_eq = 534516.35
        if api_key and secret_key and "your_" not in api_key.lower():
            alpaca = AlpacaExecutionHandler(api_key=api_key, secret_key=secret_key, is_paper=True)
            current_eq = alpaca.get_account_equity()
        else:
            eq_input = Prompt.ask("Enter current account equity for harvest evaluation", default="534516.35")
            try:
                current_eq = float(eq_input.replace("$", "").replace(",", ""))
            except ValueError:
                current_eq = 534516.35

        advisor = ProfitHarvestAdvisor(target_annual_salary=80000.0, locked_growth_floor=100000.0)
        decision = advisor.evaluate_harvest(current_equity=current_eq, withdrawn_ytd=0.0)
        advisor.print_harvest_dashboard(decision)
    else:
        console.print("[cyan]Goodbye![/cyan]")

if __name__ == "__main__":
    main()
