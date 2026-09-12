#!/usr/bin/env bash
# ==============================================================================
# AutoTrader Linux Management Utility
# ==============================================================================

ACTION="${1:-status}"

case "$ACTION" in
    status)
        echo "📊 AutoTrader Service Status:"
        sudo systemctl status autotrader.service --no-pager
        ;;
    logs)
        echo "📜 Streaming AutoTrader Real-Time Logs (Press Ctrl+C to exit):"
        sudo journalctl -u autotrader.service -f -n 50
        ;;
    restart)
        echo "🔄 Restarting AutoTrader Service..."
        sudo systemctl restart autotrader.service
        echo "✅ Service restarted."
        sudo systemctl status autotrader.service --no-pager
        ;;
    start)
        echo "🚀 Starting AutoTrader Service..."
        sudo systemctl start autotrader.service
        echo "✅ Service started."
        sudo systemctl status autotrader.service --no-pager
        ;;
    stop)
        echo "🛑 Stopping AutoTrader Service..."
        sudo systemctl stop autotrader.service
        echo "✅ Service stopped."
        ;;
    enable)
        echo "⚡ Enabling AutoTrader on Boot..."
        sudo systemctl enable autotrader.service
        echo "✅ Service enabled on boot."
        ;;
    disable)
        echo "❌ Disabling AutoTrader on Boot..."
        sudo systemctl disable autotrader.service
        echo "✅ Service disabled on boot."
        ;;
    *)
        echo "Usage: $0 {status|logs|restart|start|stop|enable|disable}"
        exit 1
        ;;
esac
