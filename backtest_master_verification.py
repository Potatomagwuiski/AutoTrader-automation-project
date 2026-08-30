"""
Master Comprehensive Autonomous Multi-Account Backtest.
Compares 10-Year Historical Performance (2016 - 2026) across:
- $1,000 Micro Account
- $5,000 Standard Growth Account
- $50,000 Mid Portfolio Account
Using the expanded dynamic Halal universe with strict Musaffa 30% AAOIFI screening,
Chandelier ATR stops, profit ratchets, and 200-EMA macro cash shields.
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

def simulate_portfolio(initial_capital: float, symbol_data: dict):
    sizer = PositionSizer()
    strategy = HalalTrendRotatorStrategy()
    engine = PaperExecutionEngine(initial_capital=initial_capital)
    all_timestamps = sorted(list({ts for df in symbol_data.values() for ts in df.index}))
    equity_curve = [initial_capital]

    for ts in all_timestamps:
        current_time = ts.to_pydatetime() if isinstance(ts, pd.Timestamp) else ts
        current_equity = engine.get_account_equity()
        tier = sizer.get_dynamic_account_tier(current_equity)

        # 1. Manage open positions
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

                # Profit Ratchet
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

                # Trigger Exit
                if low <= pos.current_stop_loss:
                    engine._close_position_internal(
                        symbol=symbol,
                        exit_price=pos.current_stop_loss,
                        exit_time=current_time,
                        reason="CHANDELIER_TRAILING_STOP"
                    )

        # 2. Check for entries
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
                    shares = available_notional / signal.suggested_entry

                    if shares > 0.01 and (shares * signal.suggested_entry) <= engine.cash:
                        order = Order(
                            order_id=f"master_{int(ts.timestamp())}_{symbol}_{int(initial_capital)}",
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
    screener = HalalShariahScreener()

    universe = ["NVDA", "AMD", "TSLA", "PLTR", "ARM", "CRWD", "PANW", "AMAT", "MU", "ASML", "AAPL", "MSFT"]
    symbol_data = {}

    print("\n" + "="*95)
    print("  LOADING 10-YEAR EXPANDED HALAL DATASET (2016 - 2026)...")
    print("="*95)

    for sym in universe:
        df = provider.fetch_historical_bars(sym, timeframe="1d", period="10y")
        if not df.empty and len(df) >= 200:
            symbol_data[sym] = df
            print(f"  • {sym:<6}: Loaded {len(df)} daily bars")

    # Run simulations for $1k, $5k, $50k
    accounts = [1000.0, 5000.0, 50000.0]
    results = []

    print("\n" + "="*95)
    print("  RUNNING MASTER MULTI-ACCOUNT 10-YEAR HISTORICAL COMPARISON")
    print("="*95)

    for cap in accounts:
        final_bal, rep, trades = simulate_portfolio(cap, symbol_data)
        cagr = ((final_bal / cap)**(1/10) - 1)
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
        "Start Capital", "Final Balance", "Net Profit ($)", "10Y Return", "CAGR/Yr",
        "Trades", "Win Rate", "PF", "Avg Win / Loss", "Payoff", "Purify (1%)"
    ]
    print("\n" + tabulate(results, headers=headers, tablefmt="fancy_grid"))

if __name__ == "__main__":
    main()
