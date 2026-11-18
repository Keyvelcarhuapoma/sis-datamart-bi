@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -File "%~dp0Inicializar.ps1" -Servidor localhost
if errorlevel 1 exit /b 1
echo Estructura creada. Sigue README.md para cargar los ejemplos.
pause
