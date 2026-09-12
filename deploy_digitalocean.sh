#!/usr/bin/env bash
# ==============================================================================
# AutoTrader — Automated 1-Click DigitalOcean VPS Deployment Script
# Configures Ubuntu 24.04/22.04 LTS Droplet for 24/7 Autonomous Trading
# ==============================================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

clear 2>/dev/null || true
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║    🌊  AUTOTRADER AI — DIGITALOCEAN CLOUD VPS DEPLOYMENT     ║"
echo "  ║    24/7 Autonomous Cloud Engine  |  Alpaca Live Trading      ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

INSTALL_DIR="/opt/autotrader"
SERVICE_FILE="/etc/systemd/system/autotrader.service"

# ── 1. Update system & install dependencies ───────────────────────────────────
echo -e "${CYAN}📦 Installing required system packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq python3 python3-venv python3-pip curl ufw git rsync >/dev/null

# ── 2. Configure Firewall (Allow SSH & AutoTrader Port 8000) ──────────────────
echo -e "${CYAN}🛡️  Configuring cloud firewall (Port 22 SSH & Port 8000 API)...${NC}"
ufw allow 22/tcp >/dev/null 2>&1 || true
ufw allow 8000/tcp >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true

# ── 3. Fetch / Update Codebase ────────────────────────────────────────────────
echo -e "${CYAN}📥 Syncing latest AutoTrader engine from GitHub...${NC}"
REPO_URL="https://github.com/Potatomagwuiski/AutoTrader-automation-project.git"
mkdir -p "$INSTALL_DIR"

if [ -d "$INSTALL_DIR/.git" ]; then
    echo -e "${CYAN}🔄 Updating existing git repository...${NC}"
    cd "$INSTALL_DIR"
    git fetch origin main
    git reset --hard origin/main
elif [ -f "$INSTALL_DIR/run_server.py" ]; then
    echo -e "${CYAN}🔄 Updating existing standalone installation...${NC}"
    TMP_REPO=$(mktemp -d)
    git clone --depth 1 "$REPO_URL" "$TMP_REPO"
    rsync -av --exclude='.venv' --exclude='.env' "$TMP_REPO/" "$INSTALL_DIR/" >/dev/null
    rm -rf "$TMP_REPO"
    cd "$INSTALL_DIR"
else
    echo -e "${CYAN}📥 Cloning AutoTrader repository...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# ── 4. Setup Python Virtual Environment ───────────────────────────────────────
if [ ! -d ".venv" ]; then
    echo -e "${CYAN}⚙️  Creating Python virtual environment...${NC}"
    python3 -m venv .venv
fi

source .venv/bin/activate
echo -e "${CYAN}📦 Installing Python trading dependencies (FastAPI, Alpaca, Uvicorn)...${NC}"
pip install --upgrade pip --quiet
pip install fastapi "uvicorn[standard]" alpaca-py pandas numpy scipy yfinance pydantic websockets python-dotenv requests --quiet

# ── 5. Setup Environment (.env) ───────────────────────────────────────────────
if [ ! -f "$INSTALL_DIR/.env" ]; then
    cat << 'EOF' > "$INSTALL_DIR/.env"
# AutoTrader Cloud Environment Configuration
ALPACA_API_KEY=${ALPACA_API_KEY:-""}
ALPACA_SECRET_KEY=${ALPACA_SECRET_KEY:-""}
ALPACA_BASE_URL=${ALPACA_BASE_URL:-"https://paper-api.alpaca.markets"}
EXECUTION_MODE=${EXECUTION_MODE:-"paper"}
EOF
    chmod 600 "$INSTALL_DIR/.env"
fi

# ── 6. Setup Systemd 24/7 Cloud Service ────────────────────────────────────────
echo -e "${CYAN}⚙️  Configuring 24/7 systemd background service...${NC}"
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=AutoTrader Autonomous Trading Bot Engine (DigitalOcean Cloud)
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
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

systemctl daemon-reload
systemctl enable autotrader.service
systemctl restart autotrader.service

# Get Public IP
PUBLIC_IP=$(curl -s https://api.ipify.org || curl -s ifconfig.me || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ AUTOTRADER CLOUD ENGINE IS LIVE ON DIGITALOCEAN 24/7!   ${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e "  🌐 ${BOLD}YOUR PERMANENT CLOUD URL:${NC} ${CYAN}${BOLD}http://$PUBLIC_IP:8000${NC}"
echo -e "  📡 ${BOLD}WEBSOCKET STREAM:${NC}        ${CYAN}ws://$PUBLIC_IP:8000/ws/telemetry${NC}"
echo -e "  🛡️  ${BOLD}FIREWALL:${NC}                ${GREEN}Port 8000 Allowed & Active${NC}"
echo -e "  🔄 ${BOLD}AUTO-RESTART:${NC}            ${GREEN}Enabled (survives server reboots)${NC}"
echo ""
echo -e "${YELLOW}👉 Open your AutoTrader Phone App → Settings → Type: ${CYAN}http://$PUBLIC_IP:8000${NC}"
echo -e "${YELLOW}   Then tap 'Connect Global Engine' (100% permanent, works on 5G/LTE worldwide!)${NC}"
echo ""
