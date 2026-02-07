import { BookSourcePage } from './BookSourcePage';
import { HomePage } from './HomePage';
import { SearchPage } from './SearchPage';
import { SettingsPage } from './SettingsPage';
import { ThemeManager } from '../styles/ThemeManager';
import { AppTheme } from '../styles/Theme';

/**
 * 主页面 - 使用Tab导航
 * 集成主题系统，支持动态主题切换
 */
@Entry
@Component
export struct Index {
  @State currentIndex: number = 0;
  @State currentTheme: AppTheme = ThemeManager.getInstance().currentTheme;
  
  private themeManager: ThemeManager = ThemeManager.getInstance();

  aboutToAppear(): void {
    // 注册主题变更监听
    this.themeManager.onThemeChange((theme: AppTheme) => {
      this.currentTheme = theme;
    });
  }

  aboutToDisappear(): void {
    // 清理主题监听
    this.themeManager.offThemeChange(() => {});
  }

  onTabChange(index: number) {
    this.currentIndex = index;
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
        // 书架
        TabContent() {
          HomePage()
        }
        .tabBar({
          text: '书架',
          icon: '\ue715'
        })

        // 搜索
        TabContent() {
          SearchPage()
        }
        .tabBar({
          text: '搜索',
          icon: '\ue68b'
        })

        // 书源
        TabContent() {
          BookSourcePage()
        }
        .tabBar({
          text: '书源',
          icon: '\ue674'
        })

        // 设置
        TabContent() {
          SettingsPage()
        }
        .tabBar({
          text: '设置',
          icon: '\ue693'
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.currentTheme.backgroundColor)
      .onChange((index: number) => {
        this.onTabChange(index);
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentTheme.backgroundColor)
  }
}