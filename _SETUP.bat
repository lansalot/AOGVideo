@echo off
cd /d %~dp0
echo You have connected to wifi, haven't you??? Do it now if not
pause

powershell -executionpolicy bypass -file Set-AOGCustomisation.ps1
pause