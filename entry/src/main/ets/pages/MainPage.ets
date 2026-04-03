import { HomePage } from './Index';
import { SettingsPage } from './Settings';
import { LogPage } from './LogPage';
import { DevicePage } from './Device';
import { TerminalPage } from './TerminalPage';

@Entry
@Component
struct MainPage {
  @State currentIndex: number = 0;
  @State loadedTabs: boolean[] = [true, false, false, false, false]; // 只有首页默认加载
  private tabsController: TabsController = new TabsController();

  @Builder
  TabBuilder(title: Resource, targetIndex: number, selectedImg: Resource, normalImg: Resource) {

    Column() {

      Image(this.currentIndex === targetIndex ? selectedImg : normalImg)
        .width(24)
        .height(24)
        .fillColor(this.currentIndex === targetIndex ? $r('app.color.primary_color') : $r('app.color.icon_color'))
      Text(title)
        .fontSize(12)
        .fontColor(this.currentIndex === targetIndex ? $r('app.color.primary_color') : $r('app.color.text_tertiary'))
        .margin({ top: 4 })
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentIndex = targetIndex;
      this.tabsController.changeIndex(targetIndex);
    })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
      TabContent() {
        HomePage()
      }
      .tabBar(this.TabBuilder($r('app.string.home_title'), 0, $r('app.media.house'), $r('app.media.house')))

      TabContent() {
        if (this.loadedTabs[1]) {
          DevicePage()
        }
      }
      .tabBar(this.TabBuilder($r('app.string.device_title'), 1, $r('app.media.bolt'), $r('app.media.bolt')))
      TabContent() {
        if (this.loadedTabs[2]) {
          TerminalPage()
        }
      }
      .tabBar(this.TabBuilder($r('app.string.terminal_title'), 2, $r('app.media.terminal'), $r('app.media.terminal')))

      TabContent() {
        if (this.loadedTabs[3]) {
          LogPage()
        }
      }
      .tabBar(this.TabBuilder($r('app.string.logs_title'), 3, $r('app.media.doc_plaintext'), $r('app.media.doc_plaintext')))

      TabContent() {
        if (this.loadedTabs[4]) {
          SettingsPage()
        }
      }
      .tabBar(this.TabBuilder($r('app.string.settings_title'), 4, $r('app.media.gearshape'), $r('app.media.gearshape')))

    }
    .width('100%')
    .height('100%')
    .barWidth('100%')
    .barHeight(56)
    .barBackgroundColor($r('app.color.page_background'))
    .onChange((index: number) => {
      this.currentIndex = index;
      this.loadedTabs[index] = true; // 标记为已加载
    })
    .vertical(false)
  }
}
