"""
Master Launcher for AutoTrader Telemetry Server.
Starts FastAPI & WebSocket bridge on port 8000.
"""

import uvicorn

if __name__ == "__main__":
    print("=" * 60)
    print("  🚀 AUTOTRADER LIVE TELEMETRY BRIDGE")
    print("  🔗 REST API:   http://127.0.0.1:8000/api")
    print("  📡 WEBSOCKET:  ws://127.0.0.1:8000/ws/telemetry")
    print("  📱 FLUTTER:    Connecting Live Mobile Cockpit...")
    print("=" * 60)
    uvicorn.run("autotrader.server:app", host="0.0.0.0", port=8000, reload=False, log_level="info")
