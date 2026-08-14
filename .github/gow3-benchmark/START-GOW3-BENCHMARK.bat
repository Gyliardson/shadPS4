@echo off
setlocal
cd /d "%~dp0"
if "%~1"=="" (
  echo Usage: START-GOW3-BENCHMARK.bat "C:\path\to\game\eboot.bin"
  exit /b 2
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0START-GOW3-BENCHMARK.ps1" -EbootPath "%~1"
exit /b %ERRORLEVEL%
