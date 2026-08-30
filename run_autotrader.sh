#!/usr/bin/env bash
# AutoTrader AI Master 1-Click Launcher (Mac/Linux)

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "==============================================================================="
echo "  AUTOTRADER AI: AUTONOMOUS HALAL ALGORITHMIC TRADING SYSTEM"
echo "  100% Shariah Compliant (AAOIFI Standard) | 2-Position Alpha Compounding"
echo "==============================================================================="
echo ""

# Check for virtual environment
if [ ! -d ".venv" ]; then
    echo "[1/3] Creating Python Virtual Environment..."
    python3 -m venv .venv
fi

# Activate environment
source .venv/bin/activate

# Install requirements if needed
echo "[2/3] Verifying dependencies..."
pip install -q -r requirements.txt

# Start bot
echo "[3/3] Starting AutoTrader AI..."
echo ""
python start_bot.py
