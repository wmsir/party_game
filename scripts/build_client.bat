@echo off
chcp 65001 >nul
title 聚会桌游吧 (PartyGame Club) - 多平台客户端构建工具
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT_DIR=%%~fI"

if exist "C:\src\flutter\bin" set "PATH=C:\src\flutter\bin;%PATH%"

where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python "%ROOT_DIR%\party_game_app\scripts\build_app.py" %*
) else (
    echo [错误] 未检测到 Python 环境，请安装 Python 3.x 并加入 PATH。
    pause
    exit /b 1
)
