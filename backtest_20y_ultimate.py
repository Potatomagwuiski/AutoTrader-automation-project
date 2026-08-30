"""
20-Year Ultimate Historical Multi-Decade Backtest (2006 - 2026).
Tests our Autonomous Halal Alpha Compounding Strategy through:
- 2008 Great Financial Crisis (-57% S&P 500 crash)
- 2011 Eurozone Debt Crisis
- 2018 Trade War & Fed Tightening Crash
- 2020 COVID-19 Flash Crash
- 2022 Inflation & Tech Bear Market
- 2023-2026 Generative AI Semiconductor Hyper-Cycle

Rules:
- Fixed 2-Position Compounding (48.5% allocation per trade, 3% Alpaca buffer)
- 200-EMA Macro Cash Shield (100% Cash in Bear Regimes)
- Dynamic Chandelier ATR Trailing Stops (2.4x ATR) + Multi-Tier Profit Ratchets
- AAOIFI Shariah-compliant universe (NVDA, AMD, AAPL, MSFT, AMAT, MU, ASML, QCOM, TSLA, PLTR, CRWD, ARM)
"""

from datetime import datetime
import pandas as pd
from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.screening.halal_screener import HalalShariahScreener
from autotrader.strategies.halal_trend_rotator import HalalTrendRotatorStrategy
from autotrader.execution.paper_engine import PaperExecutionEngine
from autotrader.execution.order_types import Order
from autotrader.features.indicators import calculate_atr
from autotrader.telemetry.metrics import calculate_performance

def simulate_20y_portfolio(initial_capital: float, symbol_data: dict, allocation_pct: float = 0.485, max_positions: int = 2):
    strategy = HalalTrendRotatorStrategy()
    engine = PaperExecutionEngine(initial_capital=initial_capital)
    all_timestamps = sorted(list({ts for df in symbol_data.values() for ts in df.index}))
    equity_curve = [initial_capital]

    for ts in all_timestamps:
        current_time = ts.to_pydatetime() if isinstance(ts, pd.Timestamp) else ts
        current_equity = engine.get_account_equity()

        # 1. Manage open positions with Chandelier ATR stops and profit ratchets
        for symbol in list(engine.positions.keys()):
            df = symbol_data.get(symbol)
            if df is not None and ts in df.index:
                idx = df.index.get_loc(ts)
                loc = idx if isinstance(idx, int) else int(idx.start)
                sub_df = df.iloc[:loc+1]
                current_atr = float(calculate_atr(sub_df, period=14).iloc[-1]) if len(sub_df) >= 14 else 1.0

                pos = engine.positions[symbol]
                row = df.loc[ts]
                bar_dict = row.iloc[-1].to_dict() if isinstance(row, pd.DataFrame) else row.to_dict()
                low = float(bar_dict["low"])
                close = float(bar_dict["close"])

                pos.update_market_price(close)
                gain_pct = (pos.highest_price - pos.entry_price) / pos.entry_price

                # Profit Ratchet Level 1 (+30% gain -> lock +20%)
                if gain_pct >= 0.30:
                    lock_price = pos.entry_price * 1.20
                    if lock_price > pos.current_stop_loss:
                        pos.current_stop_loss = lock_price

                # Profit Ratchet Level 2 (+60% gain -> lock +45%)
                if gain_pct >= 0.60:
                    lock_price = pos.entry_price * 1.45
                    if lock_price > pos.current_stop_loss:
                        pos.current_stop_loss = lock_price

                # Chandelier Trailing Stop (2.4x ATR below highest price)
                chandelier_stop = pos.highest_price - (2.4 * current_atr)
                if chandelier_stop > pos.current_stop_loss:
                    pos.current_stop_loss = chandelier_stop

                # Trigger Exit if price hits stop
                if low <= pos.current_stop_loss:
                    engine._close_position_internal(
                        symbol=symbol,
                        exit_price=pos.current_stop_loss,
                        exit_time=current_time,
                        reason="CHANDELIER_TRAILING_STOP"
                    )

        # 2. Check for new entries
        if len(engine.positions) < max_positions:
            for symbol, df in symbol_data.items():
                if len(engine.positions) >= max_positions:
                    break
                if symbol in engine.positions or ts not in df.index:
                    continue

                idx = df.index.get_loc(ts)
                loc = idx if isinstance(idx, int) else int(idx.start)
                if loc < 205:
                    continue

                sub_df = df.iloc[:loc+1]
                signal = strategy.generate_signal(symbol, sub_df)
                if signal and signal.direction == "BUY":
                    available_notional = current_equity * allocation_pct
                    shares = available_notional / signal.suggested_entry

                    if shares > 0.01 and (shares * signal.suggested_entry) <= engine.cash:
                        order = Order(
                            order_id=f"20y_{int(ts.timestamp())}_{symbol}_{int(initial_capital)}",
                            symbol=symbol,
                            direction="BUY",
                            order_type="MARKET",
                            shares=shares,
                            price=signal.suggested_entry,
                            stop_price=signal.suggested_stop_loss,
                            created_at=current_time,
                            strategy_name=strategy.name,
                            metadata={"take_profit": signal.suggested_take_profit}
                        )
                        engine.submit_order(order)

        equity_curve.append(engine.get_account_equity())

    for symbol in list(engine.positions.keys()):
        engine.close_position(symbol, reason="END_OF_SIMULATION")

    pnls = [t.realized_pnl for t in engine.closed_trades]
    report = calculate_performance(trade_pnls=pnls, equity_curve=equity_curve)
    final_balance = initial_capital + report.total_pnl

    return final_balance, report, engine.closed_trades

def main():
    provider = YFinanceProvider()
    universe = [
        "NVDA", "AMD", "AAPL", "MSFT", "AMAT", "MU", "ASML", "QCOM",
        "TSLA", "PLTR", "CRWD", "ARM"
    ]
    symbol_data = {}

    print("\n" + "="*95)
    print("  FETCHING 20-YEAR HISTORICAL DATASET (2006 - 2026)...")
    print("="*95)

    for sym in universe:
        df = provider.fetch_historical_bars(sym, timeframe="1d", period="max")
        if not df.empty:
            df = df[df.index >= "2006-01-01"]
            if len(df) >= 100:
                symbol_data[sym] = df
                start_date = df.index[0].strftime('%Y-%m-%d')
                end_date = df.index[-1].strftime('%Y-%m-%d')
                print(f"  • {sym:<6}: {len(df):>4} bars ({start_date} to {end_date})")

    # 1. Multi-Account Comparison ($1k, $5k, $50k)
    accounts = [1000.0, 5000.0, 50000.0]
    results = []

    print("\n" + "="*95)
    print("  1. 20-YEAR MULTI-ACCOUNT COMPOUNDING COMPARISON (2006 - 2026)")
    print("="*95)

    all_trades_5k = []
    for cap in accounts:
        final_bal, rep, trades = simulate_20y_portfolio(cap, symbol_data)
        if cap == 5000.0:
            all_trades_5k = trades

        cagr = ((final_bal / cap)**(1/20) - 1) if final_bal > 0 else 0.0
        total_ret = (rep.total_pnl / cap)
        purify_est = max(0.0, rep.total_pnl * 0.01)

        results.append([
            f"${cap:,.2f}",
            f"${final_bal:,.2f}",
            f"${rep.total_pnl:+,.2f}",
            f"{total_ret:+.2%}",
            f"{cagr:+.2%}",
            rep.total_trades,
            f"{rep.win_rate:.1%}",
            f"{rep.profit_factor:.2f}",
            f"${rep.avg_win:,.2f} / ${rep.avg_loss:,.2f}",
            f"{rep.payoff_ratio:.2f}",
            f"${purify_est:,.2f}"
        ])

    headers = [
        "Start Capital", "Final Balance", "Net Profit ($)", "20Y Return", "CAGR/Yr",
        "Trades", "Win Rate", "PF", "Avg Win / Loss", "Payoff", "Purify (1%)"
    ]
    print("\n" + tabulate(results, headers=headers, tablefmt="fancy_grid"))

    # 2. Year-by-Year Historical Breakdown for $5k Account
    print("\n" + "="*95)
    print("  2. YEAR-BY-YEAR DETAILED MARKET CYCLE BREAKDOWN ($5,000 ACCOUNT)")
    print("="*95)

    trades_by_year = {}
    for t in all_trades_5k:
        yr = t.entry_time.year
        if yr not in trades_by_year:
            trades_by_year[yr] = []
        trades_by_year[yr].append(t)

    yearly_rows = []
    running_balance = 5000.0

    era_descriptions = {
        2006: "Pre-Crisis Expansion",
        2007: "Subprime Early Warnings",
        2008: "🔥 Great Financial Crisis (-57% S&P Crash)",
        2009: "Post-Crisis Generational Bottom & Rebound",
        2010: "Flash Crash & Recovery",
        2011: "Eurozone Debt Crisis & US Downgrade",
        2012: "Central Bank QE Era",
        2013: "Taper Tantrum & Tech Rally",
        2014: "Bull Market Continuation",
        2015: "China Devaluation / Commodity Slump",
        2016: "Tech Recovery Wave",
        2017: "Broad Market Melt-Up",
        2018: "🔥 Fed Rate Hikes & Q4 Crash",
        2019: "Pivot Recovery",
        2020: "🔥 COVID Flash Crash & Hyper-Stimulus",
        2021: "Speculative Tech Peak",
        2022: "🔥 Fed Tightening & Tech Bear (-33% NASDAQ)",
        2023: "Generative AI Boom Ignition",
        2024: "Semiconductor Hyper-Expansion",
        2025: "Parabolic AI Growth",
        2026: "Mature Momentum Continuation"
    }

    for yr in sorted(trades_by_year.keys()):
        yr_trades = trades_by_year[yr]
        yr_pnls = [t.realized_pnl for t in yr_trades]
        yr_net_pnl = sum(yr_pnls)
        yr_wins = [p for p in yr_pnls if p > 0]
        yr_losses = [p for p in yr_pnls if p < 0]
        yr_win_rate = len(yr_wins) / len(yr_trades) if yr_trades else 0.0
        yr_gross_profit = sum(yr_wins)
        yr_gross_loss = abs(sum(yr_losses))
        yr_pf = (yr_gross_profit / yr_gross_loss) if yr_gross_loss > 0 else 999.0
        yr_return = (yr_net_pnl / running_balance) if running_balance > 0 else 0.0
        start_bal = running_balance
        running_balance += yr_net_pnl

        era = era_descriptions.get(yr, "Market Cycle")
        yearly_rows.append([
            yr,
            era,
            f"${start_bal:,.2f}",
            f"${running_balance:,.2f}",
            f"${yr_net_pnl:+,.2f}",
            f"{yr_return:+.1%}",
            len(yr_trades),
            f"{yr_win_rate:.1%}",
            f"{yr_pf:.2f}" if yr_pf < 999 else "INF"
        ])

    y_headers = ["Year", "Market Era", "Start Bal", "End Bal", "Net PnL", "Return (%)", "Trades", "Win Rate", "PF"]
    print("\n" + tabulate(yearly_rows, headers=y_headers, tablefmt="fancy_grid"))

    # 3. Top 15 Multi-Baggers Across 20 Years
    print("\n" + "="*95)
    print("  3. TOP 15 GREATEST COMPOUNDING TRADES ACROSS 20 YEARS (2006 - 2026)")
    print("="*95)

    sorted_trades = sorted(all_trades_5k, key=lambda t: t.realized_pnl, reverse=True)[:15]
    top_rows = []
    for t in sorted_trades:
        gain_pct = (t.exit_price - t.entry_price) / t.entry_price
        purify = max(0.0, t.realized_pnl * 0.01)
        top_rows.append([
            t.symbol,
            t.entry_time.strftime("%Y-%m-%d"),
            t.exit_time.strftime("%Y-%m-%d"),
            f"${t.entry_price:,.2f}",
            f"${t.exit_price:,.2f}",
            f"${t.realized_pnl:+,.2f}",
            f"{gain_pct:+.1%}",
            f"${purify:,.2f}"
        ])

    top_headers = ["Symbol", "Entry Date", "Exit Date", "Entry $", "Exit $", "Net Profit ($)", "Trade Gain (%)", "Purify (1%)"]
    print("\n" + tabulate(top_rows, headers=top_headers, tablefmt="fancy_grid"))

if __name__ == "__main__":
    main()
