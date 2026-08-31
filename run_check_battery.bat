@echo off
setlocal

set "URL=https://github.com/hiroki147/Android-Check-Battery/raw/refs/heads/main/check_battery.ps1"
set "SCRIPT=%TEMP%\check_battery.ps1"

echo ==========================================
echo   Android Battery Check
echo ==========================================
echo.
echo Downloading latest version...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Invoke-WebRequest -Uri '%URL%' -OutFile '%SCRIPT%'"

if errorlevel 1 (
echo.
echo ERROR: Download failed.
pause
exit /b 1
)

echo Starting Battery Checker...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

echo.
echo Finished.
pause
