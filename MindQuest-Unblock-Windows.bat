@echo off
:: MindQuest Anti-Gravity YouTube Unblock for Windows
title MindQuest DNS Shield (YouTube Unblock)

net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~0' -Verb RunAs"
    exit /b
)

set HOSTS=%windir%\System32\drivers\etc\hosts

:: Remove block entries
powershell -Command "(Get-Content '%HOSTS%') -notmatch 'youtube|googlevideo|ytimg|MindQuest' | Set-Content '%HOSTS%'"

:: Flush Windows DNS Cache
ipconfig /flushdns >nul

echo.
echo ====================================================
echo   [SUCCESS] YouTube access is now UNLOCKED!
echo ====================================================
echo.
pause
