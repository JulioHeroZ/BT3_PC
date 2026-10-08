@echo off
setlocal
title BT3 - Port nativo
cd /d "%~dp0Nativo\Tenkaichi3Decomp"
if not exist gamedata\.installed (
    echo Execute Preparar-BT3-Nativo.py primeiro.
    pause
    exit /b 1
)
set "BT3_DATA=%CD%\gamedata"
set "BT3_SAVES=%CD%\saves"
set "BT3_DEMO="
set "BT3_REPLAY="
set "BT3_SETTINGS="
set "BT3_GS=gpu"
set "BT3_WIDE="
set "BT3_ASPECT="
set "BT3_FPS60="
if not exist bt3_settings.txt (
    >bt3_settings.txt echo aspect_milli=1778
    >>bt3_settings.txt echo fps60=0
)
if /i "%~1"=="--self-test" (
    set "BT3_DEMO=1"
    set "BT3_GS=none"
    set "BT3_SAVES=%CD%\gamedata\.selftest"
)
Tenkaichi3Decomp.exe
exit /b %ERRORLEVEL%
