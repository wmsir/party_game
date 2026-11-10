import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import window from '@ohos.window';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

/**
 * 聚会桌游吧 (PartyGame Club) - HarmonyOS Next Entry Ability
 * 继承自 FlutterAbility，负责引擎初始化与原生 ArkTS 窗口生命周期管理
 */
export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    super.onWindowStageCreate(windowStage);
    
    // 设置全屏沉浸式体验
    let windowClass: window.Window = windowStage.getMainWindowSync();
    windowClass.setWindowLayoutFullScreen(true);
    windowClass.setWindowSystemBarEnable(['status', 'navigation']);
    windowClass.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: '#FFFFFF',
      navigationBarContentColor: '#FFFFFF'
    });
  }
}
