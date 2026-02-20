/**
 * 设计系统常量
 * 提供统一的视觉、间距、颜色、字体规范
 */

// 接口定义 - 必须在使用前定义
export interface CardStyle {
  backgroundColor: string;
  borderRadius: number;
  borderWidth: number;
  borderColor: string;
  shadow: string;
  padding: number;
}

export interface PaddingConfig {
  left: number;
  right: number;
  top: number;
  bottom: number;
}

export interface ButtonStyle {
  backgroundColor: string;
  textColor: string;
  borderRadius: number;
  padding: PaddingConfig;
  fontSize: number;
  fontWeight: number;
}

export interface InputStyle {
  backgroundColor: string;
  textColor: string;
  placeholderColor: string;
  borderColor: string;
  focusBorderColor: string;
  borderRadius: number;
  borderWidth: number;
  padding: PaddingConfig;
  fontSize: number;
}

export interface ColorVariant {
  light: string;
  dark: string;
}

export interface StatusColorsConfig {
  success: ColorVariant;
  warning: ColorVariant;
  error: ColorVariant;
  info: ColorVariant;
}

export interface ShadowVariant {
  light: string;
  dark: string;
}

export interface ShadowsConfig {
  sm: ShadowVariant;
  md: ShadowVariant;
  lg: ShadowVariant;
  xl: ShadowVariant;
}

export interface AnimationDurationConfig {
  instant: number;
  fast: number;
  normal: number;
  slow: number;
  slower: number;
}

export interface AnimationCurveConfig {
  easeIn: string;
  easeOut: string;
  easeInOut: string;
  linear: string;
  spring: string;
}

export interface ZIndexConfig {
  base: number;
  dropdown: number;
  sticky: number;
  modal: number;
  popover: number;
  toast: number;
  tooltip: number;
}

export interface AccessibilityConfig {
  minTouchTarget: number;
  minContrastRatio: number;
  focusRingWidth: number;
  focusRingOffset: number;
}

export interface IconSizeConfig {
  xs: number;
  sm: number;
  md: number;
  lg: number;
  xl: number;
  xxl: number;
}

// 颜色主题类
class ColorTheme {
  light: string = '';
  dark: string = '';

  constructor(light: string, dark: string) {
    this.light = light;
    this.dark = dark;
  }
}

// 文本颜色类
class TextColors {
  primary: ColorTheme = new ColorTheme('', '');
  secondary: ColorTheme = new ColorTheme('', '');
  tertiary: ColorTheme = new ColorTheme('', '');

  constructor(primary: ColorTheme, secondary: ColorTheme, tertiary: ColorTheme) {
    this.primary = primary;
    this.secondary = secondary;
    this.tertiary = tertiary;
  }
}

// 背景颜色类
class BackgroundColors {
  primary: ColorTheme = new ColorTheme('', '');
  secondary: ColorTheme = new ColorTheme('', '');
  tertiary: ColorTheme = new ColorTheme('', '');

  constructor(primary: ColorTheme, secondary: ColorTheme, tertiary: ColorTheme) {
    this.primary = primary;
    this.secondary = secondary;
    this.tertiary = tertiary;
  }
}

// 边框颜色类
class BorderColors {
  light: string = '';
  dark: string = '';

  constructor(light: string, dark: string) {
    this.light = light;
    this.dark = dark;
  }
}

// 状态颜色类
class StateColors {
  hover: ColorTheme = new ColorTheme('', '');
  active: ColorTheme = new ColorTheme('', '');
  focus: ColorTheme = new ColorTheme('', '');

  constructor(hover: ColorTheme, active: ColorTheme, focus: ColorTheme) {
    this.hover = hover;
    this.active = active;
    this.focus = focus;
  }
}

// 颜色配置类
class ColorsConfig {
  primary: ColorTheme = new ColorTheme('', '');
  text: TextColors = new TextColors(new ColorTheme('', ''), new ColorTheme('', ''), new ColorTheme('', ''));
  background: BackgroundColors = new BackgroundColors(new ColorTheme('', ''), new ColorTheme('', ''), new ColorTheme('', ''));
  border: BorderColors = new BorderColors('', '');
  state: StateColors = new StateColors(new ColorTheme('', ''), new ColorTheme('', ''), new ColorTheme('', ''));

  constructor(
    primary: ColorTheme,
    text: TextColors,
    background: BackgroundColors,
    border: BorderColors,
    state: StateColors
  ) {
    this.primary = primary;
    this.text = text;
    this.background = background;
    this.border = border;
    this.state = state;
  }
}

// 间距配置类
class SpacingConfig {
  xs: number = 0;
  sm: number = 0;
  md: number = 0;
  lg: number = 0;
  xl: number = 0;
  xxl: number = 0;
  xxxl: number = 0;
  xxxxl: number = 0;

  constructor(xs: number, sm: number, md: number, lg: number, xl: number, xxl: number, xxxl: number, xxxxl: number) {
    this.xs = xs;
    this.sm = sm;
    this.md = md;
    this.lg = lg;
    this.xl = xl;
    this.xxl = xxl;
    this.xxxl = xxxl;
    this.xxxxl = xxxxl;
  }
}

// 字体大小类
class FontSizeConfig {
  xs: number = 0;
  sm: number = 0;
  base: number = 0;
  lg: number = 0;
  xl: number = 0;
  xxl: number = 0;
  xxxl: number = 0;

  constructor(xs: number, sm: number, base: number, lg: number, xl: number, xxl: number, xxxl: number) {
    this.xs = xs;
    this.sm = sm;
    this.base = base;
    this.lg = lg;
    this.xl = xl;
    this.xxl = xxl;
    this.xxxl = xxxl;
  }
}

// 字重类
class FontWeightConfig {
  light: number = 0;
  regular: number = 0;
  medium: number = 0;
  semibold: number = 0;
  bold: number = 0;

  constructor(light: number, regular: number, medium: number, semibold: number, bold: number) {
    this.light = light;
    this.regular = regular;
    this.medium = medium;
    this.semibold = semibold;
    this.bold = bold;
  }
}

// 行高类
class LineHeightConfig {
  tight: number = 0;
  normal: number = 0;
  relaxed: number = 0;
  loose: number = 0;

  constructor(tight: number, normal: number, relaxed: number, loose: number) {
    this.tight = tight;
    this.normal = normal;
    this.relaxed = relaxed;
    this.loose = loose;
  }
}

// 字体配置类
class TypographyConfig {
  size: FontSizeConfig = new FontSizeConfig(0, 0, 0, 0, 0, 0, 0);
  weight: FontWeightConfig = new FontWeightConfig(0, 0, 0, 0, 0);
  lineHeight: LineHeightConfig = new LineHeightConfig(0, 0, 0, 0);

  constructor(size: FontSizeConfig, weight: FontWeightConfig, lineHeight: LineHeightConfig) {
    this.size = size;
    this.weight = weight;
    this.lineHeight = lineHeight;
  }
}

// 圆角配置类
class BorderRadiusConfig {
  none: number = 0;
  sm: number = 0;
  md: number = 0;
  lg: number = 0;
  xl: number = 0;
  full: number = 0;

  constructor(none: number, sm: number, md: number, lg: number, xl: number, full: number) {
    this.none = none;
    this.sm = sm;
    this.md = md;
    this.lg = lg;
    this.xl = xl;
    this.full = full;
  }
}

// 断点配置类
class BreakpointsConfig {
  xs: number = 0;
  sm: number = 0;
  md: number = 0;
  lg: number = 0;
  xl: number = 0;

  constructor(xs: number, sm: number, md: number, lg: number, xl: number) {
    this.xs = xs;
    this.sm = sm;
    this.md = md;
    this.lg = lg;
    this.xl = xl;
  }
}

// 响应式值类
class ResponsiveValue<T> {
  xs: T;
  sm: T;
  md: T;
  lg: T;
  xl: T;

  constructor(xs: T, sm: T, md: T, lg: T, xl: T) {
    this.xs = xs;
    this.sm = sm;
    this.md = md;
    this.lg = lg;
    this.xl = xl;
  }
}

export class DesignSystem {
  // 颜色系统
  static readonly Colors: ColorsConfig = new ColorsConfig(
    // 主色调
    new ColorTheme('#8B6914', '#d4b483'),
    // 文本颜色
    new TextColors(
      new ColorTheme('#333333', '#e0d8c9'),
      new ColorTheme('#666666', '#8a7f6e'),
      new ColorTheme('#999999', '#5a5a5a')
    ),
    // 背景颜色
    new BackgroundColors(
      new ColorTheme('#F5F1E6', '#1a1a1a'),
      new ColorTheme('#F0EAD6', '#2a2a2a'),
      new ColorTheme('#FFFFFF', '#1e1e1e')
    ),
    // 边框颜色
    new BorderColors('#E0E0E0', '#2a2a2a'),
    // 状态颜色
    new StateColors(
      new ColorTheme('#F8F4E9', '#2f2f2f'),
      new ColorTheme('#EDE8D9', '#3a3a3a'),
      new ColorTheme('#E6E1D2', '#444444')
    )
  );

  // 间距系统 (8px为基准)
  static readonly Spacing: SpacingConfig = new SpacingConfig(
    4,    // xs: 4px
    8,    // sm: 8px
    12,   // md: 12px
    16,   // lg: 16px
    20,   // xl: 20px
    24,   // xxl: 24px
    32,   // xxxl: 32px
    40    // xxxxl: 40px
  );

  // 字体系统
  static readonly Typography: TypographyConfig = new TypographyConfig(
    // 字号
    new FontSizeConfig(
      12,   // xs: 辅助文字
      14,   // sm: 正文/描述
      16,   // base: 正文
      18,   // lg: 小标题
      20,   // xl: 标题
      24,   // xxl: 大标题
      28    // xxxl: 超大标题
    ),
    // 字重
    new FontWeightConfig(
      300,  // light
      400,  // regular
      500,  // medium
      600,  // semibold
      700   // bold
    ),
    // 行高
    new LineHeightConfig(
      1.2,  // tight
      1.4,  // normal
      1.6,  // relaxed
      1.8   // loose
    )
  );

  // 圆角系统
  static readonly BorderRadius: BorderRadiusConfig = new BorderRadiusConfig(
    0,    // none
    4,    // sm
    8,    // md
    12,   // lg
    16,   // xl
    999   // full
  );

  // 断点系统
  static readonly Breakpoints: BreakpointsConfig = new BreakpointsConfig(
    320,  // xs: 小屏手机
    375,  // sm: 标准手机
    414,  // md: 大屏手机
    768,  // lg: 平板
    1024  // xl: 小桌面
  );

  // 响应式工具函数
  static getResponsiveValue<T>(values: ResponsiveValue<T>, screenWidth: number): T {
    if (screenWidth >= DesignSystem.Breakpoints.xl) {
      return values.xl;
    }
    if (screenWidth >= DesignSystem.Breakpoints.lg) {
      return values.lg;
    }
    if (screenWidth >= DesignSystem.Breakpoints.md) {
      return values.md;
    }
    if (screenWidth >= DesignSystem.Breakpoints.sm) {
      return values.sm;
    }
    return values.xs;
  }

  // 获取主色调
  static getPrimaryColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.Colors.primary.light : DesignSystem.Colors.primary.dark;
  }

  // 获取边框颜色
  static getBorderColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.Colors.border.light : DesignSystem.Colors.border.dark;
  }

  // 获取文本颜色
  static getPrimaryTextColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.Colors.text.primary.light : DesignSystem.Colors.text.primary.dark;
  }

  static getSecondaryTextColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.Colors.text.secondary.light : DesignSystem.Colors.text.secondary.dark;
  }

  static getTertiaryTextColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.Colors.text.tertiary.light : DesignSystem.Colors.text.tertiary.dark;
  }

  // 获取背景颜色
  static getPrimaryBackgroundColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.Colors.background.primary.light : DesignSystem.Colors.background.primary.dark;
  }

  static getSecondaryBackgroundColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.Colors.background.secondary.light : DesignSystem.Colors.background.secondary.dark;
  }

  static getTertiaryBackgroundColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.Colors.background.tertiary.light : DesignSystem.Colors.background.tertiary.dark;
  }

  // 获取状态颜色
  static getHoverColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.Colors.state.hover.light : DesignSystem.Colors.state.hover.dark;
  }

  static getActiveColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.Colors.state.active.light : DesignSystem.Colors.state.active.dark;
  }

  static getFocusColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.Colors.state.focus.light : DesignSystem.Colors.state.focus.dark;
  }

  // 状态颜色
  static readonly StatusColors: StatusColorsConfig = {
    success: { light: '#4CAF50', dark: '#66BB6A' } as ColorVariant,
    warning: { light: '#FF9800', dark: '#FFB74D' } as ColorVariant,
    error: { light: '#F44336', dark: '#EF5350' } as ColorVariant,
    info: { light: '#2196F3', dark: '#42A5F5' } as ColorVariant
  };

  static getSuccessColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.StatusColors.success.light : DesignSystem.StatusColors.success.dark;
  }

  static getWarningColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.StatusColors.warning.light : DesignSystem.StatusColors.warning.dark;
  }

  static getErrorColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.StatusColors.error.light : DesignSystem.StatusColors.error.dark;
  }

  static getInfoColor(isLightMode: boolean): string {
    return isLightMode ? DesignSystem.StatusColors.info.light : DesignSystem.StatusColors.info.dark;
  }

  // 阴影系统
  static readonly Shadows: ShadowsConfig = {
    sm: { light: '0 1px 2px rgba(0, 0, 0, 0.05)', dark: '0 1px 2px rgba(0, 0, 0, 0.3)' } as ShadowVariant,
    md: { light: '0 4px 6px rgba(0, 0, 0, 0.07)', dark: '0 4px 6px rgba(0, 0, 0, 0.4)' } as ShadowVariant,
    lg: { light: '0 10px 15px rgba(0, 0, 0, 0.1)', dark: '0 10px 15px rgba(0, 0, 0, 0.5)' } as ShadowVariant,
    xl: { light: '0 20px 25px rgba(0, 0, 0, 0.15)', dark: '0 20px 25px rgba(0, 0, 0, 0.6)' } as ShadowVariant
  };

  // 动画时长
  static readonly AnimationDuration: AnimationDurationConfig = {
    instant: 0,
    fast: 100,
    normal: 200,
    slow: 300,
    slower: 500
  };

  // 动画曲线
  static readonly AnimationCurve: AnimationCurveConfig = {
    easeIn: 'ease-in',
    easeOut: 'ease-out',
    easeInOut: 'ease-in-out',
    linear: 'linear',
    spring: 'spring(1, 100, 10, 0)'
  };

  // Z-Index层级
  static readonly ZIndex: ZIndexConfig = {
    base: 0,
    dropdown: 100,
    sticky: 200,
    modal: 300,
    popover: 400,
    toast: 500,
    tooltip: 600
  };

  // 无障碍访问 - 最小触摸目标尺寸
  static readonly Accessibility: AccessibilityConfig = {
    minTouchTarget: 44,
    minContrastRatio: 4.5,
    focusRingWidth: 2,
    focusRingOffset: 2
  };

  // 图标尺寸
  static readonly IconSize: IconSizeConfig = {
    xs: 12,
    sm: 16,
    md: 20,
    lg: 24,
    xl: 32,
    xxl: 48
  };

  // 卡片样式
  static getCardStyle(isLightMode: boolean): CardStyle {
    return {
      backgroundColor: DesignSystem.getSecondaryBackgroundColor(isLightMode),
      borderRadius: DesignSystem.BorderRadius.lg,
      borderWidth: 1,
      borderColor: DesignSystem.getBorderColor(isLightMode),
      shadow: isLightMode ? DesignSystem.Shadows.sm.light : DesignSystem.Shadows.sm.dark,
      padding: DesignSystem.Spacing.lg
    };
  }

  // 按钮样式
  static getButtonStyle(isLightMode: boolean, variant: 'primary' | 'secondary' | 'ghost' = 'primary'): ButtonStyle {
    const padding: PaddingConfig = {
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: DesignSystem.Spacing.sm,
      bottom: DesignSystem.Spacing.sm
    };
    
    switch (variant) {
      case 'primary':
        const primaryStyle: ButtonStyle = {
          backgroundColor: DesignSystem.getPrimaryColor(isLightMode),
          textColor: '#FFFFFF',
          borderRadius: DesignSystem.BorderRadius.md,
          padding: padding,
          fontSize: DesignSystem.Typography.size.sm,
          fontWeight: DesignSystem.Typography.weight.medium
        };
        return primaryStyle;
      case 'secondary':
        const secondaryStyle: ButtonStyle = {
          backgroundColor: DesignSystem.getSecondaryBackgroundColor(isLightMode),
          textColor: DesignSystem.getPrimaryTextColor(isLightMode),
          borderRadius: DesignSystem.BorderRadius.md,
          padding: padding,
          fontSize: DesignSystem.Typography.size.sm,
          fontWeight: DesignSystem.Typography.weight.medium
        };
        return secondaryStyle;
      case 'ghost':
        const ghostStyle: ButtonStyle = {
          backgroundColor: 'transparent',
          textColor: DesignSystem.getPrimaryColor(isLightMode),
          borderRadius: DesignSystem.BorderRadius.md,
          padding: padding,
          fontSize: DesignSystem.Typography.size.sm,
          fontWeight: DesignSystem.Typography.weight.medium
        };
        return ghostStyle;
    }
  }

  // 输入框样式
  static getInputStyle(isLightMode: boolean): InputStyle {
    const padding: PaddingConfig = {
      left: DesignSystem.Spacing.md,
      right: DesignSystem.Spacing.md,
      top: DesignSystem.Spacing.sm,
      bottom: DesignSystem.Spacing.sm
    };
    
    const inputStyle: InputStyle = {
      backgroundColor: DesignSystem.getTertiaryBackgroundColor(isLightMode),
      textColor: DesignSystem.getPrimaryTextColor(isLightMode),
      placeholderColor: DesignSystem.getTertiaryTextColor(isLightMode),
      borderColor: DesignSystem.getBorderColor(isLightMode),
      focusBorderColor: DesignSystem.getPrimaryColor(isLightMode),
      borderRadius: DesignSystem.BorderRadius.md,
      borderWidth: 1,
      padding: padding,
      fontSize: DesignSystem.Typography.size.base
    };
    return inputStyle;
  }
}
