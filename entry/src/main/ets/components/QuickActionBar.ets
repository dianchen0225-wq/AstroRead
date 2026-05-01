/**
 * QuickActionBar - 首页快捷操作栏业务组件
 * 渲染三个高频快捷操作入口：继续阅读、搜索书籍、导入书源
 */

import { DesignSystem } from '../common/DesignSystem';
import { HomeTokens } from '../common/HomeTokens';

interface QuickActionData {
  id: string;
  icon: ResourceStr;
  title: ResourceStr;
  tabIndex: number;
}

@ComponentV2
export struct QuickActionBar {
  @Param isLightMode: boolean = true;
  @Param onActionClick: (tabIndex: number) => void = () => {};
  @Local pressedActionId: string = '';

  private quickActions: QuickActionData[] = [
    { id: 'continue_reading', icon: $r('app.string.icon_continue_reading'), title: $r('app.string.continue_reading'), tabIndex: 2 },
    { id: 'search_books', icon: $r('app.string.icon_search_books'), title: $r('app.string.search_books'), tabIndex: 1 },
    { id: 'import_source', icon: $r('app.string.icon_import_source'), title: $r('app.string.import_source'), tabIndex: 3 }
  ];

  build() {
    Row() {
      ForEach(this.quickActions, (action: QuickActionData) => {
        this.buildQuickActionItem(action)
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      bottom: DesignSystem.Spacing.lg
    })
  }

  @Builder
  buildQuickActionItem(action: QuickActionData) {
    Column() {
      // 圆形图标容器
      Row() {
        Text(action.icon)
          .fontSize(HomeTokens.QuickAction.iconSize)
      }
      .width(HomeTokens.QuickAction.iconContainerSize)
      .height(HomeTokens.QuickAction.iconContainerSize)
      .borderRadius(DesignSystem.BorderRadius.full)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .justifyContent(FlexAlign.Center)
      .shadow({
        radius: 4,
        color: this.isLightMode ? 'rgba(0,0,0,0.05)' : 'rgba(0,0,0,0.2)',
        offsetX: 0,
        offsetY: 2
      })

      // 文字标签
      Text(action.title)
        .fontSize(HomeTokens.QuickAction.labelSize)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ top: DesignSystem.Spacing.sm })
    }
    .scale({
      x: this.pressedActionId === action.id ? 0.95 : 1,
      y: this.pressedActionId === action.id ? 0.95 : 1
    })
    .opacity(this.pressedActionId === action.id ? 0.85 : 1)
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      this.onActionClick(action.tabIndex);
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedActionId = action.id;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedActionId = '';
      }
    })
  }
}
