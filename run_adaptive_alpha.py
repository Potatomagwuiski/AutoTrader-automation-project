"""
Adaptive High-Alpha 5-Year Portfolio Backtest Runner.
Incorporates 200-EMA Macro Regime Gate, Dynamic Profit Ratcheting, and Asymmetric Compounding.
"""

from datetime import datetime
import pandas as pd
from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.strategies.adaptive_high_alpha import AdaptiveHighAlphaStrategy
from autotrader.execution.paper_engine import PaperExecutionEngine
from autotrader.execution.order_types import Order
from autotrader.features.indicators import calculate_atr
from autotrader.telemetry.metrics import calculate_performance

def run_adaptive_simulation(
    symbols: list[str],
    initial_capital: float = 100000.0,
    allocation_pct: float = 0.50,
    trailing_atr_mult: float = 2.2
):
    provider = YFinanceProvider()
    symbol_data = {}
    for s in symbols:
        df = provider.fetch_historical_bars(s, timeframe="1d", period="5y")
        if not df.empty and len(df) >= 210:
            symbol_data[s] = df

    strategy = AdaptiveHighAlphaStrategy()
    engine = PaperExecutionEngine(initial_capital=initial_capital)

    all_timestamps = sorted(list({ts for df in symbol_data.values() for ts in df.index}))
    equity_curve = [initial_capital]

    for ts in all_timestamps:
        current_time = ts.to_pydatetime() if isinstance(ts, pd.Timestamp) else ts

        # 1. Update open positions with Ratcheted Trailing Stops
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
                high = float(bar_dict["high"])
                low = float(bar_dict["low"])
                close = float(bar_dict["close"])

                pos.update_market_price(close)
                gain_pct = (pos.highest_price - pos.entry_price) / pos.entry_price

                # Profit Ratchet Locks:
                # If gained +25%, stop is locked at +15% profit minimum
                if gain_pct >= 0.25:
                    lock_price = pos.entry_price * 1.15
                    if lock_price > pos.current_stop_loss:
                        pos.current_stop_loss = lock_price

                # If gained +50%, stop is locked at +35% profit minimum
                if gain_pct >= 0.50:
                    lock_price = pos.entry_price * 1.35
                    if lock_price > pos.current_stop_loss:
                        pos.current_stop_loss = lock_price

                # If gained +100%, stop is locked at +75% profit minimum
                if gain_pct >= 1.00:
                    lock_price = pos.entry_price * 1.75
                    if lock_price > pos.current_stop_loss:
                        pos.current_stop_loss = lock_price

                # Chandelier Trailing Stop
                chandelier_stop = pos.highest_price - (trailing_atr_mult * current_atr)
                if chandelier_stop > pos.current_stop_loss:
                    pos.current_stop_loss = chandelier_stop

                # Trigger Exit
                if low <= pos.current_stop_loss:
                    engine._close_position_internal(
                        symbol=symbol,
                        exit_price=pos.current_stop_loss,
                        exit_time=current_time,
                        reason="RATCHETED_TRAILING_STOP"
                    )

        # 2. Check for new high-conviction entries
        max_positions = int(1.0 / allocation_pct)
        if len(engine.positions) < max_positions:
            for symbol, df in symbol_data.items():
                if symbol in engine.positions or ts not in df.index:
                    continue

                idx = df.index.get_loc(ts)
                loc = idx if isinstance(idx, int) else int(idx.start)
                if loc < 205:
                    continue

                sub_df = df.iloc[:loc+1]
                signal = strategy.generate_signal(symbol, sub_df)
                if signal and signal.direction == "BUY":
                    available_equity = engine.get_account_equity() * allocation_pct
                    shares = int(available_equity / signal.suggested_entry)

                    if shares > 0 and (shares * signal.suggested_entry) <= engine.cash:
                        order = Order(
                            order_id=f"adapt_{ts}_{symbol}",
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

    print("\n" + "="*70)
    print("  ADAPTIVE HIGH-ALPHA REGIME & PROFIT-SHIELDED 5-YEAR RESULTS")
    print("="*70)
    results = [
        ["Initial Capital", f"${initial_capital:,.2f}"],
        ["Final Capital", f"${initial_capital + report.total_pnl:,.2f}"],
        ["Total Net Profit", f"${report.total_pnl:+,.2f}"],
        ["Total Net Return", f"{(report.total_pnl / initial_capital):+.2%}"],
        ["Total Trades", report.total_trades],
        ["Winning / Losing Trades", f"{report.winning_trades} / {report.losing_trades}"],
        ["Win Rate", f"{report.win_rate:.1%}"],
        ["Profit Factor", f"{report.profit_factor:.2f}"],
        ["Average Winning Trade", f"${report.avg_win:,.2f}"],
        ["Average Losing Trade", f"${report.avg_loss:,.2f}"],
        ["Payoff Ratio (R:R)", f"{report.payoff_ratio:.2f}"],
        ["Sharpe Ratio", f"{report.sharpe_ratio:.2f}"],
        ["Max Drawdown (%)", f"{report.max_drawdown_pct:.2%}"]
    ]
    print(tabulate(results, headers=["Metric", "Value"], tablefmt="fancy_grid"))

    print("\n--- Top Winning Multi-Bagging Trades ---")
    sorted_trades = sorted(engine.closed_trades, key=lambda t: t.realized_pnl, reverse=True)
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
    print(tabulate(top_trades, headers=["Symbol", "Entry", "Exit", "Entry $", "Exit $", "PnL", "Gain %"], tablefmt="fancy_grid"))

if __name__ == "__main__":
    symbols = ['NVDA', 'TSLA', 'AMD', 'AAPL', 'MSFT', 'AMZN', 'META']
    run_adaptive_simulation(symbols, initial_capital=100000.0, allocation_pct=0.50)
