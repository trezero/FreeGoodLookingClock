@echo off
REM Double-click to uninstall the desktop clock: removes the shortcuts, the daily
REM background task, and the Edge profile, and stops the running clock + server.
REM (This folder is left in place - delete it yourself afterwards if you want.)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
echo.
pause
