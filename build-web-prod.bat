@echo off
setlocal
cd /d "%~dp0"
if not exist "tool\web-deploy.local.ps1" (
  echo Missing tool\web-deploy.local.ps1. Copy tool\web-deploy.example.ps1 and fill in server details.
  pause
  exit /b 1
)
echo ========================================
echo   Build Check-in Web - PRODUCTION
echo ========================================
call flutter build web --release --dart-define=ENV=prod --base-href "/app/checkin/"
if errorlevel 1 (
  echo Web production build failed.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "tool\stage-web-build.ps1" -Environment prod
if errorlevel 1 (
  echo Web production package is incomplete.
  pause
  exit /b 1
)
echo.
echo Build complete: build/web-prod
powershell -NoProfile -ExecutionPolicy Bypass -File "tool\deploy-web.ps1" -Environment prod
if errorlevel 1 (
  echo Web production deployment failed.
  pause
  exit /b 1
)
pause
endlocal
