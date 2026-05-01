/**
 * HomeFooter - 首页底部信息业务组件
 * 渲染品牌信息，视觉权重最低
 */

import { DesignSystem } from '../common/DesignSystem';

@ComponentV2
export struct HomeFooter {
  @Param isLightMode: boolean = true;

  build() {
    Column() {
      Text($r('app.string.home_footer'))
        .fontSize(DesignSystem.Typography.size.xs)
        .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
    }
    .width('100%')
    .padding(DesignSystem.Spacing.lg)
  }
}
