@echo off
rem Run the test suite: import global classes first, then run the headless tests.
rem Usage:
rem   tools\test.cmd
rem   tools\test.cmd D:\path\to\Godot_v4.7.2-stable_win64_console.exe
rem
rem New scripts with class_name must be imported before running, otherwise
rem the runtime cannot resolve the global type.

setlocal
set "GODOT=%~1"
if "%GODOT%"=="" set "GODOT=godot"
set "ROOT=%~dp0.."

echo == import ==
"%GODOT%" --headless --path "%ROOT%" --import
if errorlevel 1 exit /b %ERRORLEVEL%

echo == tests ==
"%GODOT%" --headless --audio-driver Dummy --path "%ROOT%" res://Code/Tests/TestRunner.tscn
exit /b %ERRORLEVEL%
