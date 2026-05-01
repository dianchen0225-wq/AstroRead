/**
 * FeatureListItem - 功能菜单列表项原子组件
 * 渲染单个功能菜单项：渐变图标 + 标题 + 描述 + 箭头
 * 支持按压反馈微交互
 */

import { DesignSystem } from '../common/DesignSystem';
import { HomeTokens } from '../common/HomeTokens';

interface GradientColorItem {
  color: string;
  position: number;
}

interface MenuItemData {
  id: string;
  title: ResourceStr;
  desc: ResourceStr;
  icon: ResourceStr;
  gradientKey: string;
  route: string;
  tabIndex?: number;
}

@ComponentV2
export struct FeatureListItem {
  @Param isLightMode: boolean = true;
  @Param item: MenuItemData = { id: '', title: '', desc: '', icon: '', gradientKey: 'bookshelf', route: '' };
  @Param onItemClick: (item: MenuItemData) => void = () => {};
  @Local isPressed: boolean = false;

  private getGradientColors(): Array<[string, number]> {
    return HomeTokens.getGradientColors(this.item.gradientKey, this.isLightMode);
  }

  private getGradientStartColor(): string {
    return HomeTokens.getGradientStartColor(this.item.gradientKey, this.isLightMode);
  }

  build() {
    Row() {
      // 渐变图标容器
      Row() {
        Text(this.item.icon)
          .fontSize(DesignSystem.IconSize.lg)
      }
      .width(HomeTokens.FeatureMenu.iconContainerSize)
      .height(HomeTokens.FeatureMenu.iconContainerSize)
      .borderRadius(DesignSystem.BorderRadius.lg)
      .linearGradient({
        angle: 135,
        colors: this.getGradientColors()
      })
      .justifyContent(FlexAlign.Center)
      .shadow({
        radius: 8,
        color: `${this.getGradientStartColor()}40`,
        offsetX: 0,
        offsetY: 4
      })
      .margin({ right: DesignSystem.Spacing.md })

      // 标题 + 描述
      Column() {
        Text(this.item.title)
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.medium)
          .lineHeight(22)

        Text(this.item.desc)
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .lineHeight(18)
          .margin({ top: DesignSystem.Spacing.xs })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 箭头指示
      Row() {
        Text('›')
          .fontSize(DesignSystem.Typography.size.xl)
          .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
      }
      .width(HomeTokens.FeatureMenu.arrowSize)
      .height(HomeTokens.FeatureMenu.arrowSize)
      .borderRadius(DesignSystem.BorderRadius.md)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(HomeTokens.FeatureMenu.itemHeight)
    .padding({
      left: DesignSystem.Spacing.md,
      right: DesignSystem.Spacing.md,
      top: DesignSystem.Spacing.sm,
      bottom: DesignSystem.Spacing.sm
    })
    .borderRadius(DesignSystem.BorderRadius.xl)
    .backgroundColor(this.isPressed ?
      DesignSystem.getActiveColor(this.isLightMode) :
      DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .shadow({
      radius: this.isPressed ? 2 : 4,
      color: this.isLightMode ? 'rgba(0,0,0,0.04)' : 'rgba(0,0,0,0.2)',
      offsetX: 0,
      offsetY: this.isPressed ? 1 : 2
    })
    .scale({
      x: this.isPressed ? 0.98 : 1,
      y: this.isPressed ? 0.98 : 1
    })
    .opacity(this.isPressed ? 0.9 : 1)
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      this.onItemClick(this.item);
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
  }
}

export { MenuItemData }
