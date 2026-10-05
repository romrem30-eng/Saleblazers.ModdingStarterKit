@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
title Saleblazers ModLoader Installer

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; & '.\install.ps1'"
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Installation failed.
)
echo.
pause
