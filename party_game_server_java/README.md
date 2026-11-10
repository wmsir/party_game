# 聚会桌游吧 · 后端实时联机与社交微服务 (`party_game_server_java`)

基于 **Spring Boot 3.1.5 + Java 17 + WebSocket + Spring Data JPA + MySQL 8.0** 构建的聚会桌游实时房间对决、社交广场、好友私信与商业化商城后端微服务（默认监听端口：`9001`）。

## 核心功能模块

- **WebSocket 实时房间与游戏状态同步 (`GameWebSocketHandler`)**：支持大话骰、谁是牛头王、谁是卧底、聚会大冒险转盘多席位实时同步与全屏互动道具投掷广播。
- **用户认证与游客转正体系 (`AuthController` / `UserService`)**：支持手机号验证码、账号密码登录与免密游客模式（Guest Mode）一键绑定转正。
- **社交关系与潮友圈 (`FriendController` / `RoomAndMomentController` / `IntimacyController`)**：支持世界公频、同城酒馆、1对1私信房间邀约、亲密度等级与高光动态广场。
- **装扮商城与排行榜 (`ShopController` / `RankController`)**：支持骰盅皮肤、头像框装扮购买佩戴与全服胜率/金币排行榜。
- **Web 在线畅玩与管理后台 (`WebPlayController` / `AdminController`)**：内置静态管理台与在线健康检查端点（`/health`）。

## 本地开发与构建

```bash
# 本地开发模式运行 (默认端口 9001)
mvn spring-boot:run

# 编译打包可执行 JAR
mvn clean package -DskipTests

# 运行打包后的 JAR
java -jar target/party-game-server-1.0.0.jar --server.port=9001
```
