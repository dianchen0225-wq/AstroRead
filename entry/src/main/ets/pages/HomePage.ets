/**
 * HomePage - 首页编排组件
 * 组合 HomeHeader、QuickActionBar、FeatureMenuList、HomeFooter 子组件
 * 管理主题状态和导航逻辑
 */

import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { HomeTokens } from '../common/HomeTokens';
import { NavigationManager } from '../common/NavigationManager';
import { HomeHeader } from '../components/HomeHeader';
import { QuickActionBar } from '../components/QuickActionBar';
import { FeatureMenuList } from '../components/FeatureMenuList';
import { HomeFooter } from '../components/HomeFooter';

@ComponentV2
export struct HomePage {
  @Local isLightMode: boolean = true;
  @Param safeAreaTop: number = 0;
  @Param onNavigate: (route: string, params?: ESObject) => void = () => {};

  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  private handleTabSwitch(tabIndex: number): void {
    if (this.onNavigate) {
      this.onNavigate('TabSwitch', { tabIndex: tabIndex });
    }
  }

  build() {
    Column() {
      // 顶部栏：主题切换 + 版本徽章
      HomeHeader({
        isLightMode: this.isLightMode,
        safeAreaTop: this.safeAreaTop
      })

      // 品牌标题区
      this.buildAppTitle()

      // 快捷操作栏：继续阅读、搜索书籍、导入书源
      QuickActionBar({
        isLightMode: this.isLightMode,
        onActionClick: (tabIndex: number) => {
          this.handleTabSwitch(tabIndex);
        }
      })

      // 功能菜单列表：我的书架、搜索书籍、书源管理、设置
      FeatureMenuList({
        isLightMode: this.isLightMode,
        onMenuClick: (tabIndex: number) => {
          this.handleTabSwitch(tabIndex);
        }
      })

      // 弹性留白
      Blank()

      // 底部品牌信息
      HomeFooter({
        isLightMode: this.isLightMode
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }

  @Builder
  buildAppTitle() {
    Column() {
      Text($r('app.string.app_name'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontSize(HomeTokens.BrandTitle.fontSize)
        .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.bold)
        .letterSpacing(HomeTokens.BrandTitle.letterSpacing)
        .textShadow({
          radius: 8,
          color: this.isLightMode ? 'rgba(139, 105, 20, 0.2)' : 'rgba(212, 180, 131, 0.3)',
          offsetX: 0,
          offsetY: 2
        })

      Text($r('app.string.home_subtitle'))
        .fontSize(HomeTokens.BrandTitle.subtitleSize)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ top: DesignSystem.Spacing.sm })
        .letterSpacing(2)
    }
    .width('100%')
    .padding({
      top: DesignSystem.Spacing.lg,
      bottom: DesignSystem.Spacing.xl
    })
  }
}
