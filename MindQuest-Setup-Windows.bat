@echo off
:: MindQuest Windows installer.
::
:: Replaces MindQuest-Agent-Setup.bat, which piped a remote script straight
:: into PowerShell as Administrator (`irm ... | iex`). That is a bad habit
:: to teach anyone, and the script it fetched blocked everything with no
:: way to unblock. This downloads the agent to a file you can read before
:: it runs, and tells you where that file is.
setlocal

title MindQuest Setup

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo   MindQuest needs Administrator, because blocking works by editing
    echo   the system hosts file. Re-launching with elevation...
    echo.
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cls
echo =========================================================
echo    MindQuest - earn your screen time
echo =========================================================
echo.

set "AGENT=%ProgramData%\MindQuest\mindquest-agent.ps1"
set "SRC=https://onuretim.github.io/mindquest-agent.ps1"

if "%~1"=="" (
    echo   Your Config ID is on the Unlock page:
    echo     https://onuretim.github.io/unlock/
    echo.
    set /p CONFIGID="  Paste your Config ID (mq-xxxxxx): "
) else (
    set "CONFIGID=%~1"
)

if "%CONFIGID%"=="" (
    echo.
    echo   No Config ID entered. Nothing was installed or changed.
    echo.
    pause
    exit /b 1
)

echo.
echo   Downloading the agent to:
echo     %AGENT%
echo   You can open that file and read it before or after installing.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "New-Item -ItemType Directory -Path (Split-Path '%AGENT%') -Force | Out-Null; Invoke-WebRequest -Uri '%SRC%' -OutFile '%AGENT%' -UseBasicParsing"

if not exist "%AGENT%" (
    echo   Download failed. Check your internet connection and try again.
    echo   Nothing on this PC was changed.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%AGENT%" -Install -ConfigId "%CONFIGID%"

echo.
echo   To remove MindQuest completely at any time, run:
echo     powershell -ExecutionPolicy Bypass -File "%AGENT%" -Uninstall
echo.
pause
