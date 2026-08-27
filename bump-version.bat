@echo off
setlocal
cd /d "%~dp0"

echo ========================================
echo   Check-in App Version Manager
echo ========================================
echo.
echo  1. Build +1
echo  2. Patch +1
echo  3. Minor +1
echo  4. Major +1
echo.
set /p "choice=Select [1-4]: "

if "%choice%"=="1" goto build
if "%choice%"=="2" goto patch
if "%choice%"=="3" goto minor
if "%choice%"=="4" goto major
echo Invalid choice. No changes were made.
goto end

:build
call dart run tool/build.dart bump
goto end

:patch
call dart run tool/build.dart bump --patch
goto end

:minor
call dart run tool/build.dart bump --minor
goto end

:major
call dart run tool/build.dart bump --major

:end
echo.
pause
endlocal
