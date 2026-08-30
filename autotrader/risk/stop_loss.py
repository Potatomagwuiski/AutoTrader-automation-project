"""
Dynamic Trailing Stop and Structural Exit Engine.
Protects capital by ratcheting stop losses in the trade's favor as R-multiples are captured.
"""

from pydantic import BaseModel
from autotrader.config.risk_params import risk_params

class TrailingStopState(BaseModel):
    symbol: str
    entry_price: float
    initial_stop: float
    current_stop: float
    highest_price_reached: float
    risk_distance: float  # |entry - initial_stop| = 1R
    is_breakeven_locked: bool = False

class TrailingStopEngine:
    def __init__(
        self,
        activation_r: float = risk_params.TRAILING_STOP_ACTIVATION_RR,
        atr_step_multiplier: float = risk_params.TRAILING_STOP_ATR_STEP
    ):
        self.activation_r = activation_r
        self.atr_step_multiplier = atr_step_multiplier

    def initialize_state(self, symbol: str, entry_price: float, initial_stop: float) -> TrailingStopState:
        risk_distance = max(abs(entry_price - initial_stop), 0.01)
        return TrailingStopState(
            symbol=symbol,
            entry_price=entry_price,
            initial_stop=initial_stop,
            current_stop=initial_stop,
            highest_price_reached=entry_price,
            risk_distance=risk_distance,
            is_breakeven_locked=False
        )

    def update_stop(
        self,
        state: TrailingStopState,
        current_price: float,
        current_atr: float
    ) -> tuple[TrailingStopState, bool]:
        """
        Updates trailing stop state given current price and ATR.
        Returns (updated_state, has_stop_moved: bool).
        """
        stop_moved = False
        
        # Track highest price
        if current_price > state.highest_price_reached:
            state.highest_price_reached = current_price

        gain = state.highest_price_reached - state.entry_price
        r_multiple_gain = gain / state.risk_distance

        # Step 1: Move to Breakeven once >= +1R is gained
        if r_multiple_gain >= self.activation_r and not state.is_breakeven_locked:
            breakeven_price = state.entry_price + (state.risk_distance * 0.05)  # Slightly above breakeven to cover fees
            if breakeven_price > state.current_stop:
                state.current_stop = breakeven_price
                state.is_breakeven_locked = True
                stop_moved = True

        # Step 2: Trail behind highest high by ATR step multiplier once > 1.5R
        if r_multiple_gain >= 1.5:
            trailing_level = state.highest_price_reached - (self.atr_step_multiplier * current_atr)
            if trailing_level > state.current_stop:
                state.current_stop = trailing_level
                stop_moved = True

        return state, stop_moved
