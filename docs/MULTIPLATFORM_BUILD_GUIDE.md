# 聚会桌游吧 (PartyGame Club) 全平台编译与签名发布指南 (iOS / Android / 鸿蒙 / Windows / Web)

本文档介绍如何通过 **GitHub Actions 云端流水线** 或 **本地开发环境** 编译打包 Android、iOS、鸿蒙 (HarmonyOS Next / OpenHarmony)、Windows 与 Web 端应用。

---

## 一、 GitHub Actions 云端一键编译（推荐）

本项目已配置好 [`.github/workflows/build-multiplatform.yml`](../.github/workflows/build-multiplatform.yml) 自动化构建工作流。

### 1. 触发方式
- **自动触发**：向 `main` 分支推送代码，或推送 `v*` 版本标签（如 `git tag v1.0.56 && git push origin v1.0.56`）。
- **手动触发**：进入 GitHub 仓库顶部的 **Actions** 页签 ➔ 选择左侧 **Build Multi-Platform Apps (Android, iOS, HarmonyOS, Web, Windows & Server)** ➔ 点击右侧 **Run workflow** 按钮。

### 2. 获取编译产物
编译完成后（约 5–8 分钟），可通过以下两种方式下载全平台安装包：
1. **GitHub Releases 页面**：自动创建或更新对应版本的 Release，包含 `.apk`、`.aab`、`.ipa`、`.hap`、`-harmonyos-deveco-project.zip`、`-windows-x64.zip`、`-web-h5.zip`、后端 `.jar` 及 `SHA256SUMS.txt` 校验文件。
2. **Actions 构建详情页底部 Artifacts**：可按平台单独下载对应构建产物。

---

## 二、 各平台安装包使用与重签名指南

### 1. Android (`.apk` / `.aab`)
- `party-game-v1.0.56-android-universal.apk`：已使用默认签名打包，可直接传输至任意 Android 手机安装运行。
- `party-game-v1.0.56-android-bundle.aab`：用于上传至 Google Play Console 发布。

### 2. iOS (`.ipa`)
GitHub Actions 在 `macos-latest` 云端 Mac 主机上使用 Xcode 编译生成未签名 `party-game-v1.0.56-ios-unsigned.ipa`，支持以下安装方式：
- **个人免费 Apple ID 自签安装**：使用 **AltStore** 或 **Sideloadly** 导入 `.ipa` 文件并输入 Apple ID 即可直接安装至 iPhone / iPad。
- **TrollStore 永久安装**：支持巨魔商店的设备可直接导入 `.ipa` 安装。
- **企业证书 / Ad-Hoc 重签名**：使用 `fastlane sigh resign` 或 iOS App Signer 注入 `.mobileprovision` 与企业证书后分发。

### 3. 鸿蒙 HarmonyOS Next / OpenHarmony (`.hap`)
云端流水线同时产出两份鸿蒙构建产物：
1. **`party-game-v1.0.56-harmonyos-unsigned.hap`**：
   - 已注入编译后的 `flutter_assets` 全量资源与 Stage 模型配置（`com.fwpt.partygame`）；
   - 可使用华为 OpenHarmony SDK 自带的 `hap-sign-tool.jar` 进行命令行证书签名后，通过 `hdc install` 安装至鸿蒙真机。
2. **`party-game-v1.0.56-harmonyos-deveco-project.zip`**：
   - 解压后直接用华为 **DevEco Studio 5.0+** 打开 `ohos` 目录；
   - 由于云端已将 Flutter 游戏资源预先编译并嵌入 `ohos/entry/src/main/resources/rawfile/flutter_assets/`，**本地无需配置 Flutter 环境**；
   - 进入 `File -> Project Structure -> Signing Configs` 勾选 **Automatically generate signature** 登录华为开发者账号自动签名，点击右上角 **Run** 即可一键安装至鸿蒙 Next 真机或模拟器。
