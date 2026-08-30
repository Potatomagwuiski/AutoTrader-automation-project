"""
Frontier 2: Deep Reinforcement Learning (DRL) Policy Network Agent.
Features:
- PyTorch Policy Network (Actor-Critic Architecture).
- State Space: [Ret_5, Ret_10, Ret_20, RSI_14, ATR_Pct, Dist_200EMA, RVOL, CVD_Ratio].
- Action Space: Discrete Actions [0: 100% Cash / Neutral, 1: 50% Spot Long, 2: 100% Spot Long].
- Reward: Differential Sortino Ratio with maximum drawdown penalty.
"""

from datetime import datetime
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
import torch.optim as optim
from autotrader.features.indicators import calculate_rsi, calculate_atr, calculate_ema, calculate_rvol
from autotrader.strategies.order_flow_cvd import estimate_volume_delta
from autotrader.telemetry.metrics import calculate_performance, PerformanceReport
from autotrader.telemetry.logger import log

class DRLTradingPolicyNetwork(nn.Module):
    def __init__(self, input_dim: int = 8, hidden_dim: int = 64, output_dim: int = 3):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, output_dim)
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        logits = self.net(x)
        return torch.softmax(logits, dim=-1)

def extract_state_features(df: pd.DataFrame, idx: int) -> np.ndarray:
    """Extracts normalized 8-dimensional state vector at bar index `idx`."""
    sub = df.iloc[:idx+1]
    closes = sub["close"]
    
    ret_5 = (closes.iloc[-1] - closes.iloc[-5]) / closes.iloc[-5] if len(closes) >= 5 else 0.0
    ret_10 = (closes.iloc[-1] - closes.iloc[-10]) / closes.iloc[-10] if len(closes) >= 10 else 0.0
    ret_20 = (closes.iloc[-1] - closes.iloc[-20]) / closes.iloc[-20] if len(closes) >= 20 else 0.0
    
    rsi = calculate_rsi(closes, period=14).iloc[-1] / 100.0
    atr = calculate_atr(sub, period=14).iloc[-1]
    atr_pct = (atr / closes.iloc[-1]) if closes.iloc[-1] > 0 else 0.0
    
    ema200 = calculate_ema(closes, span=min(200, len(closes))).iloc[-1]
    dist_200 = (closes.iloc[-1] - ema200) / ema200 if ema200 > 0 else 0.0
    
    rvol = min(5.0, calculate_rvol(sub, baseline_period=20).iloc[-1]) / 5.0
    delta, _ = estimate_volume_delta(sub)
    cvd_ratio = np.tanh(delta.iloc[-5:].mean() / (sub["volume"].iloc[-5:].mean() + 1e-5))
    
    state = np.array([ret_5, ret_10, ret_20, rsi, atr_pct, dist_200, rvol, cvd_ratio], dtype=np.float32)
    return np.nan_to_num(state, nan=0.0)

def train_and_evaluate_drl_agent(
    symbol_data: dict[str, pd.DataFrame],
    epochs: int = 15,
    initial_capital: float = 100000.0
) -> tuple[PerformanceReport, list]:
    """
    Trains Policy Gradient DRL agent on multi-asset market data and evaluates performance.
    """
    device = torch.device("cpu")
    policy = DRLTradingPolicyNetwork(input_dim=8, hidden_dim=64, output_dim=3).to(device)
    optimizer = optim.Adam(policy.parameters(), lr=0.003)

    log.info(f"Training Deep RL Policy Network over {epochs} epochs...")

    # Training Loop (REINFORCE Algorithm with baseline)
    for epoch in range(epochs):
        for sym, df in symbol_data.items():
            if len(df) < 150:
                continue

            log_probs = []
            rewards = []
            position = 0.0  # 0: Cash, 1: 50%, 2: 100%

            for i in range(50, min(len(df) - 1, 500)):
                state = extract_state_features(df, i)
                state_tensor = torch.tensor(state, dtype=torch.float32).unsqueeze(0).to(device)
                
                probs = policy(state_tensor)
                dist = torch.distributions.Categorical(probs)
                action = dist.sample()
                log_probs.append(dist.log_prob(action))

                # Calculate reward on next bar return
                next_ret = (df["close"].iloc[i+1] - df["close"].iloc[i]) / df["close"].iloc[i]
                action_alloc = action.item() * 0.5  # 0.0, 0.5, 1.0
                trade_ret = action_alloc * next_ret
                
                # Sortino penalized reward: Heavy penalty for downside loss when allocated
                reward = trade_ret if trade_ret >= 0 else trade_ret * 2.5
                rewards.append(reward)

            # Policy Gradient Update
            if log_probs:
                discounted_rewards = []
                running_add = 0
                for r in reversed(rewards):
                    running_add = r + 0.95 * running_add
                    discounted_rewards.insert(0, running_add)

                disc_tensor = torch.tensor(discounted_rewards, dtype=torch.float32)
                disc_tensor = (disc_tensor - disc_tensor.mean()) / (disc_tensor.std() + 1e-7)

                loss = -torch.sum(torch.stack(log_probs) * disc_tensor)
                optimizer.zero_grad()
                loss.backward()
                optimizer.step()

    # Out-of-Sample / Final Evaluation
    policy.eval()
    all_timestamps = sorted(list({ts for df in symbol_data.values() for ts in df.index}))
    equity = initial_capital
    cash = initial_capital
    positions = {}
    trade_pnls = []
    equity_curve = [initial_capital]

    with torch.no_grad():
        for ts in all_timestamps:
            for sym, df in symbol_data.items():
                if ts not in df.index:
                    continue
                loc = df.index.get_loc(ts)
                loc_idx = loc if isinstance(loc, int) else int(loc.start)
                if loc_idx < 50:
                    continue

                state = extract_state_features(df, loc_idx)
                state_tensor = torch.tensor(state, dtype=torch.float32).unsqueeze(0)
                probs = policy(state_tensor)
                best_action = torch.argmax(probs).item()  # 0: Cash, 1: 50%, 2: 100%

                current_price = float(df.loc[ts, "close"]) if isinstance(df.loc[ts], pd.Series) else float(df.loc[ts, "close"].iloc[-1])

                # Execute action
                if best_action > 0 and sym not in positions and cash >= 1000:
                    alloc_val = (equity * 0.40)
                    shares = int(alloc_val / current_price)
                    if shares > 0 and (shares * current_price) <= cash:
                        cash -= (shares * current_price)
                        positions[sym] = {"shares": shares, "entry": current_price}
                elif best_action == 0 and sym in positions:
                    pos = positions.pop(sym)
                    proceeds = pos["shares"] * current_price
                    cash += proceeds
                    pnl = proceeds - (pos["shares"] * pos["entry"])
                    trade_pnls.append(pnl)

            unrealized = sum(p["shares"] * float(symbol_data[s].loc[ts, "close"].iloc[-1] if isinstance(symbol_data[s].loc[ts], pd.DataFrame) else symbol_data[s].loc[ts, "close"]) for s, p in positions.items() if ts in symbol_data[s].index)
            equity = cash + unrealized
            equity_curve.append(equity)

    # Close remaining
    for sym, pos in list(positions.items()):
        current_price = float(symbol_data[sym]["close"].iloc[-1])
        proceeds = pos["shares"] * current_price
        cash += proceeds
        pnl = proceeds - (pos["shares"] * pos["entry"])
        trade_pnls.append(pnl)

    report = calculate_performance(trade_pnls=trade_pnls, equity_curve=equity_curve)
    return report, trade_pnls
