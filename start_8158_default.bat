@echo off
cd /d "%~dp0"

docker compose up -d --wait
if errorlevel 1 (
    echo Baza danych nie wystartowala - przerywam ^(FXServer bez bazy nie zaladuje graczy^).
    pause
    exit /b 1
)

python "%~dp0txData\resources\[addon]\generate_vehicle_resources.py"
if errorlevel 1 (
    echo Failed to generate vehicle resources.
    pause
    exit /b 1
)
"D:/game/FiveM/local4Word6/artifact/FXServer.exe" +set serverProfile "default"
pause
