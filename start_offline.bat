@echo off
:: ==============================================================
::  Kwara Poly Fees System — OFFLINE-only launcher (Windows)
::  - 100%% offline once dependencies are installed
::  - LAN-only access (other PCs on the same Wi-Fi can open it)
::  - NO tunnel, NO cloudflared, NO internet required
::  - For public / cross-school access, use start_tunnel.bat instead
::  - This is the right script for "everything stays on my PC"
:: ==============================================================
setlocal ENABLEDELAYEDEXPANSION
cd /d "%~dp0"

set PORT=5000
set HOST=0.0.0.0
set LOG=%CD%\app.log

:: Show LAN IP so other PCs on the same Wi-Fi know where to connect
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /R /C:"IPv4"') do (
    for /f "tokens=*" %%j in ("%%i") do (
        set "LAN_IP=%%j"
        goto :GOT_IP
    )
)
:GOT_IP

echo.
echo ==============================================================
echo   KWARA POLY FEES SYSTEM  -  OFFLINE / LAN-ONLY MODE
echo ==============================================================
echo   Project folder : %CD%
echo   Local URL      : http://127.0.0.1:%PORT%
if defined LAN_IP echo   LAN URL        : http://!LAN_IP!:%PORT%  (other PCs on same Wi-Fi)
echo   Access         : verify at /verify, login at /
echo ==============================================================
echo.

:: --- Step 1: check Python ---------------------------------------
where python >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Python not found on PATH.
  echo         Install Python 3.10+ from https://python.org and tick "Add to PATH".
  pause & exit /b 1
)
for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PYVER=%%v
echo [check] Python !PYVER!
if exist "vendor\libzbar-64.dll" (
    echo [check] libzbar DLL bundled - QR decode will work offline.
)

:: --- Step 2: ensure deps once (skip if already installed) ------
echo [setup] verifying offline Python dependencies ...
python -c "import flask, qrcode, pyzbar, PIL" >nul 2>&1
if errorlevel 1 (
    if exist "vendor\requirements.txt" (
        echo [setup] Installing offline (only first run) ...
        python -m pip install --upgrade pip --disable-pip-version-check >nul 2>&1
        python -m pip install --no-index --find-links vendor\wheels -r vendor\requirements.txt
    ) else (
        if exist "requirements.txt" (
            echo [setup] Installing via PyPI - this needs internet once ...
            python -m pip install -r requirements.txt
        )
    )
    if errorlevel 1 (
        echo [ERROR] Python deps install failed.
        pause & exit /b 1
    )
) else (
    echo [setup] Offline dependencies already present.
)

:: --- Step 3: init DB if not present ----------------------------
if not exist "kwara_fees.db" (
  echo [setup] initializing local database ...
  python database_init.py
)

:: --- Step 4: kill any prior Flask instance --------------------
echo [cleanup] stopping any old instance ...
taskkill /FI "WINDOWTITLE eq KwaraPolyFlask*" /T /F >nul 2>&1
timeout /t 2 /nobreak >nul

:: --- Step 5: launch Flask in minimized window -----------------
echo [start] launching flask on %HOST%:%PORT% ...
start "KwaraPolyFlask" /MIN cmd /c "python app.py > %LOG% 2>&1"

:: --- Step 6: wait for Flask ------------------------------------
set /a TRIES=0
:WAIT_FLASK
set /a TRIES+=1
powershell -NoProfile -Command "(Test-NetConnection -ComputerName 127.0.0.1 -Port %PORT% -InformationLevel Quiet)" >nul 2>&1
if errorlevel 1 (
    if !TRIES! LSS 30 (
        timeout /t 1 /nobreak >nul
        goto WAIT_FLASK
    )
    echo [ERROR] Flask did not start within 30s. See %LOG%
    type "%LOG%" 2>nul
    pause & exit /b 1
)

echo.
echo  ===================================================================
echo   OFFLINE SERVER READY
echo.
echo   Login:      http://127.0.0.1:%PORT%/   (admin / admin123)
echo   Verify:     http://127.0.0.1:%PORT%/verify
if defined LAN_IP (
    echo   Other PCs (same Wi-Fi):
    echo       http://!LAN_IP!:%PORT%/
)
echo.
echo   This window STAYS OPEN and keeps the server running.
echo   Closing the window stops the local server.
echo.
echo   For PUBLIC access from any internet browser, run start_tunnel.bat instead.
echo  ===================================================================
echo.

:: --- Step 7: keep alive until close -----------------------------
echo Press any key (or close window) to STOP the local server ...
pause >nul

echo.
echo [shutdown] stopping flask ...
taskkill /FI "WINDOWTITLE eq KwaraPolyFlask*" /T /F >nul 2>&1
echo [done] Server closed. You can close this window now.
pause
endlocal
