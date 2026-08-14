@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CREATE-GOW3-BENCHMARK-SNAPSHOT.ps1" %*
exit /b %ERRORLEVEL%
