"""
Risk parameters, circuit breakers, and position-sizing guardrails.
"""

from pydantic import BaseModel

class RiskParameters(BaseModel):
    # Maximum risk per single trade as fraction of total account equity (e.g. 0.01 = 1%)
    MAX_RISK_PER_TRADE_PCT: float = 0.01
    
    # Maximum open portfolio risk (all positions combined)
    MAX_TOTAL_PORTFOLIO_RISK_PCT: float = 0.05
    
    # Maximum concurrent open positions (Fixed 2 Concentrated Positions Mode)
    MAX_OPEN_POSITIONS: int = 2
    
    # Hard Daily Drawdown Circuit Breaker: Trading halts immediately if daily loss exceeds this %
    MAX_DAILY_DRAWDOWN_PCT: float = 0.02
    
    # Maximum Total Historical Drawdown Limit: Engine enters safe liquidation if reached
    MAX_SYSTEM_DRAWDOWN_PCT: float = 0.08
    
    # Consecutive loss cooldown: After N consecutive losses, pause trading for cooldown minutes
    CONSECUTIVE_LOSS_LIMIT: int = 3
    COOLDOWN_MINUTES: int = 30
    
    # Stop-loss defaults
    ATR_STOP_MULTIPLIER: float = 1.5
    PROFIT_TARGET_RR_RATIO: float = 2.0  # Default 1:2 Risk to Reward
    TRAILING_STOP_ACTIVATION_RR: float = 1.0  # Activate trailing stop once +1R is reached
    TRAILING_STOP_ATR_STEP: float = 1.0

    # Slippage and execution friction estimates for realistic backtesting/paper
    ESTIMATED_SLIPPAGE_BPS: float = 2.0  # 2 basis points
    ESTIMATED_COMMISSION_PER_SHARE: float = 0.005  # $0.005 / share

risk_params = RiskParameters()
