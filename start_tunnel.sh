#!/usr/bin/env bash
# ==============================================================
#  Kwara Poly Fees System — Public Tunnel Launcher (Linux/macOS)
#  - Starts Flask app
#  - Downloads + installs cloudflared to ~/.local/bin
#  - Opens a public tunnel accessible from any browser
#  - Keeps running until you press Ctrl+C
# ==============================================================
set -e

cd "$(dirname "$0")"
PORT="${PORT:-5000}"
CF_DIR="$HOME/.local/share/kwara-poly-tunnel"
CF_EXE="$CF_DIR/cloudflared"
CF_LOG="$CF_DIR/cloudflared.log"
APP_LOG="$CF_DIR/flask.log"
URL_FILE="$CF_DIR/public_url.txt"

mkdir -p "$CF_DIR"

echo "=============================================================="
echo " KWARA POLY FEES SYSTEM  -  PUBLIC TUNNEL LAUNCHER"
echo " Project folder : $(pwd)"
echo " Local Flask URL: http://127.0.0.1:${PORT}"
echo " Tunnel folder  : ${CF_DIR}"
echo "=============================================================="

# --- 1. Install cloudflared if missing
if [ ! -x "$CF_EXE" ]; then
    echo "[setup] Downloading cloudflared (one-time only)..."
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  BIN="cloudflared-linux-amd64" ;;
        aarch64) BIN="cloudflared-linux-arm64"  ;;
        armv7l)  BIN="cloudflared-linux-arm"    ;;
        *) echo "[ERROR] Unsupported arch: $ARCH"; exit 1 ;;
    esac
    curl -fsSL -o "$CF_EXE" \
        "https://github.com/cloudflare/cloudflared/releases/latest/download/${BIN}"
    chmod +x "$CF_EXE"
fi
echo "[setup] cloudflared ready."

# --- 2. Python requirements
if [ -f "requirements.txt" ]; then
    pip install -q --disable-pip-version-check -r requirements.txt || \
        echo "[warn] pip had warnings, continuing"
fi

# --- 3. Cleanup any prior instances
pkill -f "cloudflared tunnel --url" 2>/dev/null || true
pkill -f "python3? .* app.py"      2>/dev/null || true
sleep 1

# --- 4. Start Flask in background
echo "[start] launching flask on port $PORT ..."
python3 app.py >> "$APP_LOG" 2>&1 &
FLASK_PID=$!

# Wait for Flask to listen
for i in $(seq 1 30); do
    if curl -sf "http://127.0.0.1:${PORT}/verify" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
if ! curl -sf "http://127.0.0.1:${PORT}/verify" >/dev/null 2>&1; then
    echo "[ERROR] Flask failed to start. Check $APP_LOG"
    cat "$APP_LOG" || true
    kill $FLASK_PID 2>/dev/null || true
    exit 1
fi
echo "[start] flask is up."

# --- 5. Start cloudflared in background
echo "[start] launching cloudflared tunnel ..."
"$CF_EXE" tunnel --no-autoupdate --url "http://127.0.0.1:${PORT}" >> "$CF_LOG" 2>&1 &
CF_PID=$!

trap 'echo; echo "[shutdown] killing tunnel ..."; kill $CF_PID 2>/dev/null; \
       pkill -f "python3? .* app.py" 2>/dev/null; exit 0' INT TERM

# --- 6. Wait for the public URL to appear
URL=""
for i in $(seq 1 60); do
    URL=$(grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" "$CF_LOG" 2>/dev/null | head -1 || true)
    if [ -n "$URL" ]; then break; fi
    sleep 1
done

if [ -z "$URL" ]; then
    echo "[ERROR] Could not parse tunnel URL. See $CF_LOG"
    kill $CF_PID $FLASK_PID 2>/dev/null || true
    exit 1
fi

echo "$URL" > "$URL_FILE"

# Try copying to clipboard
if command -v xclip      >/dev/null 2>&1; then echo -n "$URL" | xclip -selection clipboard
elif command -v pbcopy   >/dev/null 2>&1; then echo -n "$URL" | pbcopy
elif command -v wl-copy  >/dev/null 2>&1; then echo -n "$URL" | wl-copy
fi

echo ""
echo "===================================================================="
echo "  PUBLIC TUNNEL URL:  ${URL}"
echo "  PUBLIC VERIFY URL:  ${URL}/verify"
echo "  PUBLIC RECEIPT URL: ${URL}/p/KWP/xxxxxxx"
echo "===================================================================="
echo "  Share the URL with anyone — any browser worldwide."
echo "  The URL has been COPIED to your clipboard (if a clipboard tool is installed)."
echo ""
echo "  Press Ctrl+C to stop the tunnel and exit."
echo "  Logs:"
echo "    tunnel : ${CF_LOG}"
echo "    flask  : ${APP_LOG}"
echo "===================================================================="

wait
