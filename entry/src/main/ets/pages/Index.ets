import { BookSourcePage } from './BookSourcePage';
import { HomePage } from './HomePage';
import { SearchPage } from './SearchPage';
import { SettingsPage } from './SettingsPage';
import { ThemeManager } from '../styles/ThemeManager';
import { AppTheme, AppColors } from '../styles/Theme';

/**
 * 页面配置接口
 */
interface PageConfig {
  name: string;
  icon: Resource;
}

/**
 * 主页面 - 使用自定义Tab导航
 * 极简图标 + 文字风格，轻质感设计
 */
@Entry
@Component
export struct Index {
  @State currentIndex: number = 0;
  @State currentTheme: AppTheme = ThemeManager.getInstance().currentTheme;
  
  private themeManager: ThemeManager = ThemeManager.getInstance();
  
  // 页面配置数组
  private pages: PageConfig[] = [
    { name: '书架', icon: $r('app.media.ic_bookshelf_line') },
    { name: '搜索', icon: $r('app.media.ic_search_line') },
    { name: '书源', icon: $r('app.media.ic_book_source_line') },
    { name: '设置', icon: $r('app.media.ic_settings_line') }
  ];

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

  build() {
    Column() {
      // 页面内容区域
      Column() {
        if (this.currentIndex === 0) {
          HomePage()
        } else if (this.currentIndex === 1) {
          SearchPage()
        } else if (this.currentIndex === 2) {
          BookSourcePage()
        } else if (this.currentIndex === 3) {
          SettingsPage()
        }
      }
      .width('100%')
      .layoutWeight(1)

      // 底部导航栏
      Row() {
        ForEach(this.pages, (item: PageConfig, index: number) => {
          Column() {
            // 图标
            Image(item.icon)
              .width(24)
              .height(24)
              .fillColor(this.currentIndex === index ? AppColors.PRIMARY : this.currentTheme.textTertiary)
              .margin({ bottom: 4 })

            // 文字
            Text(item.name)
              .fontSize(10)
              .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.currentIndex === index ? AppColors.PRIMARY : this.currentTheme.textTertiary)

            // 选中指示条
            if (this.currentIndex === index) {
              Column() {
                // 空列用于指示条
              }
              .width(24)
              .height(3)
              .backgroundColor(AppColors.PRIMARY)
              .borderRadius(2)
              .margin({ top: 6 })
            }
          }
          .width('25%') // 等分4个标签
          .height(56)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('transparent')
          .onClick(() => {
            this.currentIndex = index;
          })
          .animation({
            duration: 200,
            curve: Curve.EaseOut
          })
        })
      }
      .width('100%')
      .height(56)
      .backgroundColor(this.currentTheme.surfaceColor)
      .border({
        width: { top: 1 },
        color: this.currentTheme.borderColor,
        style: BorderStyle.Solid
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentTheme.backgroundColor)
  }
}