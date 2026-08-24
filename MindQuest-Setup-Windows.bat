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

:: Downloaded to a staging path, NOT to the install directory.
:: Downloading straight to C:\ProgramData\MindQuest\mindquest-agent.ps1
:: meant -Install was asked to copy that file onto itself, which
:: Copy-Item refuses - so the scheduled task was never registered and
:: this script printed its closing instructions for an install that had
:: not happened.
set "STAGE=%TEMP%\mindquest-agent.ps1"
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
echo   Downloading the agent...
echo   It will be installed to:
echo     %AGENT%
echo   You can open that file and read it at any time.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Invoke-WebRequest -Uri '%SRC%' -OutFile '%STAGE%' -UseBasicParsing"

if not exist "%STAGE%" (
    echo   Download failed. Check your internet connection and try again.
    echo   Nothing on this PC was changed.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%STAGE%" -Install -ConfigId "%CONFIGID%"

:: Report what actually happened. The previous version printed its closing
:: instructions unconditionally, so a failed install read exactly like a
:: successful one.
if errorlevel 1 (
    echo.
    echo   INSTALL FAILED - see the error above. Nothing is being blocked.
    echo   Your hosts file and DNS settings were not changed.
    echo.
    pause
    exit /b 1
)

echo.
echo   To remove MindQuest completely at any time, run:
echo     powershell -ExecutionPolicy Bypass -File "%AGENT%" -Uninstall
echo.
pause
