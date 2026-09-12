#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "Building self-contained installer..."
./package_linux.sh

INSTALLER="deploy_digitalocean_installer.sh"

cat << 'HEADER' > "$INSTALLER"
#!/usr/bin/env bash
# ==============================================================================
# AutoTrader AI — Automated DigitalOcean Cloud Installer
# ==============================================================================
set -e

INSTALL_DIR="/opt/autotrader"
SERVICE_FILE="/etc/systemd/system/autotrader.service"

echo "🌊 Updating AutoTrader AI on DigitalOcean Cloud (165.22.41.58)..."

# 1. System packages
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq python3 python3-venv python3-pip curl ufw git tar gzip >/dev/null 2>&1

# 2. Firewall
ufw allow 22/tcp >/dev/null 2>&1 || true
ufw allow 8000/tcp >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true

# 3. Directory & Extraction
mkdir -p "$INSTALL_DIR"
ARCHIVE_LINE=$(awk '/^__ARCHIVE_BELOW__/{print NR + 1; exit 0;}' "$0")
tail -n +${ARCHIVE_LINE} "$0" | tar -xzf - --strip-components=1 -C "$INSTALL_DIR" 2>/dev/null || tail -n +${ARCHIVE_LINE} "$0" | tar -xzf - -C "$INSTALL_DIR"

# 4. Virtualenv & Dependencies
cd "$INSTALL_DIR"
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate
pip install --upgrade pip --quiet >/dev/null 2>&1
pip install fastapi "uvicorn[standard]" alpaca-py pandas numpy scipy yfinance pydantic websockets python-dotenv requests --quiet >/dev/null 2>&1

# 5. Environment
cat << 'ENVEOF' > "$INSTALL_DIR/.env"
ALPACA_API_KEY=PKUYSD6QXABJ5SVZ55PAFUCOT7
ALPACA_SECRET_KEY=EFuxJ7P5XYFnvUd1LvGV8gfwuymRyYsQWcXSN6NigGuA
ALPACA_BASE_URL=https://paper-api.alpaca.markets
EXECUTION_MODE=paper
ENVEOF
chmod 600 "$INSTALL_DIR/.env"

# 6. Systemd Service (24/7 Auto-Restart)
cat << SVCEOF > "$SERVICE_FILE"
[Unit]
Description=AutoTrader Autonomous Trading Bot Engine
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
SVCEOF

systemctl daemon-reload
systemctl enable autotrader.service
systemctl restart autotrader.service

echo ""
echo "=================================================================="
echo "  ✅ AUTOTRADER ENGINE IS ONLINE ON DIGITALOCEAN 24/7!"
echo "  🌐 PERMANENT CLOUD URL: http://165.22.41.58:8000"
echo "  📡 WEBSOCKET STREAM:    ws://165.22.41.58:8000/ws/telemetry"
echo "  🔄 AUTO-START:          Active on every boot"
echo "=================================================================="
echo ""
echo "Current Service Status:"
systemctl status autotrader.service --no-pager
exit 0
__ARCHIVE_BELOW__
HEADER

cat autotrader_linux.tar.gz >> "$INSTALLER"
chmod +x "$INSTALLER"
echo "Installer generated successfully: $INSTALLER"
