@echo off
setlocal

echo ==========================================
echo   Android Battery Check
echo ==========================================
echo.

set "URL=https://github.com/hiroki147/Android-Check-Battery/raw/refs/heads/main/check_battery.ps1"
set "SCRIPT=%TEMP%\check_battery.ps1"

echo [1/2] 最新版をダウンロードしています...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Invoke-WebRequest -Uri '%URL%' -OutFile '%SCRIPT%'"

if errorlevel 1 (
echo.
echo [ERROR] ダウンロードに失敗しました。
pause
exit /b 1
)

echo [2/2] Battery Checkerを起動しています...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

echo.
echo ==========================================
echo 終了しました。
echo ==========================================
pause
