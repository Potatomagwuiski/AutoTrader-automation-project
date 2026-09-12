#!/usr/bin/env bash
# ==============================================================================
# AutoTrader — 100% Autonomous 1-Click Terminal Executable for Linux
# Double-click or run once: auto-spawns terminal, installs everything,
# starts the engine, configures 24/7 boot service, and streams live logs.
# Zero options, zero prompts, zero user intervention required.
# ==============================================================================
set -e

# ── Auto-Spawn Terminal if double-clicked from GUI / File Manager ─────────────
if [ ! -t 0 ] || [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    for term in gnome-terminal xfce4-terminal konsole alacritty kitty terminator xterm; do
        if command -v "$term" &>/dev/null; then
            if [ "$term" = "gnome-terminal" ]; then
                exec gnome-terminal --title="🤖 AutoTrader AI Live Cockpit" -- bash -c "\"$SCRIPT_PATH\"; echo ''; read -p 'Press Enter to exit...' "
            elif [ "$term" = "konsole" ]; then
                exec konsole --title="🤖 AutoTrader AI Live Cockpit" -e bash -c "\"$SCRIPT_PATH\"; echo ''; read -p 'Press Enter to exit...' "
            elif [ "$term" = "xfce4-terminal" ]; then
                exec xfce4-terminal --title="🤖 AutoTrader AI Live Cockpit" -e "bash -c '\"$SCRIPT_PATH\"; echo \"\"; read -p \"Press Enter to exit...\" '"
            else
                exec "$term" -e "bash -c '\"$SCRIPT_PATH\"; echo \"\"; read -p \"Press Enter to exit...\" '"
            fi
        fi
    done
    if command -v x-terminal-emulator &>/dev/null; then
        exec x-terminal-emulator -e "bash -c '\"$SCRIPT_PATH\"; echo \"\"; read -p \"Press Enter to exit...\" '"
    fi
fi

INSTALL_DIR="$HOME/.autotrader"
SERVICE_FILE="/etc/systemd/system/autotrader.service"
CURRENT_USER="$(whoami)"
CURRENT_GROUP="$(id -gn 2>/dev/null || echo "$CURRENT_USER")"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

clear 2>/dev/null || true
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║    🤖  AUTOTRADER AI — AUTONOMOUS TRADING ENGINE             ║"
echo "  ║    100% Shariah Compliant  |  Zero-Click Auto Execution      ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── 1. Auto-Install Dependencies (Non-Interactive) ────────────────────────────
if ! command -v python3 &>/dev/null || ! python3 -c "import venv" &>/dev/null || ! command -v pip3 &>/dev/null || ! command -v curl &>/dev/null; then
    echo -e "${YELLOW}⚙️  Installing system dependencies...${NC}"
    if command -v apt-get &>/dev/null; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null 2>&1 || true
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 python3-venv python3-pip curl tar >/dev/null 2>&1 || true
    fi
fi

# ── 2. Extract embedded engine ────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
echo -e "${CYAN}📂 Extracting AutoTrader engine to $INSTALL_DIR...${NC}"
ARCHIVE_LINE=$(awk '/^__ARCHIVE_BELOW__/{print NR + 1; exit 0;}' "$0")
tail -n +${ARCHIVE_LINE} "$0" | tar -xzf - -C "$INSTALL_DIR" --strip-components=1 2>/dev/null || true
echo -e "${GREEN}✓ Engine extracted successfully.${NC}"

# ── 3. Virtualenv & Dependencies Setup (Automatic) ────────────────────────────
cd "$INSTALL_DIR"
if [ ! -d ".venv" ] || [ ! -f ".venv/bin/python3" ]; then
    echo -e "${CYAN}⚙️  Creating Python virtual environment...${NC}"
    python3 -m venv .venv
fi

source .venv/bin/activate
echo -e "${CYAN}📦 Preparing trading engine dependencies...${NC}"
pip install --upgrade pip --quiet >/dev/null 2>&1 || true
pip install -r requirements.txt --quiet >/dev/null 2>&1 || true
echo -e "${GREEN}✓ All dependencies ready.${NC}"

# ── 4. Systemd Auto-Start on Boot (Automatic 24/7) ─────────────────────────────
if command -v systemctl &>/dev/null; then
    echo -e "${CYAN}⚙️  Configuring 24/7 background system service...${NC}"
    cat << EOF > /tmp/autotrader.service
[Unit]
Description=AutoTrader Autonomous Trading Bot Engine
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_GROUP
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/.venv/bin/python3 $INSTALL_DIR/run_server.py
Restart=always
RestartSec=3s
EnvironmentFile=$INSTALL_DIR/.env
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo cp /tmp/autotrader.service "$SERVICE_FILE" 2>/dev/null || true
    sudo chmod 644 "$SERVICE_FILE" 2>/dev/null || true
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl enable autotrader.service 2>/dev/null || true
    sudo systemctl restart autotrader.service 2>/dev/null || true
    rm -f /tmp/autotrader.service
fi

LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")

echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ AUTOTRADER ENGINE IS ONLINE & RUNNING 24/7!              ${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e "  📡 Local Wi-Fi URL:   ${CYAN}${BOLD}http://$LOCAL_IP:8000${NC}"
echo -e "  📡 WebSocket Stream:  ${CYAN}ws://$LOCAL_IP:8000/ws/telemetry${NC}"
echo -e "  📡 UDP Beacon:        ${CYAN}Port 8001 (Auto-Discover Broadcast Active)${NC}"
echo -e "  🔄 Auto-Start:        ${GREEN}Enabled (Automatically runs on every boot)${NC}"
echo ""
echo -e "${YELLOW}Streaming real-time bot engine telemetry logs (Ctrl+C to detach):${NC}"
echo -e "${CYAN}--------------------------------------------------------------${NC}"
sleep 1

# Stream real-time logs directly so user immediately sees live activity
if command -v journalctl &>/dev/null; then
    journalctl -u autotrader -f -n 25 --no-tail 2>/dev/null || exec "$INSTALL_DIR/.venv/bin/python3" "$INSTALL_DIR/run_server.py"
else
    exec "$INSTALL_DIR/.venv/bin/python3" "$INSTALL_DIR/run_server.py"
fi

exit 0
__ARCHIVE_BELOW__
