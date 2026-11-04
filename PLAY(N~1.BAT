@echo off
rem Re-rolls the randomiser with the mod menu's saved choices and a new seed, then starts Dying Light
rem through Steam. (Don't use this as well as the Steam launch option, or it rolls twice.)
echo Re-rolling the randomiser...
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Randomiser Menu.ps1" -Launch
