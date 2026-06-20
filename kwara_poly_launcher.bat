@echo off
:: ==============================================================
::  Kwara Poly Fees System — choose run mode
::  1) Offline-only    — local + LAN, NO internet needed
::  2) Public tunnel   — opens a public URL via Cloudflare
:: ==============================================================
setlocal
cd /d "%~dp0"

:TOP
echo.
echo ==============================================================
echo   KWARA POLY FEES SYSTEM  -  RUN MODE
echo ==============================================================
echo.
echo   [1] OFFLINE ONLY       (local PC + same Wi-Fi devices)
echo   [2] PUBLIC TUNNEL      (any internet browser in any country)
echo   [3] EXIT
echo.
set /p CHOICE=Pick 1, 2 or 3 then ENTER: 
if "%CHOICE%"=="1" goto OFFLINE
if "%CHOICE%"=="2" goto TUNNEL
if "%CHOICE%"=="3" exit /b 0
goto TOP

:OFFLINE
echo.
call "%~dp0start_offline.bat"
goto :EOF

:TUNNEL
echo.
call "%~dp0start_tunnel.bat"
goto :EOF

endlocal
