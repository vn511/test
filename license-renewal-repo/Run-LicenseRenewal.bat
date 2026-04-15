@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%license_renewal.ps1"
set "CONFIG_FILE=%SCRIPT_DIR%config.json"
set "MACHINE_NAME=%~1"

if not "%~2"=="" (
    set "CONFIG_FILE=%~2"
)

if not exist "%PS_SCRIPT%" (
    echo [ERROR] Could not find license_renewal.ps1 in:
    echo         %SCRIPT_DIR%
    pause
    exit /b 1
)

if not exist "%CONFIG_FILE%" (
    echo [ERROR] Could not find config file:
    echo         %CONFIG_FILE%
    echo.
    echo Create config.json from config.example.json and update values first.
    pause
    exit /b 1
)

if "%MACHINE_NAME%"=="" (
    set /p MACHINE_NAME=Enter the machine name for the license renewal target: 
)

if "%MACHINE_NAME%"=="" (
    echo [ERROR] Machine name is required.
    pause
    exit /b 1
)

echo.
echo Running license renewal for machine: %MACHINE_NAME%
echo Using config file: %CONFIG_FILE%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -ConfigFile "%CONFIG_FILE%" -MachineName "%MACHINE_NAME%"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo License renewal completed successfully.
) else (
    echo License renewal failed with exit code %EXIT_CODE%.
)

pause
exit /b %EXIT_CODE%
