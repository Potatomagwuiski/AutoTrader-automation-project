"""
Tests for Risk Management, Circuit Breakers, Position Sizing, and Trailing Stops.
"""

from datetime import datetime, date
from autotrader.risk.position_sizer import PositionSizer
from autotrader.risk.stop_loss import TrailingStopEngine
from autotrader.risk.risk_manager import RiskManager
from autotrader.strategies.base import Signal

def test_position_sizer():
    sizer = PositionSizer(max_risk_pct=0.01)  # 1% risk
    equity = 100_000.0
    entry = 100.0
    stop = 95.0  # $5 risk per share
    
    # 1% of 100k = $1,000 risk -> 1,000 / 5 = 200 shares
    shares = sizer.calculate_shares(equity, entry, stop)
    assert shares == 200

def test_trailing_stop():
    engine = TrailingStopEngine(activation_r=1.0, atr_step_multiplier=1.0)
    state = engine.initialize_state("TEST", entry_price=100.0, initial_stop=95.0)
    assert state.risk_distance == 5.0

    # Price moves to 104 (0.8R) -> Stop should stay at 95
    state, moved = engine.update_stop(state, current_price=104.0, current_atr=2.0)
    assert state.current_stop == 95.0

    # Price reaches 106 (+1.2R) -> Trailing stop moves to breakeven (~100.25)
    state, moved = engine.update_stop(state, current_price=106.0, current_atr=2.0)
    assert moved is True
    assert state.is_breakeven_locked is True
    assert state.current_stop > 100.0

def test_risk_manager_daily_circuit_breaker():
    rm = RiskManager()
    now = datetime(2026, 1, 15, 10, 0, 0)
    
    # Initialize equity
    rm.sync_account_state(100_000.0, now)
    assert rm.circuit_breaker_tripped is False

    # Equity drops by 2.5% ($97,500) -> Should trip circuit breaker (2.0% limit)
    rm.sync_account_state(97_400.0, now)
    assert rm.circuit_breaker_tripped is True

    # Order evaluation must be rejected
    sig = Signal(
        symbol="AAPL",
        timestamp=now,
        direction="BUY",
        strategy_name="Test",
        confidence=1.0,
        suggested_entry=100.0,
        suggested_stop_loss=95.0,
        suggested_take_profit=110.0,
        reason="Test"
    )
    result = rm.evaluate_order(sig, 97_400.0, open_positions_count=0, current_time=now)
    assert result.approved is False
    assert "Trading Halted" in result.reason
