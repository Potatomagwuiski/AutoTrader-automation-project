"""
Quantitative performance metrics calculation engine.
Calculates Sharpe, Sortino, Calmar, Profit Factor, Expectancy, Win Rate, and Drawdown.
"""

from typing import Any
import numpy as np
import pandas as pd
from pydantic import BaseModel, Field

class PerformanceReport(BaseModel):
    total_trades: int = 0
    winning_trades: int = 0
    losing_trades: int = 0
    win_rate: float = 0.0
    
    total_pnl: float = 0.0
    total_return_pct: float = 0.0
    gross_profit: float = 0.0
    gross_loss: float = 0.0
    profit_factor: float = 0.0
    
    avg_trade_pnl: float = 0.0
    avg_win: float = 0.0
    avg_loss: float = 0.0
    payoff_ratio: float = 0.0
    expectancy: float = 0.0
    
    max_drawdown_amount: float = 0.0
    max_drawdown_pct: float = 0.0
    
    sharpe_ratio: float = 0.0
    sortino_ratio: float = 0.0
    calmar_ratio: float = 0.0
    
    avg_trade_duration_bars: float = 0.0
    custom_metrics: dict[str, Any] = Field(default_factory=dict)

def calculate_drawdown(equity_series: pd.Series) -> tuple[pd.Series, float, float]:
    """Calculates drawdown series, max drawdown $, and max drawdown %."""
    if equity_series.empty:
        return pd.Series(dtype=float), 0.0, 0.0
        
    peak = equity_series.cummax()
    drawdown_abs = peak - equity_series
    drawdown_pct = (drawdown_abs / peak).replace([np.inf, -np.inf], 0.0).fillna(0.0)
    
    max_dd_abs = float(drawdown_abs.max()) if not drawdown_abs.empty else 0.0
    max_dd_pct = float(drawdown_pct.max()) if not drawdown_pct.empty else 0.0
    return drawdown_pct, max_dd_abs, max_dd_pct

def calculate_performance(
    trade_pnls: list[float],
    equity_curve: list[float] | None = None,
    risk_free_rate: float = 0.02,
    periods_per_year: int = 252 * 78  # e.g., 5-min bars in trading year
) -> PerformanceReport:
    """Computes comprehensive performance statistics for an array of trade PnLs."""
    report = PerformanceReport()
    if not trade_pnls:
        return report
        
    pnls = np.array(trade_pnls, dtype=float)
    report.total_trades = len(pnls)
    
    wins = pnls[pnls > 0]
    losses = pnls[pnls < 0]
    
    report.winning_trades = int(len(wins))
    report.losing_trades = int(len(losses))
    report.win_rate = (report.winning_trades / report.total_trades) if report.total_trades > 0 else 0.0
    
    report.gross_profit = float(np.sum(wins)) if len(wins) > 0 else 0.0
    report.gross_loss = float(np.abs(np.sum(losses))) if len(losses) > 0 else 0.0
    report.total_pnl = float(np.sum(pnls))
    
    if report.gross_loss > 0:
        report.profit_factor = report.gross_profit / report.gross_loss
    else:
        report.profit_factor = 999.0 if report.gross_profit > 0 else 0.0
        
    report.avg_trade_pnl = float(np.mean(pnls)) if len(pnls) > 0 else 0.0
    report.avg_win = float(np.mean(wins)) if len(wins) > 0 else 0.0
    report.avg_loss = float(np.mean(np.abs(losses))) if len(losses) > 0 else 0.0
    report.payoff_ratio = (report.avg_win / report.avg_loss) if report.avg_loss > 0 else 0.0
    
    # Expectancy = (WinRate * AvgWin) - (LossRate * AvgLoss)
    loss_rate = 1.0 - report.win_rate
    report.expectancy = (report.win_rate * report.avg_win) - (loss_rate * report.avg_loss)
    
    # Equity curve metrics
    if equity_curve and len(equity_curve) > 1:
        eq = pd.Series(equity_curve)
        init_equity = float(eq.iloc[0])
        final_equity = float(eq.iloc[-1])
        report.total_return_pct = (final_equity - init_equity) / init_equity if init_equity > 0 else 0.0
        
        _, max_dd_abs, max_dd_pct = calculate_drawdown(eq)
        report.max_drawdown_amount = max_dd_abs
        report.max_drawdown_pct = max_dd_pct
        
        # Periodic returns
        periodic_returns = eq.pct_change().dropna()
        if len(periodic_returns) > 1 and periodic_returns.std() > 0:
            excess_returns = periodic_returns - (risk_free_rate / periods_per_year)
            report.sharpe_ratio = float(np.sqrt(periods_per_year) * (excess_returns.mean() / periodic_returns.std()))
            
            # Downside deviation for Sortino
            downside = periodic_returns[periodic_returns < 0]
            if len(downside) > 0 and downside.std() > 0:
                report.sortino_ratio = float(np.sqrt(periods_per_year) * (excess_returns.mean() / downside.std()))
                
        if report.max_drawdown_pct > 0:
            report.calmar_ratio = report.total_return_pct / report.max_drawdown_pct
            
    return report
