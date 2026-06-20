# 🚀 Kwara Poly Fees System — Run Modes

Pick the launcher that matches your situation. **You only need ONE.**

## 🖥️ Windows — three options

| Script | When to use | Needs internet? |
|---|---|---|
| `kwara_poly_launcher.bat` | **Start here.** Menu lets you pick mode 1 or 2. | One-time setup only. |
| `start_offline.bat` | Local PC + same Wi-Fi only. **Always works, no internet needed.** | Only for first-run `pip install` — then fully offline. |
| `start_tunnel.bat` | Public URL accessible from **any browser anywhere**. | Yes, while running (Cloudflare tunnel). |

## 🐧 Linux / macOS

| Script | Mode |
|---|---|
| `start_offline.sh` | Local + Wi-Fi LAN |
| `start_tunnel.sh` | Public tunnel |

```bash
chmod +x start_offline.sh start_tunnel.sh
```

## 🧾 What's new in this build (offline + offline-QR)

1. **`vendor/libzbar-64.dll`** bundled — Windows QR scanning now works **without an internet connection** and without installing any extra system DLL.
2. **`start_offline.bat` / `start_offline.sh`** — true offline mode. Runs Flask bound to all interfaces; local PCs on the same Wi-Fi can open `http://<your-laptop-ip>:5000/` directly.
3. **`kwara_poly_launcher.bat`** — friendly menu on Windows. No more guessing which script to run.
4. **`start_tunnel.bat`** — improved to ship `libzbar-64.dll` to the tunnel folder on first run.

## 🌐 Two main access scenarios

### Scenario A — "I just want it on my PC and the same Wi-Fi"
```
1.  Double-click  kwara_poly_launcher.bat
2.  Pick [1] OFFLINE ONLY
3.  Open  http://127.0.0.1:5000/
```

### Scenario B — "Students in another city need to verify receipts I issue"
```
1.  Double-click  kwara_poly_launcher.bat
2.  Pick [2] PUBLIC TUNNEL
3.  Wait for the URL to print (e.g. https://xxx.trycloudflare.com)
4.  Right-click + Paste URL into WhatsApp / SMS
5.  Anyone opens it from a phone → lands on /verify
```

## 🔌 First-run checklist (Windows — one time)

| ✅ | Item |
|---|---|
| ☐ | Python 3.10+ installed, **ticked "Add to PATH"** at install time |
| ☐ | The repo downloaded/extracted somewhere (e.g. `C:\KwaraPolyFees`) |
| ☐ | Internet access for the first 30 seconds (downloads `cloudflared.exe` + pip packages) |
| ☐ | (One time) Default admin: **admin / admin123** |

After first run the project runs offline indefinitely. Restart anytime by double-clicking the launcher.
