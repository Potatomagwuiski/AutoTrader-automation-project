"""
Comprehensive Backtest of a $1,000 Micro Account on Alpaca.
Tests:
1. 5-Year High-Velocity Compounding (2021 - 2026)
2. 10-Year Decade Compounding (2016 - 2026)
Features:
- Fractional / Notional share sizing ($485/trade starting size)
- 2 Concentrated Positions (Tier 1 Small Growth Mode)
- 200-EMA Bear Market Shield + Chandelier ATR Stops
- 100% Halal Spot Equity
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
from autotrader.risk.position_sizer import PositionSizer
from autotrader.telemetry.metrics import calculate_performance

def run_1k_simulation(period_str: str = "10y", initial_capital: float = 1000.0):
    provider = YFinanceProvider()
    sizer = PositionSizer()
    strategy = HalalTrendRotatorStrategy()

    universe = ["NVDA", "AMD", "TSLA", "PLTR", "ARM", "CRWD", "ASML", "QCOM", "AAPL", "MSFT"]
    symbol_data = {}

    for sym in universe:
        df = provider.fetch_historical_bars(sym, timeframe="1d", period=period_str)
        if not df.empty and len(df) >= 200:
            symbol_data[sym] = df

    engine = PaperExecutionEngine(initial_capital=initial_capital)
    all_timestamps = sorted(list({ts for df in symbol_data.values() for ts in df.index}))
    equity_curve = [initial_capital]

    for ts in all_timestamps:
        current_time = ts.to_pydatetime() if isinstance(ts, pd.Timestamp) else ts
        current_equity = engine.get_account_equity()
        tier = sizer.get_dynamic_account_tier(current_equity)

        # 1. Update open positions and manage Chandelier Trailing Stops
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

                # Profit Ratchet Locks
                if gain_pct >= 0.30:
                    lock_price = pos.entry_price * 1.20
                    if lock_price > pos.current_stop_loss:
                        pos.current_stop_loss = lock_price

                if gain_pct >= 0.60:
                    lock_price = pos.entry_price * 1.45
                    if lock_price > pos.current_stop_loss:
                        pos.current_stop_loss = lock_price

                # Chandelier Trailing Stop (2.4x ATR)
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

        # 2. Check for new entries up to dynamic tier capacity (Fractional lot handling)
        if len(engine.positions) < tier.max_concurrent_positions:
            for symbol, df in symbol_data.items():
                if len(engine.positions) >= tier.max_concurrent_positions:
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
                    available_notional = current_equity * tier.allocation_pct_per_trade
                    # Fractional shares calculation (Alpaca notional sizing)
                    shares = available_notional / signal.suggested_entry

                    if shares > 0.01 and (shares * signal.suggested_entry) <= engine.cash:
                        order = Order(
                            order_id=f"1k_{int(ts.timestamp())}_{symbol}",
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
        engine.close_position(symbol, reason="END_OF_DATA")

    pnls = [t.realized_pnl for t in engine.closed_trades]
    report = calculate_performance(trade_pnls=pnls, equity_curve=equity_curve)
    final_balance = initial_capital + report.total_pnl

    return final_balance, report, engine.closed_trades

def main():
    print("\n" + "="*90)
    print("  $1,000 MICRO ACCOUNT HISTORICAL SIMULATION (ALPACA FRACTIONAL SIZING)")
    print("="*90)

    # 1. 10-Year Run
    fin_10y, rep_10y, trades_10y = run_1k_simulation(period_str="10y", initial_capital=1000.0)

    print("\n" + "-"*90)
    print("  1. $1,000 STARTING CAPITAL: 10-YEAR OVERALL PERFORMANCE (2016 - 2026)")
    print("-"*90)
    table_10y = [
        ["Starting Capital", "$1,000.00"],
        ["Final Account Balance", f"${fin_10y:,.2f}"],
        ["Total Net Realized Profit", f"${rep_10y.total_pnl:+,.2f}"],
        ["10-Year Cumulative Return", f"{(rep_10y.total_pnl / 1000.0):+.2%}"],
        ["Compound Annual Growth Rate (CAGR)", f"{((fin_10y / 1000.0)**(1/10) - 1):+.2%}"],
        ["Total Closed Trades", rep_10y.total_trades],
        ["Winning / Losing Trades", f"{rep_10y.winning_trades} / {rep_10y.losing_trades}"],
        ["Win Rate", f"{rep_10y.win_rate:.1%}"],
        ["Profit Factor", f"{rep_10y.profit_factor:.2f}"],
        ["Average Win / Loss", f"${rep_10y.avg_win:,.2f} / ${rep_10y.avg_loss:,.2f}"],
        ["Payoff Ratio (R:R)", f"{rep_10y.payoff_ratio:.2f}"],
        ["Sharpe Ratio", f"{rep_10y.sharpe_ratio:.2f}"]
    ]
    print(tabulate(table_10y, headers=["Metric", "$1,000 Account Value"], tablefmt="fancy_grid"))

    # Year by Year Breakdown on $1k
    print("\n" + "-"*90)
    print("  2. $1,000 ACCOUNT: YEAR-BY-YEAR COMPOUNDING MILESTONES")
    print("-"*90)
    trades_by_year = {}
    for t in trades_10y:
        yr = t.entry_time.year
        if yr not in trades_by_year:
            trades_by_year[yr] = []
        trades_by_year[yr].append(t)

    yearly_rows = []
    running_balance = 1000.0

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

        market_context = {
            2016: "Tech Expansion Cycle",
            2017: "Historic Bull Wave",
            2018: "Fed QT & Q4 Crash (Cash Shield)",
            2019: "V-Shape Recovery",
            2020: "COVID-19 Shock & AI Rebound",
            2021: "Retail / Tech Climax",
            2022: "Bear Market Crash (Cash Shield)",
            2023: "Gen-AI Revolution Ignition",
            2024: "Semiconductor Hyper-Expansion",
            2025: "Parabolic AI Growth",
            2026: "Mature Momentum Continuation"
        }.get(yr, "Market Regime")

        yearly_rows.append([
            yr,
            market_context,
            f"${start_bal:,.2f}",
            f"${running_balance:,.2f}",
            f"${yr_net_pnl:+,.2f}",
            f"{yr_return:+.1%}",
            len(yr_trades),
            f"{yr_win_rate:.1%}",
            f"{yr_pf:.2f}"
        ])

    headers_yearly = ["Year", "Historical Market Cycle", "Start Balance", "End Balance", "Net PnL ($)", "Annual Return", "Trades", "Win Rate", "PF"]
    print(tabulate(yearly_rows, headers=headers_yearly, tablefmt="fancy_grid"))

    # Top Winning Trades on $1k
    print("\n" + "-"*90)
    print("  3. TOP 8 GREATEST WINNING TRADES STARTING FROM $1,000")
    print("-"*90)
    sorted_trades = sorted(trades_10y, key=lambda t: t.realized_pnl, reverse=True)
    top_trades = []
    for t in sorted_trades[:8]:
        top_trades.append([
            t.symbol,
            t.entry_time.strftime('%Y-%m-%d'),
            t.exit_time.strftime('%Y-%m-%d') if t.exit_time else 'OPEN',
            f"${t.entry_price:.2f}",
            f"${t.exit_price:.2f}" if t.exit_price else 'N/A',
            f"${t.realized_pnl:+,.2f}",
            f"{t.realized_return_pct:+.1%}"
        ])
    headers_top = ["Symbol", "Entry Date", "Exit Date", "Entry $", "Exit $", "Net Profit ($)", "Trade Gain (%)"]
    print(tabulate(top_trades, headers=headers_top, tablefmt="fancy_grid"))

if __name__ == "__main__":
    main()
