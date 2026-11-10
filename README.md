# 🎲 聚会桌游吧 (PartyGame Club) —— 跨平台实时联机聚会桌游与互动社交平台

> **当前版本**：`v1.0.56`  
> **支持终端**：Android (`.apk` / `.aab`) · iOS (`.ipa`) · 鸿蒙 HarmonyOS Next / OpenHarmony (`.hap`) · Windows (`.exe`) · Web (`H5`)  
> **后端架构**：Spring Boot 3 + WebSocket + JPA + MySQL 8.0 (`9001` 端口)

---

## 📌 项目简介

**聚会桌游吧 (PartyGame Club)** 是一套完整的跨平台多人互动聚会娱乐系统，包含 **Flutter 全平台客户端 (`party_game_app`)** 与 **Java 实时联机微服务 (`party_game_server_java`)**。支持一部手机同屏轮流畅玩（Pass & Play 隐私遮挡模式）以及多端跨网 WebSocket 房间实时联机对决。

---

## 🗂️ 标准工程目录结构

```text
party_game/
├── .github/
│   └── workflows/
│       └── build-multiplatform.yml # 🚀 GitHub Actions 全平台云端自动编译与 Release 发布流水线
├── party_game_app/                 # 📱 跨平台客户端工程 (Flutter 3.27 + Dart 3.6)
│   ├── lib/                        #    游戏矩阵、WebSocket 联机、社交广场、潮友圈与商城核心源码
│   ├── android/                    #    Android 原生宿主工程 (APK / Google Play AAB)
│   ├── ios/                        #    iOS 原生宿主工程 (Xcode Runner / IPA)
│   ├── ohos/                       #    鸿蒙 HarmonyOS Next / OpenHarmony Stage 模型 ArkTS 原生宿主工程
│   ├── windows/                    #    Windows 桌面端宿主工程
│   ├── macos/                      #    macOS 桌面端宿主工程
│   ├── linux/                      #    Linux 桌面端宿主工程
│   ├── web/                        #    Web H5 宿主工程
│   └── scripts/build_app.py        #    多平台本地自动化打包脚本
├── party_game_server_java/         # ☕ Java 实时联机与社交后端微服务 (Spring Boot 3.1.5 + WebSocket)
│   ├── src/main/java/com/partygame/#    WebSocket 房间同步、好友私信、亲密度、动态广场、装扮商城与排行榜
│   ├── Dockerfile                  #    后端容器镜像构建定义
│   ├── docker-compose.yml          #    后端服务容器编排配置
│   └── pom.xml                     #    Maven 依赖配置
├── scripts/                        # 🛠️ 本地开发联调与多端打包快捷脚本
│   ├── build_client.bat            #    Windows 本地多平台客户端构建入口
│   ├── start_local.bat             #    Windows 本地一键同时启动后端微服务与客户端
│   └── deploy_server.bat           #    一键打包并远程部署后端微服务
├── docs/                           # 📚 架构与跨平台构建指南
│   └── MULTIPLATFORM_BUILD_GUIDE.md#    GitHub Actions 云端与本地编译 iOS / Android / 鸿蒙详细指南
├── .gitignore                      # Git 忽略规则
└── README.md                       # 项目总览文档
```

---

## 🎮 核心游戏矩阵与社交特性

1. **🎲 大话骰 (Liar's Dice)**：3D 拟真摇盅、传感器摇一摇碰撞震动反馈、叫点/劈骰/报斋/反斋智能裁决、多性格 AI 陪玩与同屏盲盒遮挡模式。
2. **🐮 谁是牛头王 (Take 6 / 6 Nimmt!)**：1–104 号牛头卡牌策略博弈、4 排自动比牌放置动画、第 6 张爆排吃牌惩罚与 6 位房间码联机。
3. **🎡 聚会大冒险转盘 (Party Wheel)**：阻尼旋转物理指针、真心话/大冒险随机题库与自定义概率权重。
4. **🕵️ 谁是卧底 (Undercover)**：自动词对分发、暗查底牌、轮流发言记录与无记名投票放逐结算。
5. **💬 实时社交与全屏道具投掷**：世界公频、同城酒馆、好友 1对1 私信发房邀约、全屏抛物线投掷（臭鸡蛋、碰啤酒、送鲜花、拍拖鞋、大炸弹）及潮友圈动态广场。

---

## ☁️ GitHub Actions 云端全平台自动编译

仓库内置 [`.github/workflows/build-multiplatform.yml`](.github/workflows/build-multiplatform.yml) 持续集成流水线，每次推送代码至 `main` 分支、推送 `v*` 标签或在 GitHub 页面手动点击 **Run workflow** 时，云端将自动并行编译并产出全平台安装包至 **GitHub Actions Artifacts** 与 **GitHub Releases**：

| 目标系统 | 云端编译环境 | 输出产物名称 | 说明 |
| :--- | :--- | :--- | :--- |
| **Android** | `ubuntu-latest` | `party-game-v1.0.56-android-universal.apk`<br>`party-game-v1.0.56-android-bundle.aab` | 通用全架构安装包与 Google Play 上架包 |
| **iOS** | `macos-latest` | `party-game-v1.0.56-ios-unsigned.ipa` | 原生编译 IPA 包（支持 AltStore / Sideloadly / TrollStore / 企业重签） |
| **HarmonyOS Next (鸿蒙)** | `ubuntu-latest` | `party-game-v1.0.56-harmonyos-unsigned.hap`<br>`party-game-v1.0.56-harmonyos-deveco-project.zip` | 标准 Stage 模型 `.hap` 包与内嵌编译产物的 DevEco Studio 工程包 |
| **Windows** | `windows-latest` | `party-game-v1.0.56-windows-x64.zip` | Windows 64 位桌面端免安装运行包 |
| **Web (H5)** | `ubuntu-latest` | `party-game-v1.0.56-web-h5.zip` | 静态 H5 网页包（可直接部署至 Nginx） |
| **Java 后端** | `ubuntu-latest` | `party-game-server-1.0.0.jar` | Spring Boot 3 实时联机服务端可执行 JAR |

> 📘 详细云端触发方式、iOS 签名与鸿蒙 DevEco Studio 签名指南请参阅 [`docs/MULTIPLATFORM_BUILD_GUIDE.md`](docs/MULTIPLATFORM_BUILD_GUIDE.md)。

---

## 🚀 本地快速启动与打包

### 1. 本地一键联调（后端 9001 + 客户端）
```bat
scripts\start_local.bat
```

### 2. 本地多平台打包客户端
```bat
scripts\build_client.bat
```

### 3. 单独启动后端服务
```bash
cd party_game_server_java
mvn spring-boot:run
```

---

## 📚 模块文档导航

- 📱 [跨平台客户端模块说明 (`party_game_app/README.md`)](party_game_app/README.md)
- ☕ [Java 实时联机服务端说明 (`party_game_server_java/README.md`)](party_game_server_java/README.md)
- 🛠️ [云端与本地全平台编译及签名手册 (`docs/MULTIPLATFORM_BUILD_GUIDE.md`)](docs/MULTIPLATFORM_BUILD_GUIDE.md)
- 📜 [运维与打包脚本说明 (`scripts/README.md`)](scripts/README.md)
