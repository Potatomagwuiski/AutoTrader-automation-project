# AutoTrader: Fully Autonomous, Self-Adapting Trading System

A modular, event-driven, fully autonomous algorithmic trading system. Built with multi-stage universe screening, real-time regime detection, institutional momentum filters, strict risk management circuit breakers, and an autonomous closed-loop self-learning engine.

---

## Key Capabilities

1. **3-Stage Screening Pipeline (Noise Elimination)**
   - **Stage 1 (Fundamental & Sector Sieve):** Filters out debt-heavy or non-compliant companies (debt ratio $\le 33\%$, excluded sectors).
   - **Stage 2 (Liquidity & Float Guard):** Enforces minimum price ($1+) and float threshold ($\ge 20\text{M}$ shares) to prevent sub-dollar illiquidity traps.
   - **Stage 3 (Dynamic RVOL $\ge 3.0$ Scanner):** Isolates institutional volume surges and momentum catalysts from market noise.

2. **Adaptive Strategy Ensemble**
   - **Momentum Breakout:** Trades high-volume structural breakouts above VWAP.
   - **VWAP Pullback / Retest:** Captures institutional bounce entries in established uptrends.
   - **Mean Reversion:** Targets oversold bounces in ranging and high-volatility chop regimes.

3. **Non-Negotiable Risk Layer (Zero-Tolerance Circuit Breakers)**
   - **Hard Daily Drawdown Stop ($2.0\%$ Max Loss):** Halts trading immediately if daily drawdown is reached.
   - **Consecutive Loss Cooldown:** Imposes a mandatory 30-minute pause after 3 consecutive losses.
   - **Dynamic Position Sizing:** Calculates position size to risk strictly $1.0\%$ of account equity per trade.
   - **Dynamic Trailing Stops:** Locks in breakeven at $+1.0R$ and trails via ATR multipliers.

4. **Autonomous Self-Improvement & Strategy Darwinism**
   - **Regime Detection:** Dynamically classifies market state into *Bull Trending*, *Bear Trending*, *High Volatility Chop*, and *Low Volatility Range*.
   - **Symbolic / Genetic Mutation:** Evolves strategy parameters autonomously.
   - **Canary Sandbox:** New parameter mutations are tested in shadow simulation and must pass statistical hurdles (e.g. Profit Factor $\ge 1.30$, Win Rate $\ge 40\%$, Max DD $\le 5\%$) before being promoted to live execution.

---

## Directory Structure

```
.
├── autotrader/
│   ├── config/              # Configuration & Risk thresholds
│   ├── data/                # Market data providers & Local caching
│   ├── screening/           # Multi-stage screening pipeline
│   ├── features/            # VWAP, ATR, Swing Pivots, Price Action
│   ├── strategies/          # Active strategy ensemble
│   ├── risk/                # Position sizer, Trailing stops, Risk manager
│   ├── execution/           # Paper simulator & Order router
│   ├── learning/            # Regime detector, Mutator, Canary sandbox
│   ├── telemetry/           # Journal, Performance analytics, Logger
│   ├── engine.py            # Master Autonomous Engine Orchestrator
│   └── cli.py               # CLI interface
├── tests/                   # Automated test suite (13 unit tests)
├── cli.py                   # Root CLI launcher
└── requirements.txt
```

---

## Quick Start & CLI Usage

### 1. Run Universe Screener
Scan watchlist for stocks meeting Fundamental, Liquidity, and RVOL $\ge 3.0$ filters:
```bash
python3 cli.py scan --timeframe 5m
```

### 2. Run Historical Backtest Simulation
Backtest any strategy against historical market data with realistic slippage and commission friction:
```bash
python3 cli.py backtest --symbol NVDA --strategy momentum --bars 500 --capital 100000
python3 cli.py backtest --symbol TSLA --strategy vwap --bars 500
python3 cli.py backtest --symbol AAPL --strategy mean_reversion --bars 500
```

### 3. Run Autonomous Self-Learning & Canary Sandbox Test
Mutate strategy parameters and evaluate candidates against canary promotion hurdles:
```bash
python3 cli.py learn --symbol TSLA
```

### 4. Run the Master Autonomous Engine
Launch the end-to-end autonomous engine with continuous screening, trading, and background self-adaptation:
```bash
python3 cli.py run --mode paper
```

---

## Running the Automated Test Suite

```bash
source .venv/bin/activate
PYTHONPATH=. pytest tests/ -v
```
