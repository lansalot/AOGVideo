@echo off
cd /d %~dp0
echo You have connected to wifi, haven't you??? Do it now if not
pause

powershell -executionpolicy bypass -file RustDesk.ps1
pause
regedit -s "%~dp0RustDesk.reg"