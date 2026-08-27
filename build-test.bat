@echo off
setlocal
cd /d "%~dp0"
if exist "tool\oss-credentials.local.bat" call "tool\oss-credentials.local.bat"
echo ========================================
echo   Publish Check-in App - TEST
echo ========================================
call dart run tool/build.dart test
echo.
pause
endlocal
