/**
 * 组件样式库
 * 统一管理所有UI组件的样式，支持主题切换
 */

import { ThemeManager } from './ThemeManager';
import { AppTypography, AppSpacing, AppBorderRadius, AppShadows, AppColors } from './Theme';

// 获取当前主题实例
const themeManager = ThemeManager.getInstance();

// 按钮样式 - 使用@Extend装饰器
@Extend(Button) function primaryButton() {
  .backgroundColor(AppColors.PRIMARY)
  .fontColor('#FFFFFF')
  .fontWeight(FontWeight.Medium)
  .borderRadius(AppBorderRadius.MD)
}

@Extend(Button) function secondaryButton() {
  .backgroundColor(AppColors.LIGHT_SURFACE)
  .fontColor(AppColors.PRIMARY)
  .fontWeight(FontWeight.Medium)
  .borderRadius(AppBorderRadius.MD)
}

@Extend(Button) function textButton() {
  .backgroundColor('transparent')
  .fontColor(AppColors.PRIMARY)
  .fontWeight(FontWeight.Medium)
}

// 卡片样式 - 使用@Extend装饰器
@Extend(Column) function cardStyle() {
  .backgroundColor(themeManager.currentTheme.cardColor)
  .borderRadius(AppBorderRadius.LG)
  .shadow({
    radius: AppShadows.MD.radius,
    color: AppShadows.MD.color,
    offsetX: AppShadows.MD.offsetX,
    offsetY: AppShadows.MD.offsetY
  })
}

@Extend(Column) function surfaceCard() {
  .backgroundColor(themeManager.currentTheme.surfaceColor)
  .borderRadius(AppBorderRadius.MD)
  .shadow({
    radius: AppShadows.SM.radius,
    color: AppShadows.SM.color,
    offsetX: AppShadows.SM.offsetX,
    offsetY: AppShadows.SM.offsetY
  })
}

// 文本样式 - 使用@Extend装饰器
@Extend(Text) function titleText() {
  .fontSize(AppTypography.H3.size)
  .fontWeight(AppTypography.H3.weight)
  .fontColor(themeManager.currentTheme.textPrimary)
  .lineHeight(AppTypography.H3.lineHeight)
}

@Extend(Text) function subtitleText() {
  .fontSize(AppTypography.H5.size)
  .fontWeight(AppTypography.H5.weight)
  .fontColor(themeManager.currentTheme.textSecondary)
  .lineHeight(AppTypography.H5.lineHeight)
}

@Extend(Text) function bodyText() {
  .fontSize(AppTypography.BODY_MEDIUM.size)
  .fontWeight(AppTypography.BODY_MEDIUM.weight)
  .fontColor(themeManager.currentTheme.textPrimary)
  .lineHeight(AppTypography.BODY_MEDIUM.lineHeight)
}

@Extend(Text) function captionText() {
  .fontSize(AppTypography.CAPTION.size)
  .fontWeight(AppTypography.CAPTION.weight)
  .fontColor(themeManager.currentTheme.textTertiary)
  .lineHeight(AppTypography.CAPTION.lineHeight)
}

// 输入框样式 - 使用@Extend装饰器
@Extend(TextInput) function inputField() {
  .backgroundColor(themeManager.currentTheme.surfaceColor)
  .borderRadius(AppBorderRadius.MD)
  .fontSize(AppTypography.BODY_MEDIUM.size)
  .fontColor(themeManager.currentTheme.textPrimary)
  .placeholderColor(themeManager.currentTheme.textTertiary)
}

// 分隔线样式 - 使用@Extend装饰器
@Extend(Row) function dividerLine() {
  .backgroundColor(themeManager.currentTheme.borderColor)
  .height(1)
}

// 响应式布局工具 - 简化为三个独立的函数
@Extend(Text) function responsiveTextSmall() {
  .fontColor(themeManager.currentTheme.textPrimary)
  .fontSize(AppTypography.BODY_SMALL.size)
  .fontWeight(AppTypography.BODY_SMALL.weight)
}

@Extend(Text) function responsiveTextMedium() {
  .fontColor(themeManager.currentTheme.textPrimary)
  .fontSize(AppTypography.BODY_MEDIUM.size)
  .fontWeight(AppTypography.BODY_MEDIUM.weight)
}

@Extend(Text) function responsiveTextLarge() {
  .fontColor(themeManager.currentTheme.textPrimary)
  .fontSize(AppTypography.BODY_LARGE.size)
  .fontWeight(AppTypography.BODY_LARGE.weight)
}

@Extend(Row) function responsiveRow() {
  .width('100%')
  .padding({
    left: AppSpacing.MD,
    right: AppSpacing.MD
  })
  .alignItems(VerticalAlign.Center)
  .justifyContent(FlexAlign.SpaceBetween)
}

// 导出样式组件
export {
  primaryButton,
  secondaryButton,
  textButton,
  cardStyle,
  surfaceCard,
  titleText,
  subtitleText,
  bodyText,
  captionText,
  inputField,
  dividerLine,
  responsiveTextSmall,
  responsiveTextMedium,
  responsiveTextLarge,
  responsiveRow
};