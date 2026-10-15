@echo off
setlocal EnableExtensions

rem FindUtf16.cmd - find (and optionally convert) UTF-16 encoded files.
rem Scans the current folder by default; use --path to scan another folder.

if "%~1"=="" goto Help

set "MODE="
if /i "%~1"=="--list" set "MODE=list"
if /i "%~1"=="--fix"  set "MODE=fix"
if not defined MODE goto UnknownMode

set "ROOT=."
if not "%~2"=="" (
    if /i not "%~2"=="--path" goto UnknownPath
    if "%~3"=="" goto NoPath
    set "ROOT=%~3"
)

goto Run

:Help
call :Usage
exit /b 0

:UnknownMode
echo Unknown mode: %~1
echo.
call :Usage
exit /b 1

:UnknownPath
echo Unknown option: %~2
echo.
call :Usage
exit /b 1

:NoPath
echo Missing folder after --path.
echo.
call :Usage
exit /b 1

:Usage
echo Usage:
echo   FindUtf16.cmd --list [--path ^<folder^>]   List UTF-16 files.
echo   FindUtf16.cmd --fix  [--path ^<folder^>]   Convert UTF-16 files to UTF-8 (without BOM).
echo.
echo Without --path the current folder is scanned.
echo Excluded folders: .git, $tf, .vs, bin, obj.
echo Paths are printed relative to the scan root.
exit /b 0

:Run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0FindUtf16.ps1" %MODE% -Root "%ROOT%"
exit /b %errorlevel%
