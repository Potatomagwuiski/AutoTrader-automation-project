#!/usr/bin/env bash
# ==============================================================================
# AutoTrader Linux Automated 1-Click Installer & Systemd Auto-Start Service Setup
# ==============================================================================
set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}==================================================================${NC}"
echo -e "${CYAN}${BOLD}  🤖 AUTOTRADER LINUX INSTALLER & AUTO-BOOT SERVICE SETUP          ${NC}"
echo -e "${CYAN}${BOLD}==================================================================${NC}"

# 1. Determine Project Directory & User
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CURRENT_USER="$(whoami)"
CURRENT_GROUP="$(id -gn)"
PYTHON_EXEC="python3"

echo -e "📂 Project Directory: ${GREEN}$SCRIPT_DIR${NC}"
echo -e "👤 Target User:       ${GREEN}$CURRENT_USER${NC}"
echo -e "👥 Target Group:      ${GREEN}$CURRENT_GROUP${NC}"
echo ""

# 2. Check Python Installation
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ python3 could not be found.${NC}"
    echo "Please install Python 3.10 or newer (e.g. 'sudo apt update && sudo apt install -y python3 python3-venv python3-pip')."
    exit 1
fi

PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo -e "🐍 Found Python Version: ${GREEN}$PY_VERSION${NC}"

# 3. Create Virtual Environment
cd "$SCRIPT_DIR"
if [ ! -d ".venv" ]; then
    echo -e "\n${YELLOW}⚙️  Creating Python Virtual Environment in .venv...${NC}"
    python3 -m venv .venv || {
        echo -e "${RED}❌ Failed to create venv. You may need to run: sudo apt install -y python3-venv${NC}"
        exit 1
    }
fi

echo -e "📦 Activating .venv and installing Python dependencies..."
source .venv/bin/activate
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
echo -e "${GREEN}✅ All Python dependencies installed successfully.${NC}"

# 4. Check for .env Configuration
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  No .env file found. Creating default paper trading .env...${NC}"
    cat << 'EOF' > .env
# AutoTrader Environment Configuration
ALPACA_API_KEY=PKUYSD6QXABJ5SVZ55PAFUCOT7
ALPACA_SECRET_KEY=EFuxJ7P5XYFnvUd1LvGV8gfwuymRyYsQWcXSN6NigGuA
ALPACA_BASE_URL=https://paper-api.alpaca.markets
EXECUTION_MODE=paper
EOF
    echo -e "${GREEN}✅ Created default .env (Alpaca Paper Trading)${NC}"
fi

# 5. Make Executable Scripts Executable
chmod +x deploy_linux/start_bot.sh
chmod +x deploy_linux/control.sh 2>/dev/null || true

# 6. Generate Systemd Service File
SERVICE_FILE="/etc/systemd/system/autotrader.service"
TEMP_SERVICE="/tmp/autotrader.service"

echo -e "\n${CYAN}⚙️  Generating Systemd Service for Auto-Boot on Linux...${NC}"

cat << EOF > "$TEMP_SERVICE"
[Unit]
Description=AutoTrader Autonomous Trading Bot & Telemetry Bridge
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_GROUP
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/.venv/bin/python3 $SCRIPT_DIR/run_server.py
Restart=always
RestartSec=5s
KillMode=mixed
TimeoutStopSec=10
EnvironmentFile=$SCRIPT_DIR/.env
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo -e "📋 Service definition created at $TEMP_SERVICE"
echo -e "${YELLOW}🔒 Installing service to /etc/systemd/system/ (requires sudo privileges)...${NC}"

if [ "$EUID" -ne 0 ]; then
    sudo cp "$TEMP_SERVICE" "$SERVICE_FILE"
    sudo chmod 644 "$SERVICE_FILE"
    sudo systemctl daemon-reload
    sudo systemctl enable autotrader.service
    sudo systemctl restart autotrader.service
else
    cp "$TEMP_SERVICE" "$SERVICE_FILE"
    chmod 644 "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl enable autotrader.service
    systemctl restart autotrader.service
fi

rm -f "$TEMP_SERVICE"

echo -e "\n${GREEN}${BOLD}==================================================================${NC}"
echo -e "${GREEN}${BOLD}  ✅ AUTOTRADER IS NOW RUNNING & ENABLED ON BOOT!                 ${NC}"
echo -e "${GREEN}${BOLD}==================================================================${NC}"
echo -e "🔗 REST API:    ${CYAN}http://localhost:8000/api${NC}"
echo -e "📡 WebSocket:   ${CYAN}ws://localhost:8000/ws/telemetry${NC}"
echo ""

# ─── OPTIONAL: CLOUDFLARE TUNNEL FOR GLOBAL ACCESS ────────────────────────────
echo -e "${YELLOW}${BOLD}🌐 OPTIONAL: Enable Global Access via Cloudflare Tunnel?${NC}"
echo -e "   This exposes your bot securely to the internet so your phone"
echo -e "   can connect from ANYWHERE in the world — no port forwarding needed."
read -rp "   Set up Cloudflare Tunnel now? [y/N]: " CF_CHOICE

if [[ "$CF_CHOICE" =~ ^[Yy]$ ]]; then
    # Install cloudflared if not present
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${CYAN}📦 Installing cloudflared (Cloudflare Tunnel client)...${NC}"
        ARCH=$(uname -m)
        if [ "$ARCH" == "x86_64" ]; then
            CF_PKG="cloudflared-linux-amd64.deb"
        elif [ "$ARCH" == "aarch64" ]; then
            CF_PKG="cloudflared-linux-arm64.deb"
        else
            CF_PKG="cloudflared-linux-amd64.deb"
        fi
        curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/$CF_PKG" -o /tmp/cloudflared.deb
        sudo dpkg -i /tmp/cloudflared.deb || sudo apt-get install -f -y
        rm -f /tmp/cloudflared.deb
    fi

    # Run a quick tunnel and capture the URL
    echo -e "${CYAN}🚇 Starting Cloudflare Quick Tunnel (no account required)...${NC}"
    echo -e "${YELLOW}Your global URL will appear below in seconds. Copy it into the AutoTrader mobile app Settings.${NC}"
    echo ""
    cloudflared tunnel --url http://localhost:8000 &
    CF_PID=$!
    sleep 5

    echo ""
    echo -e "${GREEN}✅ Cloudflare Tunnel is running (PID $CF_PID).${NC}"
    echo -e "${YELLOW}⚠️  Note: Quick Tunnels use temporary URLs. For a permanent URL, run 'cloudflared tunnel login' and create a named tunnel.${NC}"
    echo ""
    echo -e "  To make the tunnel auto-start with the bot, add this to your systemd service ExecStart line:"
    echo -e "  ${CYAN}ExecStartPost=/usr/local/bin/cloudflared tunnel --url http://localhost:8000${NC}"
fi

echo ""
echo -e "🛠️  ${BOLD}Helpful Management Commands:${NC}"
echo -e "  • Check Live Status:    ${YELLOW}sudo systemctl status autotrader${NC}"
echo -e "  • View Real-Time Logs:  ${YELLOW}journalctl -u autotrader -f${NC}"
echo -e "  • Restart Bot:          ${YELLOW}sudo systemctl restart autotrader${NC}"
echo -e "  • Stop Bot:             ${YELLOW}sudo systemctl stop autotrader${NC}"
echo -e "  • Or use helper:        ${YELLOW}./deploy_linux/control.sh (status|logs|restart|stop)${NC}"
echo -e "=================================================================="
