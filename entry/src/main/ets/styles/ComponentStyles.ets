/**
 * 组件样式库
 * 统一管理所有UI组件的样式，支持主题切换
 * 使用 $r 分层参数引用资源颜色，支持颜色模式自动切换
 */

export class AppTypography {
  static readonly H1 = { size: 30, weight: 700, lineHeight: 36 };
  static readonly H2 = { size: 24, weight: 600, lineHeight: 30 };
  static readonly H3 = { size: 20, weight: 600, lineHeight: 26 };
  static readonly H4 = { size: 17, weight: 600, lineHeight: 22 };
  static readonly H5 = { size: 15, weight: 500, lineHeight: 20 };
  
  static readonly BODY_LARGE = { size: 17, weight: 400, lineHeight: 26 };
  static readonly BODY_MEDIUM = { size: 15, weight: 400, lineHeight: 24 };
  static readonly BODY_SMALL = { size: 13, weight: 400, lineHeight: 20 };
  
  static readonly CAPTION = { size: 11, weight: 400, lineHeight: 16 };
  static readonly LABEL = { size: 13, weight: 500, lineHeight: 18 };
}

export class AppSpacing {
  static readonly XS = 2;
  static readonly SM = 4;
  static readonly MD = 8;
  static readonly LG = 12;
  static readonly XL = 16;
  static readonly XXL = 24;
  static readonly XXXL = 32;
  static readonly XXXXL = 48;
}

export class AppBorderRadius {
  static readonly NONE = 0;
  static readonly SM = 6;
  static readonly MD = 10;
  static readonly LG = 14;
  static readonly XL = 20;
  static readonly FULL = 999;
}

export class AppShadows {
  static readonly SM = { radius: 4, color: 'rgba(0,0,0,0.06)', offsetX: 0, offsetY: 2 };
  static readonly MD = { radius: 8, color: 'rgba(0,0,0,0.08)', offsetX: 0, offsetY: 4 };
  static readonly LG = { radius: 16, color: 'rgba(0,0,0,0.1)', offsetX: 0, offsetY: 8 };
  static readonly XL = { radius: 24, color: 'rgba(0,0,0,0.12)', offsetX: 0, offsetY: 12 };
}

export class AppAnimation {
  static readonly DURATION_FAST = 150;
  static readonly DURATION_NORMAL = 250;
  static readonly DURATION_SLOW = 400;
  
  static readonly CURVE_EASE = 'ease';
  static readonly CURVE_EASE_IN = 'ease-in';
  static readonly CURVE_EASE_OUT = 'ease-out';
  static readonly CURVE_EASE_IN_OUT = 'ease-in-out';
  static readonly CURVE_SPRING = 'spring(0.8, 100, 15, 0)';
}

@Extend(Button) function primaryButton() {
  .backgroundColor($r('app.color.color_primary'))
  .fontColor($r('app.color.color_button_text'))
  .fontWeight(FontWeight.Medium)
  .borderRadius(AppBorderRadius.MD)
  .height(44)
  .shadow({
    radius: 8,
    color: 'rgba(184, 134, 11, 0.25)',
    offsetX: 0,
    offsetY: 4
  })
}

@Extend(Button) function secondaryButton() {
  .backgroundColor($r('app.color.color_surface'))
  .fontColor($r('app.color.color_primary'))
  .fontWeight(FontWeight.Medium)
  .borderRadius(AppBorderRadius.MD)
  .height(44)
  .border({
    width: 1,
    color: $r('app.color.color_border')
  })
}

@Extend(Button) function textButton() {
  .backgroundColor('transparent')
  .fontColor($r('app.color.color_primary'))
  .fontWeight(FontWeight.Medium)
}

@Extend(Button) function dangerButton() {
  .backgroundColor($r('app.color.color_error'))
  .fontColor('#FFFFFF')
  .fontWeight(FontWeight.Medium)
  .borderRadius(AppBorderRadius.MD)
  .height(44)
}

@Extend(Column) function cardStyle() {
  .backgroundColor($r('app.color.color_card'))
  .borderRadius(AppBorderRadius.MD)
  .padding(AppSpacing.LG)
  .shadow({
    radius: AppShadows.SM.radius,
    color: AppShadows.SM.color,
    offsetX: AppShadows.SM.offsetX,
    offsetY: AppShadows.SM.offsetY
  })
}

@Extend(Column) function surfaceCard() {
  .backgroundColor($r('app.color.color_surface'))
  .borderRadius(AppBorderRadius.MD)
  .padding(AppSpacing.LG)
  .shadow({
    radius: AppShadows.SM.radius,
    color: AppShadows.SM.color,
    offsetX: AppShadows.SM.offsetX,
    offsetY: AppShadows.SM.offsetY
  })
  .border({
    width: 1,
    color: $r('app.color.color_border')
  })
}

@Extend(Column) function elevatedCard() {
  .backgroundColor($r('app.color.color_card'))
  .borderRadius(AppBorderRadius.LG)
  .padding(AppSpacing.XL)
  .shadow({
    radius: AppShadows.MD.radius,
    color: AppShadows.MD.color,
    offsetX: AppShadows.MD.offsetX,
    offsetY: AppShadows.MD.offsetY
  })
}

@Extend(Text) function titleText() {
  .fontSize(AppTypography.H3.size)
  .fontWeight(AppTypography.H3.weight)
  .fontColor($r('app.color.color_text_primary'))
  .lineHeight(AppTypography.H3.lineHeight)
  .letterSpacing(0.5)
}

@Extend(Text) function subtitleText() {
  .fontSize(AppTypography.H5.size)
  .fontWeight(AppTypography.H5.weight)
  .fontColor($r('app.color.color_text_secondary'))
  .lineHeight(AppTypography.H5.lineHeight)
}

@Extend(Text) function bodyText() {
  .fontSize(AppTypography.BODY_MEDIUM.size)
  .fontWeight(AppTypography.BODY_MEDIUM.weight)
  .fontColor($r('app.color.color_text_primary'))
  .lineHeight(AppTypography.BODY_MEDIUM.lineHeight)
}

@Extend(Text) function captionText() {
  .fontSize(AppTypography.CAPTION.size)
  .fontWeight(AppTypography.CAPTION.weight)
  .fontColor($r('app.color.color_text_tertiary'))
  .lineHeight(AppTypography.CAPTION.lineHeight)
}

@Extend(Text) function labelText() {
  .fontSize(AppTypography.LABEL.size)
  .fontWeight(AppTypography.LABEL.weight)
  .fontColor($r('app.color.color_text_secondary'))
  .lineHeight(AppTypography.LABEL.lineHeight)
}

@Extend(TextInput) function inputField() {
  .backgroundColor($r('app.color.color_surface'))
  .borderRadius(AppBorderRadius.MD)
  .fontSize(AppTypography.BODY_MEDIUM.size)
  .fontColor($r('app.color.color_text_primary'))
  .placeholderColor($r('app.color.color_text_tertiary'))
  .height(44)
  .padding({ left: AppSpacing.LG, right: AppSpacing.LG })
  .border({
    width: 1,
    color: $r('app.color.color_border')
  })
}

@Extend(Row) function dividerLine() {
  .backgroundColor($r('app.color.color_divider'))
  .height(1)
  .width('100%')
}

@Extend(Text) function responsiveTextSmall() {
  .fontColor($r('app.color.color_text_primary'))
  .fontSize(AppTypography.BODY_SMALL.size)
  .fontWeight(AppTypography.BODY_SMALL.weight)
  .lineHeight(AppTypography.BODY_SMALL.lineHeight)
}

@Extend(Text) function responsiveTextMedium() {
  .fontColor($r('app.color.color_text_primary'))
  .fontSize(AppTypography.BODY_MEDIUM.size)
  .fontWeight(AppTypography.BODY_MEDIUM.weight)
  .lineHeight(AppTypography.BODY_MEDIUM.lineHeight)
}

@Extend(Text) function responsiveTextLarge() {
  .fontColor($r('app.color.color_text_primary'))
  .fontSize(AppTypography.BODY_LARGE.size)
  .fontWeight(AppTypography.BODY_LARGE.weight)
  .lineHeight(AppTypography.BODY_LARGE.lineHeight)
}

@Extend(Row) function responsiveRow() {
  .width('100%')
  .padding({
    left: AppSpacing.XL,
    right: AppSpacing.XL
  })
  .alignItems(VerticalAlign.Center)
  .justifyContent(FlexAlign.SpaceBetween)
}

@Extend(Column) function screenContainer() {
  .width('100%')
  .height('100%')
  .backgroundColor($r('app.color.color_background'))
}

@Extend(Row) function headerRow() {
  .width('100%')
  .padding({
    left: AppSpacing.XL,
    right: AppSpacing.XL,
    top: AppSpacing.LG,
    bottom: AppSpacing.LG
  })
  .backgroundColor($r('app.color.color_surface'))
  .alignItems(VerticalAlign.Center)
}

export {
  primaryButton,
  secondaryButton,
  textButton,
  dangerButton,
  cardStyle,
  surfaceCard,
  elevatedCard,
  titleText,
  subtitleText,
  bodyText,
  captionText,
  labelText,
  inputField,
  dividerLine,
  responsiveTextSmall,
  responsiveTextMedium,
  responsiveTextLarge,
  responsiveRow,
  screenContainer,
  headerRow
};
