import { FlutterPage } from '@ohos/flutter_ohos';

/**
 * 鸿蒙 Next 声明式 UI 页面：挂载 Flutter 渲染视图
 */
@Entry
@Component
struct Index {
  build() {
    Column() {
      FlutterPage({
        viewId: 'party_game_flutter_view'
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0E1A')
  }
}
