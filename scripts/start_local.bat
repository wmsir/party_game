@echo off
chcp 65001 >nul
title 聚会桌游吧 (PartyGame Club) - 本地联调启动器
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT_DIR=%%~fI"

echo ================================================================
echo   [1/2] 启动本地聚会桌游 Java 生产微服务 (端口 9001)...
echo ================================================================
start "PartyGame-Server-9001" cmd /k "chcp 65001 >nul && cd /d "%ROOT_DIR%\party_game_server_java" && mvn spring-boot:run"

timeout /t 3 >nul

echo ================================================================
echo   [2/2] 启动聚会桌游跨平台客户端 (PartyGameApp)...
echo ================================================================
cd /d "%ROOT_DIR%\party_game_app"
flutter run -d windows
pause
