@echo off
setlocal EnableExtensions

rem RunTests.cmd - entry point for the FindUtf16 self-test.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0RunTests.ps1"
exit /b %errorlevel%
