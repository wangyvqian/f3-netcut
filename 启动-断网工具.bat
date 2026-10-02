@echo off
rem 双击启动，自动请求管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
title F3 快速断网工具
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0f3-netcut.ps1"
pause
