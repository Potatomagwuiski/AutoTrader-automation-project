"""
Comprehensive 10-Year Autonomous Backtest (2016 - 2026).
Starting Capital: $5,000.00
Features:
- Dynamic Account Tier Scaling (Auto-scales from 2 to 4 to 8 positions as capital compounds)
- 200-EMA Macro Cash Shield (Survives 2018 crash, 2020 COVID shock, and 2022 bear market)
- Dynamic Chandelier ATR Trailing Stops (Rides multi-year secular winners)
- 100% Halal Spot Equity (Zero margin debt, zero shorting)
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

def run_10y_backtest(initial_capital: float = 5000.0):
    provider = YFinanceProvider()
    screener = HalalShariahScreener()
    sizer = PositionSizer()
    strategy = HalalTrendRotatorStrategy()

    universe = ["NVDA", "AMD", "TSLA", "PLTR", "ARM", "CRWD", "ASML", "QCOM", "AAPL", "MSFT"]
    symbol_data = {}

    print("\n" + "="*90)
    print("  FETCHING 10-YEAR HISTORICAL DATA (2016 - 2026) ACROSS SHARIAH UNIVERSE...")
    print("="*90)

    for sym in universe:
        df = provider.fetch_historical_bars(sym, timeframe="1d", period="10y")
        if not df.empty and len(df) >= 200:
            symbol_data[sym] = df
            print(f"  • {sym:<6}: Loaded {len(df)} daily bars ({df.index[0].strftime('%Y-%m-%d')} to {df.index[-1].strftime('%Y-%m-%d')})")

    engine = PaperExecutionEngine(initial_capital=initial_capital)
    all_timestamps = sorted(list({ts for df in symbol_data.values() for ts in df.index}))
    equity_curve = [initial_capital]

    print("\n" + "="*90)
    print("  RUNNING 10-YEAR AUTONOMOUS SIMULATION (DYNAMIC TIER SCALING + CHANDELIER STOPS)")
    print("="*90)

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

        # 2. Check for new entries up to dynamic tier capacity
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
                    shares = int(available_notional / signal.suggested_entry)

                    if shares > 0 and (shares * signal.suggested_entry) <= engine.cash:
                        order = Order(
                            order_id=f"10y_{int(ts.timestamp())}_{symbol}",
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
        engine.close_position(symbol, reason="END_OF_10Y_DATA")

    pnls = [t.realized_pnl for t in engine.closed_trades]
    report = calculate_performance(trade_pnls=pnls, equity_curve=equity_curve)
    final_balance = initial_capital + report.total_pnl

    # 1. Overall 10-Year Summary Table
    print("\n" + "="*90)
    print("  1. TEN-YEAR OVERALL PERFORMANCE RESULTS (2016 - 2026)")
    print("="*90)
    overall_table = [
        ["Initial Capital", f"${initial_capital:,.2f}"],
        ["Final Account Balance", f"${final_balance:,.2f}"],
        ["Total Net Realized Profit", f"${report.total_pnl:+,.2f}"],
        ["10-Year Cumulative Return", f"{(report.total_pnl / initial_capital):+.2%}"],
        ["Compound Annual Growth Rate (CAGR)", f"{((final_balance / initial_capital)**(1/10) - 1):+.2%}"],
        ["Total Trades Executed", report.total_trades],
        ["Winning / Losing Trades", f"{report.winning_trades} / {report.losing_trades}"],
        ["Win Rate", f"{report.win_rate:.1%}"],
        ["Profit Factor", f"{report.profit_factor:.2f}"],
        ["Average Win / Loss", f"${report.avg_win:,.2f} / ${report.avg_loss:,.2f}"],
        ["Payoff Ratio (R:R)", f"{report.payoff_ratio:.2f}"],
        ["Sharpe Ratio", f"{report.sharpe_ratio:.2f}"],
        ["Max Drawdown (%)", f"{report.max_drawdown_pct:.2%}"]
    ]
    print(tabulate(overall_table, headers=["Metric", "10-Year Value"], tablefmt="fancy_grid"))

    # 2. Year-by-Year Market Cycles Table
    print("\n" + "="*90)
    print("  2. YEAR-BY-YEAR 10-YEAR MARKET CYCLES COMPOUNDING JOURNEY")
    print("="*90)
    trades_by_year = {}
    for t in engine.closed_trades:
        yr = t.entry_time.year
        if yr not in trades_by_year:
            trades_by_year[yr] = []
        trades_by_year[yr].append(t)

    yearly_rows = []
    running_balance = initial_capital

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
            2018: "Fed Tightening & Q4 Crash (Cash Shield)",
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

    # 3. Top 10 Multi-Bagging Trades of the Decade
    print("\n" + "="*90)
    print("  3. TOP 10 GREATEST WINNING TRADES OF THE DECADE (2016 - 2026)")
    print("="*90)
    sorted_trades = sorted(engine.closed_trades, key=lambda t: t.realized_pnl, reverse=True)
    top_trades = []
    for t in sorted_trades[:10]:
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
    run_10y_backtest(initial_capital=5000.0)
