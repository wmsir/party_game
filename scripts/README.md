# 聚会桌游吧 (PartyGame Club) 运维与构建脚本 (`scripts/`)

| 脚本名称 | 用途说明 |
| :--- | :--- |
| [`build_client.bat`](build_client.bat) | 调用 [`../party_game_app/scripts/build_app.py`](../party_game_app/scripts/build_app.py) 提供交互式/命令行多端构建（Android APK/AAB、HarmonyOS Next HAP、iOS IPA、Web H5） |
| [`start_local.bat`](start_local.bat) | 本地一键并行启动 Java 后端微服务（`9001` 端口）与 Flutter 客户端 |
| [`deploy_server.bat`](deploy_server.bat) | 一键打包并远程发布 Java 后端微服务 |
