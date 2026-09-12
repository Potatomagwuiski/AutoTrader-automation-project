#!/usr/bin/env bash
# ==============================================================================
# Package AutoTrader Linux Standalone Distribution Bundle
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "📦 Bundling AutoTrader Linux distribution..."

OUTPUT_TAR="autotrader_linux.tar.gz"
OUTPUT_ZIP="autotrader_linux.zip"
TMP_DIR="/tmp/autotrader_linux_bundle"

rm -rf "$TMP_DIR" "$OUTPUT_TAR" "$OUTPUT_ZIP"
mkdir -p "$TMP_DIR/autotrader_linux"

# Copy core engine, configuration, server, and deployment files
cp -r autotrader "$TMP_DIR/autotrader_linux/"
cp -r deploy_linux "$TMP_DIR/autotrader_linux/"
cp run_server.py "$TMP_DIR/autotrader_linux/"
cp start_bot.py "$TMP_DIR/autotrader_linux/"
cp requirements.txt "$TMP_DIR/autotrader_linux/"
cp README.md "$TMP_DIR/autotrader_linux/" 2>/dev/null || true
cp .env "$TMP_DIR/autotrader_linux/.env" 2>/dev/null || true

# Set execution permissions
chmod +x "$TMP_DIR/autotrader_linux/deploy_linux/"*.sh 2>/dev/null || true

# Create tar.gz and zip archives
cd "$TMP_DIR"
tar -czf "$DIR/$OUTPUT_TAR" autotrader_linux
zip -rq "$DIR/$OUTPUT_ZIP" autotrader_linux

rm -rf "$TMP_DIR"

echo "=================================================================="
echo "  ✅ Standalone Linux Bundle Generated Successfully!"
echo "  📂 TAR.GZ:  $DIR/$OUTPUT_TAR"
echo "  📂 ZIP:     $DIR/$OUTPUT_ZIP"
echo "=================================================================="
