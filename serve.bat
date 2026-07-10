@echo off
REM Inicia el servidor de Rojo usando el ejecutable local en bin\rojo.exe
cd /d "%~dp0"
"%~dp0bin\rojo.exe" serve default.project.json
pause
