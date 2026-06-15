@echo off
REM Launches the clock in a chromeless Edge "app" window (no tabs / address bar).
cd /d "%~dp0"
REM Open the app window a second later (gives the server time to start).
start "" cmd /c "ping -n 2 127.0.0.1 >nul & start """" msedge --app=http://localhost:8080/ --window-size=900,540"
echo Serving the clock at http://localhost:8080/
echo Keep this window open while you use the clock. Close it to stop.
python -m http.server 8080
