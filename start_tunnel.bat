@echo off
:: ==============================================================
::  Kwara Poly Fees System — Public Tunnel Launcher (Windows)
::  - Starts Flask app
::  - Downloads + installs cloudflared to %LOCALAPPDATA%\KwaraPolyTunnel
::  - Opens a public tunnel accessible from any browser
::  - Keeps running until the user closes this window
::  - First run downloads cloudflared, subsequent runs use the cached one
:: ==============================================================
setlocal ENABLEDELAYEDEXPANSION
cd /d "%~dp0"

set PORT=5000
set CF_DIR=%LOCALAPPDATA%\KwaraPolyTunnel
set CF_EXE=%CF_DIR%\cloudflared.exe
set APP_LOG=%CF_DIR%\flask.log
set CF_LOG=%CF_DIR%\cloudflared.log
set URL_FILE=%CF_DIR%\public_url.txt

echo.
echo ==============================================================
echo   KWARA POLY FEES SYSTEM  -  PUBLIC TUNNEL LAUNCHER
echo ==============================================================
echo   Project folder : %CD%
echo   Local Flask URL: http://127.0.0.1:%PORT%
echo   Tunnel folder  : %CF_DIR%
echo ==============================================================
echo.

:: --- Step 1: setup tunnel folder -----------------------------
if not exist "%CF_DIR%" mkdir "%CF_DIR%"

:: --- Step 2: ensure cloudflared.exe exists -------------------
if not exist "%CF_EXE%" (
  echo [setup] Downloading cloudflared (one-time only) ...
  powershell -NoProfile -Command ^
    "$ErrorActionPreference='Stop'; ^
     try { Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile '%CF_EXE%' } ^
     catch { Write-Host 'Download failed:' $_.Exception.Message; exit 1 }"
  if errorlevel 1 (
    echo.
    echo [!] cloudflared download failed. Open this window's internet/whitelist settings and try again.
    pause & exit /b 1
  )
)
echo [setup] cloudflared ready.

:: --- Step 3: check Python ----------------------------------
where python >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Python is not installed or not on PATH.
  echo         Install Python 3 from https://www.python.org/downloads/ and tick "Add to PATH".
  pause & exit /b 1
)

:: --- Step 4: install Python requirements once ---------------
if exist "requirements.txt" (
  echo [setup] Installing Python requirements (one-time) ...
  python -m pip install --upgrade pip >nul 2>&1
  python -m pip install -r requirements.txt 2>>"%CF_DIR%\pip_errors.txt"
  if errorlevel 1 (
    echo [!] pip install had warnings. See %CF_DIR%\pip_errors.txt - continuing anyway.
  ) else (
    echo [setup] Python requirements OK.
  )
)

:: --- Step 5: kill previous Flask + cloudflared ----------------
echo [cleanup] stopping any old instances ...
taskkill /IM python.exe /FI "WINDOWTITLE eq KwaraPolyFlask*" /T /F >nul 2>&1
taskkill /IM cloudflared.exe /T /F >nul 2>&1
timeout /t 2 /nobreak >nul

:: --- Step 6: start Flask in its own window --------------------
echo [start] launching flask on port %PORT% ...
start "KwaraPolyFlask" /MIN cmd /c "python app.py >> %APP_LOG% 2>&1"

:: --- Step 7: wait for Flask to listen ---------------------------
set /a TRIES=0
:WAIT_FLASK
set /a TRIES+=1
powershell -NoProfile -Command ^
  "$ErrorActionPreference='SilentlyContinue'; ^
   $ok = (Test-NetConnection -ComputerName 127.0.0.1 -Port %PORT% -InformationLevel Quiet) -eq $true; ^
   if ($ok) { exit 0 } else { exit 1 }" >nul 2>&1
if errorlevel 1 (
  if !TRIES! LSS 30 (
    timeout /t 1 /nobreak >nul
    goto WAIT_FLASK
  )
  echo [ERROR] Flask did not start within 30s. Check %APP_LOG%
  type "%APP_LOG%" 2>nul
  pause & exit /b 1
)
echo [start] flask is up.

:: --- Step 8: start cloudflared in this window ----------------
echo [start] launching cloudflared tunnel ...
(
  echo.
  echo  ============================================================
  echo   PUBLIC TUNNEL ACTIVE - share the URL below with anyone:
  echo  ============================================================
  echo.
) > "%URL_FILE%.header"

start /B "" "%CF_EXE%" tunnel --no-autoupdate --url http://127.0.0.1:%PORT% >> "%CF_LOG%" 2>&1

:: --- Step 9: wait for the trycloudflare URL to appear ---------
set /a TRIES=0
:WAIT_URL
set /a TRIES+=1
findstr /R "https://[abcdefghijklmnopqrstuvwxyz0123456789-]*\.trycloudflare\.com" "%CF_LOG%" >nul 2>&1
if errorlevel 1 (
  if !TRIES! LSS 60 (
    timeout /t 1 /nobreak >nul
    goto WAIT_URL
  )
  echo [ERROR] Could not get tunnel URL. View %CF_LOG% for details.
  type "%CF_LOG%"
  pause & exit /b 1
)

:: --- Step 10: extract URL, copy to clipboard, write file -----
for /f "tokens=*" %%U in ('findstr /R "https://[abcdefghijklmnopqrstuvwxyz0123456789-]*\.trycloudflare\.com" "%CF_LOG%"') do (
  set "TUNNEL_URL=%%U"
  goto :GOT_URL
)
:GOT_URL

:: trim any leftovers
for /f "tokens=1 delims= " %%A in ("%TUNNEL_URL%") do set "TUNNEL_URL=%%A"

> "%URL_FILE%" echo %TUNNEL_URL%
type "%URL_FILE%.header" "%URL_FILE%" > "%CF_DIR%\live_url_with_header.txt"

:: copy URL to clipboard
echo | set /p dummy=%TUNNEL_URL% | clip >nul 2>&1

echo.
echo  ====================================================================
echo   PUBLIC TUNNEL URL:  %TUNNEL_URL%
echo   PUBLIC VERIFY URL:  %TUNNEL_URL%/verify
echo   PUBLIC RECEIPT URL: %TUNNEL_URL%/p/KWP/xxxxxxx (your receipts)
echo  ====================================================================
echo   The URL has been COPIED to your clipboard.
echo.
echo   Share it (WhatsApp / Email / SMS) with anyone — they can open it
echo   from any browser worldwide to verify the payment receipt.
echo.
echo   This window must stay open. Closing it stops the tunnel.
echo   Logs: %CF_LOG%
echo   Flask log: %APP_LOG%
echo  ====================================================================
echo.

:: --- Step 11: keep window alive until user closes it ----------
echo Press any key (or close this window) to STOP the tunnel...
pause >nul

echo.
echo [shutdown] stopping cloudflared ...
taskkill /IM cloudflared.exe /T /F >nul 2>&1
echo [shutdown] stopping flask ...
taskkill /FI "WINDOWTITLE eq KwaraPolyFlask*" /T /F >nul 2>&1
echo.
echo [done] Tunnel closed. You can close this window now.
pause
endlocal
