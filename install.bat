@echo off
REM Double-click to install the desktop clock. Walks you through a couple of
REM quick questions, then creates the shortcut, startup entry, and daily refresh.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
