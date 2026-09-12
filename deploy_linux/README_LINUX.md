# 🐧 AutoTrader Linux Deployment Guide

Run the AutoTrader Autonomous Trading Bot and Telemetry Bridge 24/7 on your Linux PC (Ubuntu, Debian, Fedora, Arch, etc.) with automatic launch on system reboot.

---

## ⚡ Quick 1-Step Setup on Linux

1. **Extract the archive or navigate to the project directory on your Linux PC**:
   ```bash
   cd autotrader_linux
   ```

2. **Run the 1-Click Installer & Auto-Start Service Setup**:
   ```bash
   chmod +x deploy_linux/*.sh
   ./deploy_linux/install_service.sh
   ```

That's it! The script will:
- Check Python 3 and configure `.venv`.
- Install all dependencies (`fastapi`, `uvicorn`, `yfinance`, `alpaca-py`, `pandas`, etc.).
- Create the `.env` file (if missing).
- Install and enable `autotrader.service` in `systemd`.
- Start the bot immediately and configure it to **automatically start upon PC boot or restart**.

---

## 🛠️ Bot Management Commands

You can manage the bot at any time using the `control.sh` helper:

```bash
# View Live Status & Telemetry Connection
./deploy_linux/control.sh status

# Follow Real-Time Live Logs
./deploy_linux/control.sh logs

# Restart the Bot
./deploy_linux/control.sh restart

# Stop the Bot
./deploy_linux/control.sh stop

# Start the Bot
./deploy_linux/control.sh start
```

Or use standard `systemctl` commands:
```bash
sudo systemctl status autotrader
sudo journalctl -u autotrader -f
sudo systemctl restart autotrader
```

---

## 🚀 Running Manually (Without Systemd)

If you prefer to run the bot interactively in your terminal:
```bash
./deploy_linux/start_bot.sh
```

---

## 📱 Connecting the Flutter Mobile Cockpit
Once running on your Linux PC, you can connect your mobile app from anywhere on the same local network:
- **REST API**: `http://<YOUR_LINUX_IP>:8000/api`
- **WebSocket**: `ws://<YOUR_LINUX_IP>:8000/ws/telemetry`
*(Find your local IP by running `hostname -I` or `ip a` on Linux)*.
