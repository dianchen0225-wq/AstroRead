/**
 * 组件样式库
 * 统一管理所有UI组件的样式，支持主题切换
 */

import { ThemeManager } from './ThemeManager';
import { AppTypography, AppSpacing, AppBorderRadius, AppShadows } from './Theme';

// 获取当前主题实例
const themeManager = ThemeManager.getInstance();

// 按钮样式
@Styles function primaryButton() {
  .fontSize(AppTypography.BODY_MEDIUM.size)
  .fontWeight(AppTypography.BODY_MEDIUM.weight)
  .fontColor('#FFFFFF')
  .backgroundColor(themeManager.currentTheme.colors.PRIMARY)
  .borderRadius(AppBorderRadius.MD)
  .padding({
    left: AppSpacing.MD,
    right: AppSpacing.MD,
    top: AppSpacing.SM,
    bottom: AppSpacing.SM
  })
  .shadow(AppShadows.SM)
  .stateEffect({
    pressed: {
      backgroundColor: themeManager.currentTheme.colors.PRIMARY_DARK,
      shadow: AppShadows.MD
    }
  })
}

@Styles function secondaryButton() {
  .fontSize(AppTypography.BODY_MEDIUM.size)
  .fontWeight(AppTypography.BODY_MEDIUM.weight)
  .fontColor(themeManager.currentTheme.colors.PRIMARY)
  .backgroundColor('transparent')
  .border({
    width: 1,
    color: themeManager.currentTheme.colors.PRIMARY,
    style: BorderStyle.Solid
  })
  .borderRadius(AppBorderRadius.MD)
  .padding({
    left: AppSpacing.MD,
    right: AppSpacing.MD,
    top: AppSpacing.SM,
    bottom: AppSpacing.SM
  })
  .stateEffect({
    pressed: {
      backgroundColor: themeManager.currentTheme.colors.PRIMARY_LIGHT + '20',
      borderColor: themeManager.currentTheme.colors.PRIMARY_DARK
    }
  })
}

@Styles function textButton() {
  .fontSize(AppTypography.BODY_MEDIUM.size)
  .fontWeight(AppTypography.BODY_MEDIUM.weight)
  .fontColor(themeManager.currentTheme.colors.PRIMARY)
  .backgroundColor('transparent')
  .padding(AppSpacing.SM)
  .stateEffect({
    pressed: {
      backgroundColor: themeManager.currentTheme.colors.PRIMARY_LIGHT + '20'
    }
  })
}

// 卡片样式
@Styles function cardStyle() {
  .backgroundColor(themeManager.currentTheme.cardColor)
  .borderRadius(AppBorderRadius.LG)
  .shadow(AppShadows.MD)
  .padding(AppSpacing.MD)
}

@Styles function surfaceCard() {
  .backgroundColor(themeManager.currentTheme.surfaceColor)
  .borderRadius(AppBorderRadius.MD)
  .shadow(AppShadows.SM)
  .padding(AppSpacing.MD)
}

// 文本样式
@Styles function titleText() {
  .fontSize(AppTypography.H4.size)
  .fontWeight(AppTypography.H4.weight)
  .fontColor(themeManager.currentTheme.textPrimary)
  .lineHeight(AppTypography.H4.lineHeight)
}

@Styles function subtitleText() {
  .fontSize(AppTypography.H6.size)
  .fontWeight(AppTypography.H6.weight)
  .fontColor(themeManager.currentTheme.textSecondary)
  .lineHeight(AppTypography.H6.lineHeight)
}

@Styles function bodyText() {
  .fontSize(AppTypography.BODY_MEDIUM.size)
  .fontWeight(AppTypography.BODY_MEDIUM.weight)
  .fontColor(themeManager.currentTheme.textPrimary)
  .lineHeight(AppTypography.BODY_MEDIUM.lineHeight)
}

@Styles function captionText() {
  .fontSize(AppTypography.BODY_SMALL.size)
  .fontWeight(AppTypography.BODY_SMALL.weight)
  .fontColor(themeManager.currentTheme.textTertiary)
  .lineHeight(AppTypography.BODY_SMALL.lineHeight)
}

// 输入框样式
@Styles function inputField() {
  .fontSize(AppTypography.BODY_MEDIUM.size)
  .fontColor(themeManager.currentTheme.textPrimary)
  .backgroundColor(themeManager.currentTheme.surfaceColor)
  .border({
    width: 1,
    color: themeManager.currentTheme.borderColor,
    style: BorderStyle.Solid
  })
  .borderRadius(AppBorderRadius.MD)
  .padding(AppSpacing.MD)
  .stateEffect({
    focused: {
      borderColor: themeManager.currentTheme.colors.PRIMARY,
      shadow: AppShadows.SM
    }
  })
}

// 分隔线样式
@Styles function dividerLine() {
  .height(1)
  .backgroundColor(themeManager.currentTheme.borderColor)
  .margin({
    top: AppSpacing.MD,
    bottom: AppSpacing.MD
  })
}

// 响应式布局工具
@Extend(Text) function responsiveText(sizeType: 'small' | 'medium' | 'large') {
  .fontColor(themeManager.currentTheme.textPrimary)
  let fontSize: number = AppTypography.BODY_MEDIUM.size;
  let fontWeight: FontWeight = AppTypography.BODY_MEDIUM.weight;
  
  if (sizeType === 'small') {
    fontSize = AppTypography.BODY_SMALL.size;
    fontWeight = AppTypography.BODY_SMALL.weight;
  } else if (sizeType === 'large') {
    fontSize = AppTypography.BODY_LARGE.size;
    fontWeight = AppTypography.BODY_LARGE.weight;
  }
  
  .fontSize(fontSize)
  .fontWeight(fontWeight)
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
  responsiveText,
  responsiveRow
};