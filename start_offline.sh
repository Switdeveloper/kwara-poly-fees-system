#!/usr/bin/env bash
# ==============================================================
#  Kwara Poly Fees System — OFFLINE-only launcher (Linux/macOS)
#  - Fully offline once dependencies are installed
#  - LAN-only access via host's IP
#  - No tunnel, no cloudflared, no internet
# ==============================================================
set -u
cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"

PORT=5000
HOST=0.0.0.0
LOG="$PWD/app.log"

# Detect LAN IP (Linux first, macOS fallback)
LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "$LAN_IP" ] && LAN_IP=$(ipconfig getifaddr en0 2>/dev/null)

echo
echo "=============================================================="
echo "  KWARA POLY FEES SYSTEM  -  OFFLINE / LAN-ONLY MODE"
echo "=============================================================="
echo "  Folder     : $PWD"
echo "  Local URL  : http://127.0.0.1:$PORT"
if [ -n "$LAN_IP" ]; then
  echo "  LAN URL    : http://$LAN_IP:$PORT  (other PCs on same Wi-Fi)"
fi
echo "=============================================================="
echo

# 1. check python3
if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] python3 not found on PATH."
  exit 1
fi

# 2. ensure deps
if ! python3 -c "import flask, qrcode, pyzbar, PIL" >/dev/null 2>&1; then
  echo "[setup] Installing Python dependencies..."
  if [ -f vendor/wheels/requirements.txt ] && [ -d vendor/wheels ]; then
    pip3 install --no-index --find-links vendor/wheels -r vendor/wheels/requirements.txt
  else
    pip3 install -r requirements.txt
  fi
fi

# 3. init DB if absent
if [ ! -f kwara_fees.db ]; then
  echo "[setup] initializing local database ..."
  python3 database_init.py
fi

# 4. kill prior instance
pkill -f "python3 app.py" 2>/dev/null
sleep 1

# 5. launch Flask in background
echo "[start] launching flask on $HOST:$PORT ..."
python3 app.py > "$LOG" 2>&1 &
FLASK_PID=$!

# 6. wait for Flask
TRIES=0
until curl -sf http://127.0.0.1:$PORT/verify >/dev/null 2>&1; do
  TRIES=$((TRIES+1))
  if [ "$TRIES" -ge 30 ]; then
    echo "[ERROR] Flask did not start. See $LOG"
    cat "$LOG"
    exit 1
  fi
  sleep 1
done

echo
echo "  =================================================="
echo "   OFFLINE SERVER READY"
echo
# Auto-open browser if possible
if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://127.0.0.1:$PORT" >/dev/null 2>&1 &
elif command -v gnome-open >/dev/null 2>&1; then
    gnome-open "http://127.0.0.1:$PORT" >/dev/null 2>&1 &
fi
echo "   Login  : http://127.0.0.1:$PORT/   (admin / admin123)"
echo "   Verify : http://127.0.0.1:$PORT/verify"
if [ -n "$LAN_IP" ]; then
  echo "   LAN    : http://$LAN_IP:$PORT/"
fi
echo
echo "   Runs until you press ENTER here."
echo "   For PUBLIC cross-internet access, run ./start_tunnel.sh instead."
echo "  =================================================="
echo
read -p "Press ENTER to STOP the server ..."

echo
echo "[shutdown] stopping flask ..."
kill $FLASK_PID 2>/dev/null
wait $FLASK_PID 2>/dev/null
echo "[done] Server closed."
