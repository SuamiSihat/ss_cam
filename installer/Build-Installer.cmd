@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-Installer.ps1" %*
if errorlevel 1 (
    echo.
    echo Build failed. Review the message above.
    pause
)
