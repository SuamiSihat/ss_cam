@echo off
start "" powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0src\Install-SuamiSihat-WPF.ps1"
