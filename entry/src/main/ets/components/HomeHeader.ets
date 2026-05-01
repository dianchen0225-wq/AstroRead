/**
 * HomeHeader - 首页顶部栏业务组件
 * 包含主题切换按钮和版本徽章
 */

import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';

@ComponentV2
export struct HomeHeader {
  @Param isLightMode: boolean = true;
  @Param safeAreaTop: number = 0;
  @Local isPressed: boolean = false;

  build() {
    Row() {
      // 主题切换按钮
      this.buildThemeToggle()

      Blank()

      // 版本徽章
      this.buildVersionBadge()
    }
    .width('100%')
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: this.safeAreaTop + DesignSystem.Spacing.md,
      bottom: DesignSystem.Spacing.sm
    })
  }

  @Builder
  buildThemeToggle() {
    Row() {
      Text(this.isLightMode ? $r('app.string.icon_dark_mode') : $r('app.string.icon_light_mode'))
        .fontSize(DesignSystem.IconSize.md)
        .margin({ right: DesignSystem.Spacing.sm })

      Text(this.isLightMode ? $r('app.string.dark_mode') : $r('app.string.light_mode'))
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.medium)
    }
    .padding({
      left: DesignSystem.Spacing.md,
      right: DesignSystem.Spacing.md,
      top: DesignSystem.Spacing.sm,
      bottom: DesignSystem.Spacing.sm
    })
    .borderRadius(DesignSystem.BorderRadius.lg)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .shadow({
      radius: 4,
      color: this.isLightMode ? 'rgba(0,0,0,0.03)' : 'rgba(0,0,0,0.2)',
      offsetX: 0,
      offsetY: 2
    })
    .scale({ x: this.isPressed ? 0.95 : 1, y: this.isPressed ? 0.95 : 1 })
    .opacity(this.isPressed ? 0.9 : 1)
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      themeManager.toggleTheme();
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
  }

  @Builder
  buildVersionBadge() {
    Row() {
      Text($r('app.string.version_badge'))
        .fontSize(DesignSystem.Typography.size.xs)
        .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.medium)
    }
    .padding({
      left: DesignSystem.Spacing.sm,
      right: DesignSystem.Spacing.sm,
      top: DesignSystem.Spacing.xs,
      bottom: DesignSystem.Spacing.xs
    })
    .borderRadius(DesignSystem.BorderRadius.md)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }
}
