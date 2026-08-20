@echo off
REM Pati - scheduled sync runner
REM Backend A (DB) - runs sync_foodsafety.py and logs output

chcp 65001 >nul

cd /d "%~dp0.."

if not exist "DB\sync_logs" mkdir "DB\sync_logs"

for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set TIMESTAMP=%%i

set LOGFILE=DB\sync_logs\sync_%TIMESTAMP%.log

echo Sync started: %TIMESTAMP% > "%LOGFILE%"

python DB\sync_foodsafety.py >> "%LOGFILE%" 2>&1

echo Sync finished >> "%LOGFILE%"
