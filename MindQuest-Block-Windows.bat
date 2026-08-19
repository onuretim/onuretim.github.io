@echo off
:: MindQuest Anti-Gravity YouTube Block Enforcer for Windows
title MindQuest DNS Shield (YouTube Block)

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ====================================================
    echo   Requesting Administrator privileges to apply block...
    echo ====================================================
    powershell -Command "Start-Process '%~0' -Verb RunAs"
    exit /b
)

set HOSTS=%windir%\System32\drivers\etc\hosts

:: Remove old entries if present
powershell -Command "(Get-Content '%HOSTS%') -notmatch 'youtube|googlevideo|ytimg|MindQuest' | Set-Content '%HOSTS%'"

:: Append block entries
echo # --- MindQuest Block --- >> "%HOSTS%"
echo 0.0.0.0 youtube.com >> "%HOSTS%"
echo 0.0.0.0 www.youtube.com >> "%HOSTS%"
echo 0.0.0.0 m.youtube.com >> "%HOSTS%"
echo 0.0.0.0 youtu.be >> "%HOSTS%"
echo 0.0.0.0 googlevideo.com >> "%HOSTS%"
echo 0.0.0.0 ytimg.com >> "%HOSTS%"
echo 0.0.0.0 yt3.ggpht.com >> "%HOSTS%"
echo 0.0.0.0 youtubei.googleapis.com >> "%HOSTS%"
echo # --- End MindQuest Block --- >> "%HOSTS%"

:: Flush Windows DNS Cache
ipconfig /flushdns >nul

echo.
echo ====================================================
echo   [SUCCESS] YouTube is now 100%% BLOCKED on this PC!
echo ====================================================
echo.
echo Any attempt to open youtube.com will now be blocked.
echo To unlock access:
echo 1. Open https://onuretim.github.io/unlock/
echo 2. Complete your exercise repetitions!
echo.
pause
