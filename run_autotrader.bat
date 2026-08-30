@echo off
title AutoTrader AI - Autonomous Trading System
color 0A
cls

echo ===============================================================================
echo   AUTOTRADER AI: AUTONOMOUS HALAL ALGORITHMIC TRADING SYSTEM
echo   100% Shariah Compliant (AAOIFI Standard) ^| 2-Position Alpha Compounding
echo ===============================================================================
echo.

:: Check for virtual environment
if not exist ".venv" (
    echo [1/3] Creating Python Virtual Environment...
    python -m venv .venv
    if %errorlevel% neq 0 (
        echo [ERROR] Python is not installed or not added to PATH.
        echo Please install Python 3.10+ from python.org and check 'Add to PATH'.
        pause
        exit /b 1
    )
)

:: Activate virtual environment
call .venv\Scripts\activate

:: Check dependencies
echo [2/3] Checking dependencies...
python -m pip install -q -r requirements.txt

:: Launch AutoTrader Master Menu
echo [3/3] Starting AutoTrader AI Engine...
echo.
python start_bot.py

pause
