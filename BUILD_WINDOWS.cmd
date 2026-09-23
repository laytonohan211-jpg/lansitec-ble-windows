@echo off
powershell.exe -NoProfile -File "%~dp0build_windows.ps1"
if errorlevel 1 echo Build failed. Read the error above and README_WINDOWS.md.
pause
