@echo off
:: MindQuest NextDNS-Style Windows Agent Launcher
title MindQuest Client Agent Setup

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo =========================================================
    echo   Requesting Administrator privileges to run MindQuest...
    echo =========================================================
    powershell Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs
    exit /b
)

cls
echo =========================================================
echo       🚀 MindQuest NextDNS-Style Client Agent Setup      
echo =========================================================
echo.
echo Launching MindQuest DNS Enforcer...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://onuretim.github.io/mindquest.ps1 | iex"

pause
