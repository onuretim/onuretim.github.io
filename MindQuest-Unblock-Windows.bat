@echo off
:: MindQuest Instant Distraction Unblock for Windows
title MindQuest DNS Shield (Instant Unblock)

net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~0' -Verb RunAs"
    exit /b
)

set HOSTS=%windir%\System32\drivers\etc\hosts

:: Remove all MindQuest block entries and distraction domains
powershell -Command "(Get-Content '%HOSTS%') -notmatch 'MindQuest|youtube|tiktok|instagram|reddit|pornhub|xvideos|stake|roobet|shein|temu|dailymail|9gag|steampowered|roblox|googlevideo|ytimg' | Set-Content '%HOSTS%'"

:: Flush Windows DNS Cache
ipconfig /flushdns >nul

echo.
echo ====================================================
echo   [SUCCESS] All websites are now completely UNLOCKED!
echo   DNS cache flushed. You can now browse freely.
echo ====================================================
echo.
pause
