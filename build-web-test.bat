@echo off
setlocal
cd /d "%~dp0"
if not exist "tool\web-deploy.local.ps1" (
  echo Missing tool\web-deploy.local.ps1. Copy tool\web-deploy.example.ps1 and fill in server details.
  pause
  exit /b 1
)
echo ========================================
echo   Build Check-in Web - TEST
echo ========================================
call flutter build web --release --dart-define=ENV=test --base-href "/apptest/checkin/"
if errorlevel 1 (
  echo Web test build failed.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "tool\stage-web-build.ps1" -Environment test
if errorlevel 1 (
  echo Web test package is incomplete.
  pause
  exit /b 1
)
echo.
echo Build complete: build/web-test
powershell -NoProfile -ExecutionPolicy Bypass -File "tool\deploy-web.ps1" -Environment test
if errorlevel 1 (
  echo Web test deployment failed.
  pause
  exit /b 1
)
pause
endlocal
