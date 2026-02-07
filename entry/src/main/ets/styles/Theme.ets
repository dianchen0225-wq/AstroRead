/**
 * 主题系统配置
 * 支持亮色/暗黑模式，统一管理所有UI样式
 */

// 主题类型
export enum ThemeType {
  LIGHT = 'light',
  DARK = 'dark'
}

// 字体配置接口
export interface FontConfig {
  size: number;
  weight: FontWeight;
  lineHeight: number;
}

// 阴影配置接口
export interface ShadowConfig {
  radius: number;
  color: string;
  offsetX: number;
  offsetY: number;
}

// 动画配置接口
export interface AnimationConfig {
  duration: number;
  curve: Curve;
}

// 颜色系统
export class AppColors {
  // 主色调
  static readonly PRIMARY = '#007AFF';
  static readonly PRIMARY_LIGHT = '#66B3FF';
  static readonly PRIMARY_DARK = '#0056CC';
  
  // 语义色
  static readonly SUCCESS = '#34C759';
  static readonly WARNING = '#FF9500';
  static readonly ERROR = '#FF3B30';
  static readonly INFO = '#5AC8FA';
  
  // 中性色 - 亮色主题
  static readonly LIGHT_BACKGROUND = '#FFFFFF';
  static readonly LIGHT_SURFACE = '#F8F8F8';
  static readonly LIGHT_CARD = '#FFFFFF';
  static readonly LIGHT_TEXT_PRIMARY = '#333333';
  static readonly LIGHT_TEXT_SECONDARY = '#666666';
  static readonly LIGHT_TEXT_TERTIARY = '#999999';
  static readonly LIGHT_BORDER = '#E5E5E5';
  
  // 中性色 - 暗黑主题
  static readonly DARK_BACKGROUND = '#1C1C1E';
  static readonly DARK_SURFACE = '#2C2C2E';
  static readonly DARK_CARD = '#3A3A3C';
  static readonly DARK_TEXT_PRIMARY = '#FFFFFF';
  static readonly DARK_TEXT_SECONDARY = '#EBEBF5';
  static readonly DARK_TEXT_TERTIARY = '#98989D';
  static readonly DARK_BORDER = '#38383A';
}

// 字体系统
export class AppTypography {
  static readonly H1: FontConfig = { size: 32, weight: FontWeight.Bold, lineHeight: 40 };
  static readonly H2: FontConfig = { size: 28, weight: FontWeight.Bold, lineHeight: 36 };
  static readonly H3: FontConfig = { size: 24, weight: FontWeight.Bold, lineHeight: 32 };
  static readonly H4: FontConfig = { size: 20, weight: FontWeight.Bold, lineHeight: 28 };
  static readonly H5: FontConfig = { size: 18, weight: FontWeight.Bold, lineHeight: 24 };
  static readonly H6: FontConfig = { size: 16, weight: FontWeight.Bold, lineHeight: 22 };
  
  static readonly BODY_LARGE: FontConfig = { size: 18, weight: FontWeight.Normal, lineHeight: 26 };
  static readonly BODY_MEDIUM: FontConfig = { size: 16, weight: FontWeight.Normal, lineHeight: 24 };
  static readonly BODY_SMALL: FontConfig = { size: 14, weight: FontWeight.Normal, lineHeight: 20 };
  static readonly BODY_XSMALL: FontConfig = { size: 12, weight: FontWeight.Normal, lineHeight: 16 };
  
  static readonly CAPTION: FontConfig = { size: 12, weight: FontWeight.Medium, lineHeight: 16 };
  static readonly OVERLINE: FontConfig = { size: 10, weight: FontWeight.Medium, lineHeight: 14 };
}

// 间距系统
export class AppSpacing {
  static readonly XS = 4;
  static readonly SM = 8;
  static readonly MD = 16;
  static readonly LG = 24;
  static readonly XL = 32;
  static readonly XXL = 48;
}

// 圆角系统
export class AppBorderRadius {
  static readonly SM = 4;
  static readonly MD = 8;
  static readonly LG = 12;
  static readonly XL = 16;
  static readonly FULL = 999;
}

// 阴影系统
export class AppShadows {
  static readonly SM: ShadowConfig = {
    radius: 2,
    color: 'rgba(0, 0, 0, 0.05)',
    offsetX: 0,
    offsetY: 1
  };
  
  static readonly MD: ShadowConfig = {
    radius: 4,
    color: 'rgba(0, 0, 0, 0.1)',
    offsetX: 0,
    offsetY: 2
  };
  
  static readonly LG: ShadowConfig = {
    radius: 8,
    color: 'rgba(0, 0, 0, 0.15)',
    offsetX: 0,
    offsetY: 4
  };
  
  static readonly XL: ShadowConfig = {
    radius: 16,
    color: 'rgba(0, 0, 0, 0.2)',
    offsetX: 0,
    offsetY: 8
  };
}

// 动画系统
export class AppAnimations {
  static readonly FAST: AnimationConfig = { duration: 150, curve: Curve.EaseOut };
  static readonly NORMAL: AnimationConfig = { duration: 300, curve: Curve.EaseOut };
  static readonly SLOW: AnimationConfig = { duration: 500, curve: Curve.EaseOut };
  static readonly SPRING: AnimationConfig = { duration: 400, curve: Curve.Ease };
}

// 主题配置类
export class AppTheme {
  type: ThemeType;
  colors: AppColors;
  typography: AppTypography;
  spacing: AppSpacing;
  borderRadius: AppBorderRadius;
  shadows: AppShadows;
  animations: AppAnimations;

  constructor(type: ThemeType) {
    this.type = type;
    this.colors = new AppColors();
    this.typography = new AppTypography();
    this.spacing = new AppSpacing();
    this.borderRadius = new AppBorderRadius();
    this.shadows = new AppShadows();
    this.animations = new AppAnimations();
  }
  
  // 获取当前主题的颜色
  get backgroundColor(): string {
    return this.type === ThemeType.LIGHT 
      ? AppColors.LIGHT_BACKGROUND 
      : AppColors.DARK_BACKGROUND;
  }
  
  get surfaceColor(): string {
    return this.type === ThemeType.LIGHT 
      ? AppColors.LIGHT_SURFACE 
      : AppColors.DARK_SURFACE;
  }
  
  get cardColor(): string {
    return this.type === ThemeType.LIGHT 
      ? AppColors.LIGHT_CARD 
      : AppColors.DARK_CARD;
  }
  
  get textPrimary(): string {
    return this.type === ThemeType.LIGHT 
      ? AppColors.LIGHT_TEXT_PRIMARY 
      : AppColors.DARK_TEXT_PRIMARY;
  }
  
  get textSecondary(): string {
    return this.type === ThemeType.LIGHT 
      ? AppColors.LIGHT_TEXT_SECONDARY 
      : AppColors.DARK_TEXT_SECONDARY;
  }
  
  get textTertiary(): string {
    return this.type === ThemeType.LIGHT 
      ? AppColors.LIGHT_TEXT_TERTIARY 
      : AppColors.DARK_TEXT_TERTIARY;
  }
  
  get borderColor(): string {
    return this.type === ThemeType.LIGHT 
      ? AppColors.LIGHT_BORDER 
      : AppColors.DARK_BORDER;
  }
}

// 默认主题配置
export const LightTheme = new AppTheme(ThemeType.LIGHT);
export const DarkTheme = new AppTheme(ThemeType.DARK);