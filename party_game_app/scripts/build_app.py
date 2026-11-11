# -*- coding: utf-8 -*-
"""
================================================================================
聚会桌游跨平台客户端 (party_game_app) - 多端一键编译打包引擎
================================================================================
支持平台：
  [1] 安卓 (Android APK / AAB) - 支持独立只打包安卓
  [2] 鸿蒙 (HarmonyOS Next / OpenHarmony HAP)
  [3] 苹果 (iOS Xcode Archive)
  [4] Web (CanvasKit / H5 静态资源)
  [5] 全平台一键全量构建
================================================================================
"""

import os
import sys
import time
import shutil
import subprocess
import argparse

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stdin, 'reconfigure'):
    sys.stdin.reconfigure(encoding='utf-8', errors='replace')

APP_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
ROOT_DIR = os.path.abspath(os.path.join(APP_DIR, '..'))  # 统一聚合目录 C:\project\fwpt\party_game
DIST_DIR = os.path.join(ROOT_DIR, 'dist')

# 确保 Flutter SDK 路径在环境变量中
flutter_bin = r"C:\src\flutter\bin"
if os.path.exists(flutter_bin) and flutter_bin not in os.environ.get("PATH", ""):
    os.environ["PATH"] = flutter_bin + os.pathsep + os.environ.get("PATH", "")

def log(msg, color="92"):
    print(f"[\033[{color}mPARTY-BUILD\033[0m] {msg}")

def ensure_dist_dir():
    os.makedirs(DIST_DIR, exist_ok=True)

def run_cmd(cmd, cwd=APP_DIR):
    log(f"执行命令: {cmd}")
    res = subprocess.run(cmd, shell=True, cwd=cwd)
    return res.returncode == 0

import re
import datetime

GLOBAL_DIST_APPS = os.path.abspath(os.path.join(ROOT_DIR, '..', 'dist_apps'))

def bump_version_and_save():
    """每次构建自动将版本号 +0.0.1，并刷新 app_version.dart 与 local.properties"""
    pubspec_path = os.path.join(APP_DIR, 'pubspec.yaml')
    if not os.path.exists(pubspec_path):
        return "1.0.54"

    with open(pubspec_path, 'r', encoding='utf-8') as f:
        content = f.read()

    m = re.search(r'version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?', content)
    if not m:
        return "1.0.54"

    major, minor, patch = int(m.group(1)), int(m.group(2)), int(m.group(3))
    new_patch = patch + 1
    new_version = f"{major}.{minor}.{new_patch}"
    now = datetime.datetime.now()
    new_build_number = int(now.strftime('%m%d%H%M'))

    new_yaml = re.sub(
        r'version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?',
        f'version: {new_version}+{new_build_number}',
        content,
        count=1
    )
    with open(pubspec_path, 'w', encoding='utf-8') as f:
        f.write(new_yaml)

    # 同步更新 lib/core/constants/app_version.dart
    app_version_dart = os.path.join(APP_DIR, 'lib', 'core', 'constants', 'app_version.dart')
    if os.path.exists(app_version_dart):
        dart_content = f"""// 自动生成的版本与构建信息文件 (每次构建流水线会自动同步刷新)
class AppVersionInfo {{
  static const String versionName = '{new_version}';
  static const int buildNumber = {new_build_number};
  static const String buildTime = '{now.strftime("%Y-%m-%d %H:%M")}';
  static const String buildTag = 'RELEASE-BUILD';
  static const String serverHost = '39.97.158.22:9001';
  static const String releaseHighlights = '个人主页电竞体能专属卡片 · 幸运夺宝严控概率与双重保底 · 商业化体验完善';
}}
"""
        with open(app_version_dart, 'w', encoding='utf-8') as f:
            f.write(dart_content)

    log(f"🚀 版本号自动递增成功: v{major}.{minor}.{patch} -> v{new_version} (Build {new_build_number})", "95")
    return new_version

def build_android_apk():
    log("================================================================", "94")
    log(">>> 正在编译 Android Release APK (通用/支持多架构)...", "94")
    log("================================================================", "94")
    ensure_dist_dir()
    os.makedirs(GLOBAL_DIST_APPS, exist_ok=True)
    
    current_version = bump_version_and_save()
    
    # 执行 Flutter 打包
    success = run_cmd("flutter build apk --release")
    if not success:
        log("❌ Android APK 编译失败，请检查 Flutter/Android SDK 环境！", "91")
        return False
        
    src_candidates = [
        os.path.join(APP_DIR, "build", "app", "outputs", "flutter-apk", "app-release.apk"),
        os.path.join(APP_DIR, "build", "app", "outputs", "apk", "release", "app-release.apk"),
    ]
    src_apk = next((p for p in src_candidates if os.path.exists(p) and os.path.getsize(p) > 1024 * 1024), None)

    if src_apk:
        # 1. 拷贝到 party_game 根目录
        root_latest = os.path.join(ROOT_DIR, "party_game_app_latest.apk")
        root_ver_apk = os.path.join(ROOT_DIR, f"party_game_app_v{current_version}.apk")
        shutil.copy2(src_apk, root_latest)
        shutil.copy2(src_apk, root_ver_apk)
        
        # 2. 拷贝到顶级统一分发目录 c:\project\fwpt\dist_apps
        dist_app_target = os.path.join(GLOBAL_DIST_APPS, f"party_game_app-v{current_version}.apk")
        shutil.copy2(src_apk, dist_app_target)
        
        size_mb = os.path.getsize(dist_app_target) / (1024 * 1024)
        log(f"🎉 Android APK 打包成功！大小: {size_mb:.2f} MB", "92")
        log(f"   [交付产物]: {dist_app_target}", "92")
        log(f"   [本地产物]: {root_ver_apk}", "92")
        return True
    else:
        log("❌ 未找到有效构建产物 APK 文件！", "91")
        return False

def build_android_aab():
    log("================================================================", "94")
    log(">>> 正在编译 Android App Bundle (Google Play AAB)...", "94")
    log("================================================================", "94")
    ensure_dist_dir()
    success = run_cmd("flutter build appbundle --release")
    if success:
        src_aab = os.path.join(APP_DIR, "build", "app", "outputs", "bundle", "release", "app-release.aab")
        if os.path.exists(src_aab):
            target_aab = os.path.join(DIST_DIR, "party_game_release.aab")
            root_aab = os.path.join(ROOT_DIR, "party_game_release.aab")
            shutil.copy2(src_aab, target_aab)
            shutil.copy2(src_aab, root_aab)
            log(f"🎉 Android AAB 打包成功: {target_aab} 以及 {root_aab}", "92")
            return True
    return False

def build_harmonyos():
    log("================================================================", "95")
    log(">>> 正在处理 鸿蒙 (HarmonyOS Next / OpenHarmony) 模块与编译...", "95")
    log("================================================================", "95")
    ensure_dist_dir()
    ohos_dir = os.path.join(APP_DIR, "ohos")
    if not os.path.exists(ohos_dir):
        log("未检测到 ohos 目录！", "91")
        return False
        
    # 检测是否安装了 hvigorw 鸿蒙构建工具
    hvigorw_path = os.path.join(ohos_dir, "hvigorw.bat" if os.name == 'nt' else "hvigorw")
    if os.path.exists(hvigorw_path):
        log("检测到 hvigorw，正在调用 OpenHarmony 编译器生成 .hap 安装包...")
        success = run_cmd(f"{hvigorw_path} assembleHap --no-daemon", cwd=ohos_dir)
        if success:
            log("🎉 鸿蒙 HAP 打包完成！", "92")
            return True
    else:
        log("💡 说明: 本工程已配齐标准 OpenHarmony ArkTS 架构与配置文件 (ohos/)；", "93")
        log("   您可以在华为 DevEco Studio 中直接打开 party_game_app 项目一键构建签名并输出 .hap 安装包！", "93")
        log(f"   鸿蒙模块源码路径: {ohos_dir}", "93")
        return True

def build_ios():
    log("================================================================", "96")
    log(">>> 正在处理 iOS 原生打包准备...", "96")
    log("================================================================", "96")
    if sys.platform != 'darwin':
        log("⚠️ 提示: 苹果 iOS 签名与 IPA 打包需在 macOS 环境下运行 Xcode/Metal 编译器。", "93")
        log("   当前 Windows 环境已完成 iOS 工程配置，代码可直接在 Mac 机上执行 `flutter build ipa` 构建！", "93")
        return True
    else:
        ensure_dist_dir()
        return run_cmd("flutter build ipa --release --no-codesign")

def build_web():
    log("================================================================", "96")
    log(">>> 正在编译 Web 纯静态 HTML5 生产产物...", "96")
    log("================================================================", "96")
    ensure_dist_dir()
    success = run_cmd("flutter build web --release")
    if success:
        web_build = os.path.join(APP_DIR, "build", "web")
        target_zip = os.path.join(DIST_DIR, "party_game_web.zip")
        root_web_zip = os.path.join(ROOT_DIR, "party_game_web.zip")
        shutil.make_archive(os.path.join(DIST_DIR, "party_game_web"), 'zip', web_build)
        shutil.copy2(target_zip, root_web_zip)
        log(f"🎉 Web 产物打包成功: {target_zip} 以及 {root_web_zip}", "92")
        return True
    return False

def open_output_folder():
    if os.name == 'nt':
        try:
            subprocess.Popen(['explorer', ROOT_DIR])
        except Exception:
            pass

def interactive_menu():
    print("""
================================================================
          🎲 聚会桌游跨平台客户端一键打包工具 🎲
================================================================
   请选择您需要打包的目标平台：
   
   [1] 仅打包安卓 Android (Release APK)  -- 推荐! 最常用!
   [2] 仅打包安卓 Google Play (AAB 包)
   [3] 仅构建鸿蒙 HarmonyOS Next (HAP 规范与产物)
   [4] 仅打包苹果 iOS 生产包 (需 macOS)
   [5] 仅打包 Web 网页版 (H5)
   [6] 一键打包全平台 (Android + 鸿蒙 + Web)
   [0] 退出
================================================================
""")
    choice = input("请输入选项编号并按回车 [默认 1]: ").strip()
    if not choice:
        choice = '1'

    if choice == '1':
        if build_android_apk():
            open_output_folder()
    elif choice == '2':
        if build_android_aab():
            open_output_folder()
    elif choice == '3':
        build_harmonyos()
    elif choice == '4':
        build_ios()
    elif choice == '5':
        if build_web():
            open_output_folder()
    elif choice == '6':
        log("开始全平台流水线构建...")
        build_android_apk()
        build_harmonyos()
        build_web()
        open_output_folder()
    elif choice == '0':
        print("已退出。")
        sys.exit(0)
    else:
        print(f"无效选项: {choice}")

def main():
    parser = argparse.ArgumentParser(description="PartyGameApp Multi-Platform Builder")
    parser.add_argument("--platform", "-p", choices=["android", "android-apk", "android-aab", "harmonyos", "ios", "web", "all"], help="指定打包平台")
    parser.add_argument("--android-only", action="store_true", help="只打包安卓 APK")
    args = parser.parse_args()

    if args.android_only or args.platform in ["android", "android-apk"]:
        if build_android_apk():
            open_output_folder()
    elif args.platform == "android-aab":
        if build_android_aab():
            open_output_folder()
    elif args.platform == "harmonyos":
        build_harmonyos()
    elif args.platform == "ios":
        build_ios()
    elif args.platform == "web":
        if build_web():
            open_output_folder()
    elif args.platform == "all":
        build_android_apk()
        build_harmonyos()
        build_web()
        open_output_folder()
    else:
        interactive_menu()

if __name__ == "__main__":
    main()
