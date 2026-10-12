@echo off
setlocal
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL%" (
  >&2 echo windows-isolated-display: Windows PowerShell 5 is required
  exit /b 2
)
"%POWERSHELL%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0windows_isolated_display.ps1" %*
exit /b %ERRORLEVEL%
