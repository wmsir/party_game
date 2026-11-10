@echo off
chcp 65001 >nul
title 聚会桌游吧 (PartyGame Club) - 后端远程自动化部署
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT_DIR=%%~fI"

cd /d "%ROOT_DIR%\party_game_server_java"
where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python "%ROOT_DIR%\party_game_server_java\deploy_java_server.py"
) else (
    call mvn clean package -DskipTests
)
pause
