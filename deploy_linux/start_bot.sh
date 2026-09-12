#!/usr/bin/env bash
# ==============================================================================
# AutoTrader Linux Master Executable Launcher
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "=================================================================="
echo "  🚀 Starting AutoTrader Autonomous Engine on Linux..."
echo "  📂 Working Directory: $DIR"
echo "=================================================================="

# Ensure virtualenv exists
if [ ! -d ".venv" ]; then
    echo "⚠️ Virtual environment not found. Creating .venv..."
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
else
    source .venv/bin/activate
fi

# Load environment variables if .env exists
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Execute the Telemetry Server and Autonomous Engine
exec python3 run_server.py
