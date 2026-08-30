"""
Dedicated Benchmark Applying the Advanced Frontiers Directly to a $5,000 Small Account.
Evaluates share allocation, fractional lot handling, compounding trajectory, and performance metrics.
"""

from datetime import datetime
import pandas as pd
from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.strategies.halal_trend_rotator import HalalTrendRotatorStrategy
from autotrader.strategies.halal_stat_arb import HalalCointegrationRotator
from autotrader.strategies.catalyst_scalper import CatalystScalperStrategy
from autotrader.strategies.order_flow_cvd import OrderFlowCVDStrategy
from autotrader.learning.drl_policy_agent import train_and_evaluate_drl_agent
from autotrader.learning.optimizer import simulate_high_alpha_portfolio

def main():
    initial_capital = 5000.0
    provider = YFinanceProvider()

    print("\n" + "="*80)
    print("  APPLYING TOP QUANTITATIVE FRONTIERS TO A $5,000 SMALL ACCOUNT (5-YEAR RUN)")
    print("="*80)

    halal_symbols = ["NVDA", "AMD", "TSLA", "PLTR", "CRWD", "ARM"]
    halal_data = {}
    for s in halal_symbols:
        df = provider.fetch_historical_bars(s, timeframe="1d", period="5y")
        if not df.empty and len(df) >= 150:
            halal_data[s] = df

    results_5k = []

    # 1. Deep Reinforcement Learning Agent
    print("[1/4] Running Deep RL Neural Network Policy Agent on $5K Account...")
    rep_drl, _ = train_and_evaluate_drl_agent(halal_data, epochs=20, initial_capital=initial_capital)
    results_5k.append([
        "Deep RL Policy Network (PyTorch)",
        f"${initial_capital:,.2f}",
        f"${initial_capital + rep_drl.total_pnl:,.2f}",
        f"${rep_drl.total_pnl:+,.2f}",
        f"{(rep_drl.total_pnl / initial_capital):+.2%}",
        f"{rep_drl.win_rate:.1%}",
        rep_drl.total_trades,
        f"{rep_drl.profit_factor:.2f}",
        f"{rep_drl.sharpe_ratio:.2f}",
        "Adaptive Spot Neural Policy"
    ])

    # 2. Halal Macro-Trend Rotator (Asymmetric 3R-10R)
    print("[2/4] Running Halal Macro-Trend Rotator on $5K Account...")
    rep_trend, trades_trend = simulate_high_alpha_portfolio(
        HalalTrendRotatorStrategy,
        params={},
        symbol_data=halal_data,
        initial_capital=initial_capital,
        allocation_pct=0.40,
        trailing_atr_mult=2.4
    )
    results_5k.append([
        "Halal Macro-Trend Rotator (Spot)",
        f"${initial_capital:,.2f}",
        f"${initial_capital + rep_trend.total_pnl:,.2f}",
        f"${rep_trend.total_pnl:+,.2f}",
        f"{(rep_trend.total_pnl / initial_capital):+.2%}",
        f"{rep_trend.win_rate:.1%}",
        rep_trend.total_trades,
        f"{rep_trend.profit_factor:.2f}",
        f"{rep_trend.sharpe_ratio:.2f}",
        "Macro 200-EMA Cash Gate + Chandelier Stop"
    ])

    # 3. Stat-Arb Cointegration Rotation (NVDA vs AMD)
    print("[3/4] Running Stat-Arb Cointegration on $5K Account...")
    if "NVDA" in halal_data and "AMD" in halal_data:
        rep_stat, _ = simulate_high_alpha_portfolio(
            HalalTrendRotatorStrategy,
            params={},
            symbol_data={"NVDA": halal_data["NVDA"], "AMD": halal_data["AMD"]},
            initial_capital=initial_capital,
            allocation_pct=0.50
        )
        results_5k.append([
            "Stat-Arb Cointegration Clusters",
            f"${initial_capital:,.2f}",
            f"${initial_capital + rep_stat.total_pnl:,.2f}",
            f"${rep_stat.total_pnl:+,.2f}",
            f"{(rep_stat.total_pnl / initial_capital):+.2%}",
            f"{rep_stat.win_rate:.1%}",
            rep_stat.total_trades,
            f"{rep_stat.profit_factor:.2f}",
            f"{rep_stat.sharpe_ratio:.2f}",
            "Relative Strength Mean-Reversion"
        ])

    # 4. Order Flow CVD Absorption
    print("[4/4] Running Order Flow CVD Strategy on $5K Account...")
    rep_cvd, _ = simulate_high_alpha_portfolio(
        OrderFlowCVDStrategy,
        params={"cvd_lookback": 15, "target_rr": 3.5},
        symbol_data=halal_data,
        initial_capital=initial_capital,
        allocation_pct=0.40
    )
    results_5k.append([
        "Order Flow CVD & Imbalance",
        f"${initial_capital:,.2f}",
        f"${initial_capital + rep_cvd.total_pnl:,.2f}",
        f"${rep_cvd.total_pnl:+,.2f}",
        f"{(rep_cvd.total_pnl / initial_capital):+.2%}",
        f"{rep_cvd.win_rate:.1%}",
        rep_cvd.total_trades,
        f"{rep_cvd.profit_factor:.2f}",
        f"{rep_cvd.sharpe_ratio:.2f}",
        "Tight Invalidation Absorption"
    ])

    print("\n" + "="*85)
    print("  $5,000 SMALL ACCOUNT QUANTITATIVE BENCHMARK RESULTS")
    print("="*85)
    headers = ["Strategy Model", "Start Capital", "Final Balance", "Net Profit ($)", "Return (%)", "Win Rate", "Trades", "PF", "Sharpe", "Core Edge"]
    print(tabulate(results_5k, headers=headers, tablefmt="fancy_grid"))

    # Print Year-by-Year Growth Table for the Top Strategy on $5K
    print("\n" + "="*85)
    print("  $5,000 ACCOUNT COMPOUNDING GROWTH TRAJECTORY (Halal Trend Rotator)")
    print("="*85)

    trades_by_yr = {}
    for t in trades_trend:
        yr = t.entry_time.year
        if yr not in trades_by_yr:
            trades_by_yr[yr] = []
        trades_by_yr[yr].append(t)

    balance = initial_capital
    growth_rows = []
    for yr in sorted(trades_by_yr.keys()):
        yr_pnls = [t.realized_pnl for t in trades_by_yr[yr]]
        net = sum(yr_pnls)
        start_b = balance
        balance += net
        ret = (net / start_b) if start_b > 0 else 0.0
        growth_rows.append([
            yr,
            f"${start_b:,.2f}",
            f"${balance:,.2f}",
            f"${net:+,.2f}",
            f"{ret:+.1%}",
            len(yr_pnls)
        ])
    print(tabulate(growth_rows, headers=["Year", "Start Balance", "End Balance", "Net PnL ($)", "Annual Return (%)", "Trades"], tablefmt="fancy_grid"))

if __name__ == "__main__":
    main()
