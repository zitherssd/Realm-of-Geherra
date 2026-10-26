@echo off
setlocal EnableDelayedExpansion

"C:\Program Files\Love\love.exe" "D:\Projects\Realm-of-Geherra\tests\unit\main.lua"

exit /b %ERRORLEVEL%
