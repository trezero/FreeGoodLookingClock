@echo off
REM Serves the clock at http://localhost:8080/ and opens it in your main Edge.
REM Useful for installing it as a PWA or quick testing. For everyday use, just
REM use the desktop "Clock" shortcut (created by install.bat).
cd /d "%~dp0"
start "" cmd /c "ping -n 2 127.0.0.1 >nul & start """" msedge http://localhost:8080/"
echo Serving the clock at http://localhost:8080/
echo Keep this window open while you use the clock. Close it to stop.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
