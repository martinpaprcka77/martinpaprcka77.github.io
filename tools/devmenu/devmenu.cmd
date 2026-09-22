@echo off
rem Launches the Reasonix dev menu without PowerShell execution-policy friction.
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0devmenu.ps1" %*
