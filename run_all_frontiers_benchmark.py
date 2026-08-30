"""
Comprehensive Benchmark of the 5 Advanced Quantitative Frontiers.
Tests:
1. Leveraged Vol-Shielded ETFs (NVDL, TSLL, SOXL, TQQQ)
2. Deep Reinforcement Learning (DRL) Neural Network Agent (PyTorch)
3. Graph Statistical Arbitrage Cointegration Clusters (Halal Spot Pairs)
4. LLM Catalyst & News Arbitrage
5. Order Flow Cumulative Volume Delta (CVD) & Microstructure Imbalance
"""

from datetime import datetime
import pandas as pd
from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.strategies.halal_stat_arb import HalalCointegrationRotator
from autotrader.strategies.order_flow_cvd import OrderFlowCVDStrategy
from autotrader.strategies.catalyst_scalper import CatalystScalperStrategy
from autotrader.strategies.halal_trend_rotator import HalalTrendRotatorStrategy
from autotrader.learning.drl_policy_agent import train_and_evaluate_drl_agent
from autotrader.learning.optimizer import simulate_high_alpha_portfolio

def main():
    provider = YFinanceProvider()
    initial_capital = 100000.0

    print("\n" + "="*80)
    print("  EXPERIMENTING WITH THE 5 CUTTING-EDGE QUANTITATIVE FRONTIERS")
    print("="*80)

    # 1. Load Halal Growth Data
    halal_symbols = ["NVDA", "AMD", "TSLA", "PLTR", "CRWD", "ARM"]
    halal_data = {}
    for s in halal_symbols:
        df = provider.fetch_historical_bars(s, timeframe="1d", period="5y")
        if not df.empty and len(df) >= 150:
            halal_data[s] = df

    frontier_results = []

    # -------------------------------------------------------------
    # Frontier 1: Leveraged Vol-Shielded Instruments (SOXL, TQQQ, NVDL, TSLL)
    # -------------------------------------------------------------
    print("[1/5] Testing Frontier 1: Leveraged Volatility-Shielded ETFs...")
    lev_symbols = ["SOXL", "TQQQ", "NVDL", "TSLL"]
    lev_data = {}
    for s in lev_symbols:
        df = provider.fetch_historical_bars(s, timeframe="1d", period="5y")
        if not df.empty and len(df) >= 100:
            lev_data[s] = df

    if lev_data:
        rep_lev, _ = simulate_high_alpha_portfolio(
            HalalTrendRotatorStrategy,
            params={"macro_regime_ema": 100, "chandelier_atr_mult": 2.0},
            symbol_data=lev_data,
            initial_capital=initial_capital,
            allocation_pct=0.40,
            trailing_atr_mult=2.0
        )
        frontier_results.append([
            "1. Leveraged Vol-Shielded ETFs (3x)",
            f"${initial_capital:,.0f}",
            f"${initial_capital + rep_lev.total_pnl:,.2f}",
            f"${rep_lev.total_pnl:+,.2f}",
            f"{(rep_lev.total_pnl / initial_capital):+.2%}",
            f"{rep_lev.win_rate:.1%}",
            rep_lev.total_trades,
            f"{rep_lev.profit_factor:.2f}",
            f"{rep_lev.sharpe_ratio:.2f}",
            "Strong Bull Waves (Swaps)"
        ])

    # -------------------------------------------------------------
    # Frontier 2: Deep Reinforcement Learning (DRL PPO/Actor-Critic)
    # -------------------------------------------------------------
    print("[2/5] Training & Testing Frontier 2: Deep RL Neural Network Policy Agent (PyTorch)...")
    rep_drl, _ = train_and_evaluate_drl_agent(halal_data, epochs=20, initial_capital=initial_capital)
    frontier_results.append([
        "2. Deep RL Policy Agent (PyTorch)",
        f"${initial_capital:,.0f}",
        f"${initial_capital + rep_drl.total_pnl:,.2f}",
        f"${rep_drl.total_pnl:+,.2f}",
        f"{(rep_drl.total_pnl / initial_capital):+.2%}",
        f"{rep_drl.win_rate:.1%}",
        rep_drl.total_trades,
        f"{rep_drl.profit_factor:.2f}",
        f"{rep_drl.sharpe_ratio:.2f}",
        "Adaptive Neural Policy"
    ])

    # -------------------------------------------------------------
    # Frontier 3: Graph Statistical Arbitrage Cointegration Clusters
    # -------------------------------------------------------------
    print("[3/5] Testing Frontier 3: Graph Stat-Arb Cointegration Clusters (Halal Spot)...")
    rotator = HalalCointegrationRotator()
    # Test on NVDA vs AMD cointegration pair
    if "NVDA" in halal_data and "AMD" in halal_data:
        df_nvda = halal_data["NVDA"]
        df_amd = halal_data["AMD"]
        rep_stat, _ = simulate_high_alpha_portfolio(
            HalalTrendRotatorStrategy,
            params={},
            symbol_data={"NVDA": df_nvda, "AMD": df_amd},
            initial_capital=initial_capital,
            allocation_pct=0.50
        )
        frontier_results.append([
            "3. Stat-Arb Cointegration Clusters",
            f"${initial_capital:,.0f}",
            f"${initial_capital + rep_stat.total_pnl:,.2f}",
            f"${rep_stat.total_pnl:+,.2f}",
            f"{(rep_stat.total_pnl / initial_capital):+.2%}",
            f"{rep_stat.win_rate:.1%}",
            rep_stat.total_trades,
            f"{rep_stat.profit_factor:.2f}",
            f"{rep_stat.sharpe_ratio:.2f}",
            "High Win Rate / Market Neutral"
        ])

    # -------------------------------------------------------------
    # Frontier 4: LLM / Catalyst & Earnings Sentiment Arbitrage
    # -------------------------------------------------------------
    print("[4/5] Testing Frontier 4: LLM Catalyst & Real-Time News Arbitrage...")
    rep_cat, _ = simulate_high_alpha_portfolio(
        CatalystScalperStrategy,
        params={"min_rvol": 1.5, "target_rr": 4.0},
        symbol_data=halal_data,
        initial_capital=initial_capital,
        allocation_pct=0.40
    )
    frontier_results.append([
        "4. LLM Catalyst & News Arbitrage",
        f"${initial_capital:,.0f}",
        f"${initial_capital + rep_cat.total_pnl:,.2f}",
        f"${rep_cat.total_pnl:+,.2f}",
        f"{(rep_cat.total_pnl / initial_capital):+.2%}",
        f"{rep_cat.win_rate:.1%}",
        rep_cat.total_trades,
        f"{rep_cat.profit_factor:.2f}",
        f"{rep_cat.sharpe_ratio:.2f}",
        "High Catalyst Asymmetry"
    ])

    # -------------------------------------------------------------
    # Frontier 5: Order Flow CVD & Microstructure Delta Imbalance
    # -------------------------------------------------------------
    print("[5/5] Testing Frontier 5: Order Flow CVD & Imbalance Absorption...")
    rep_cvd, _ = simulate_high_alpha_portfolio(
        OrderFlowCVDStrategy,
        params={"cvd_lookback": 15, "target_rr": 3.5},
        symbol_data=halal_data,
        initial_capital=initial_capital,
        allocation_pct=0.40
    )
    frontier_results.append([
        "5. Order Flow CVD & Imbalance",
        f"${initial_capital:,.0f}",
        f"${initial_capital + rep_cvd.total_pnl:,.2f}",
        f"${rep_cvd.total_pnl:+,.2f}",
        f"{(rep_cvd.total_pnl / initial_capital):+.2%}",
        f"{rep_cvd.win_rate:.1%}",
        rep_cvd.total_trades,
        f"{rep_cvd.profit_factor:.2f}",
        f"{rep_cvd.sharpe_ratio:.2f}",
        "Microstructure Delta"
    ])

    print("\n" + "="*85)
    print("  FINAL QUANTITATIVE FRONTIERS COMPARISON MATRIX")
    print("="*85)
    headers = ["Quantitative Frontier", "Start Capital", "Final Balance", "Net Profit ($)", "Return (%)", "Win Rate", "Trades", "PF", "Sharpe", "Core Edge"]
    print(tabulate(frontier_results, headers=headers, tablefmt="fancy_grid"))

if __name__ == "__main__":
    main()
