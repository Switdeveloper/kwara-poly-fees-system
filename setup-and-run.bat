@echo off
title Kwara Poly Fees System - Setup
color 0A
echo.
echo  ========================================
echo     KWARA POLY FEES SYSTEM - SETUP
echo  ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python is not installed!
    echo Please install Python 3 from: https://python.org/downloads
    echo Then run this file again.
    pause
    exit
)

echo [OK] Python found
python --version

REM Install Python dependencies
echo.
echo [1/3] Installing Python packages...
pip install flask qrcode[pil] pyzbar --quiet
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install packages. Try running as Administrator.
    pause
    exit
)
echo [OK] Packages installed

REM Check for zbar
echo.
echo [2/3] Checking QR scanner (zbar)...
where zbarimg >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] zbar not found. Installing...
    echo.
    echo IMPORTANT: If the installer doesn't open automatically:
    echo 1. Go to: https://sourceforge.net/projects/zbar/files/zbar/0.10/zbar-0.10.exe/download
    echo 2. Download and install it
    echo 3. Then run this file again
    echo.
    start https://sourceforge.net/projects/zbar/files/zbar/0.10/zbar-0.10.exe/download
    echo Press any key after installing zbar...
    pause
)
echo [OK] QR scanner ready

REM Run the app
echo.
echo [3/3] Starting the app...
echo.
echo Login credentials:
echo    Username: admin
echo    Password: admin123
echo.
echo Opening http://localhost:5000 in your browser...
echo.
cd /d "%~dp0"
python app.py