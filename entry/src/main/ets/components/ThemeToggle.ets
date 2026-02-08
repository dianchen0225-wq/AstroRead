/**
 * 主题切换组件
 * 支持亮色/暗黑模式切换
 */

import { ThemeManager } from '../styles/ThemeManager';
import { ThemeType, AppTheme, AppShadows } from '../styles/Theme';

@Component
export struct ThemeToggle {
  private themeManager: ThemeManager = ThemeManager.getInstance();
  @State currentTheme: AppTheme = this.themeManager.currentTheme;
  @State isDarkMode: boolean = this.themeManager.isDarkMode;

  aboutToAppear(): void {
    this.themeManager.onThemeChange((theme: AppTheme) => {
      this.currentTheme = theme;
      this.isDarkMode = this.themeManager.isDarkMode;
    });
  }

  aboutToDisappear(): void {
    this.themeManager.offThemeChange(() => {});
  }

  build() {
    Button() {
      Row() {
        // 太阳图标 - 亮色模式
        Text(this.isDarkMode ? '☀️' : '🌙')
          .fontSize(18)
          .fontColor(this.currentTheme.textPrimary)
        
        Text(this.isDarkMode ? '亮色模式' : '暗黑模式')
          .fontSize(14)
          .fontColor(this.currentTheme.textPrimary)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 8 })
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 12 })
    }
    .height(36)
    .backgroundColor(this.currentTheme.surfaceColor)
    .borderRadius(18)
    .shadow({
      radius: AppShadows.SM.radius,
      color: AppShadows.SM.color,
      offsetX: AppShadows.SM.offsetX,
      offsetY: AppShadows.SM.offsetY
    })
    .onClick(() => {
      this.themeManager.toggleTheme();
    })
    .animation({
      duration: 300,
      curve: Curve.EaseOut
    })
  }
}