/**
 * 响应式工具类
 * 支持不同屏幕尺寸的自适应布局
 */

// 响应式断点定义
export enum Breakpoint {
  XS = 320,   // 超小屏幕
  SM = 576,   // 小屏幕
  MD = 768,   // 中等屏幕
  LG = 992,   // 大屏幕
  XL = 1200,  // 超大屏幕
  XXL = 1400  // 超超大屏幕
}

// 设备类型
export enum DeviceType {
  PHONE = 'phone',
  TABLET = 'tablet',
  FOLDABLE = 'foldable'
}

// 布局配置接口
export interface LayoutConfig {
  columns: number;
  gap: number;
  padding: number;
}

// 边距配置接口
export interface MarginConfig {
  top?: number;
  bottom?: number;
  left?: number;
  right?: number;
}

// 内边距配置接口
export interface PaddingConfig {
  top?: number;
  bottom?: number;
  left?: number;
  right?: number;
}

// 响应式工具类
export class ResponsiveUtils {
  
  // 获取当前屏幕宽度
  static getScreenWidth(): number {
    // 实际项目中应该从系统API获取
    // 这里使用默认值，实际应该动态获取
    return 360; // 默认手机宽度
  }
  
  // 获取当前断点
  static getCurrentBreakpoint(): Breakpoint {
    const width = ResponsiveUtils.getScreenWidth();
    if (width < Breakpoint.SM) return Breakpoint.XS;
    if (width < Breakpoint.MD) return Breakpoint.SM;
    if (width < Breakpoint.LG) return Breakpoint.MD;
    if (width < Breakpoint.XL) return Breakpoint.LG;
    if (width < Breakpoint.XXL) return Breakpoint.XL;
    return Breakpoint.XXL;
  }
  
  // 获取设备类型
  static getDeviceType(): DeviceType {
    const width = ResponsiveUtils.getScreenWidth();
    if (width < Breakpoint.MD) return DeviceType.PHONE;
    if (width < Breakpoint.XL) return DeviceType.TABLET;
    return DeviceType.FOLDABLE;
  }
  
  // 根据断点获取列数
  static getGridColumns(): number {
    const breakpoint = ResponsiveUtils.getCurrentBreakpoint();
    switch (breakpoint) {
      case Breakpoint.XS: return 1;
      case Breakpoint.SM: return 2;
      case Breakpoint.MD: return 2;
      case Breakpoint.LG: return 3;
      case Breakpoint.XL: return 4;
      case Breakpoint.XXL: return 5;
      default: return 2;
    }
  }
  
  // 根据断点获取字体大小
  static getFontSize(baseSize: number): number {
    const breakpoint = ResponsiveUtils.getCurrentBreakpoint();
    switch (breakpoint) {
      case Breakpoint.XS: return baseSize * 0.9;
      case Breakpoint.SM: return baseSize * 0.95;
      case Breakpoint.MD: return baseSize;
      case Breakpoint.LG: return baseSize * 1.1;
      case Breakpoint.XL: return baseSize * 1.2;
      case Breakpoint.XXL: return baseSize * 1.3;
      default: return baseSize;
    }
  }
  
  // 根据断点获取间距
  static getSpacing(baseSpacing: number): number {
    const breakpoint = ResponsiveUtils.getCurrentBreakpoint();
    switch (breakpoint) {
      case Breakpoint.XS: return baseSpacing * 0.8;
      case Breakpoint.SM: return baseSpacing * 0.9;
      case Breakpoint.MD: return baseSpacing;
      case Breakpoint.LG: return baseSpacing * 1.1;
      case Breakpoint.XL: return baseSpacing * 1.2;
      case Breakpoint.XXL: return baseSpacing * 1.3;
      default: return baseSpacing;
    }
  }
  
  // 响应式布局配置
  static getLayoutConfig(): LayoutConfig {
    const breakpoint = ResponsiveUtils.getCurrentBreakpoint();
    switch (breakpoint) {
      case Breakpoint.XS:
        return { columns: 1, gap: 12, padding: 16 };
      case Breakpoint.SM:
        return { columns: 2, gap: 16, padding: 20 };
      case Breakpoint.MD:
        return { columns: 2, gap: 20, padding: 24 };
      case Breakpoint.LG:
        return { columns: 3, gap: 24, padding: 28 };
      case Breakpoint.XL:
        return { columns: 4, gap: 28, padding: 32 };
      case Breakpoint.XXL:
        return { columns: 5, gap: 32, padding: 36 };
      default:
        return { columns: 2, gap: 20, padding: 24 };
    }
  }
  
  // 是否为平板或更大设备
  static isTabletOrLarger(): boolean {
    return ResponsiveUtils.getCurrentBreakpoint() >= Breakpoint.MD;
  }
  
  // 是否为手机设备
  static isPhone(): boolean {
    return ResponsiveUtils.getCurrentBreakpoint() < Breakpoint.MD;
  }
}

// 响应式属性构建器
export class ResponsiveBuilder {
  
  // 构建响应式字体大小
  static buildFontSize(baseSize: number): number {
    return ResponsiveUtils.getFontSize(baseSize);
  }
  
  // 构建响应式间距
  static buildSpacing(baseSpacing: number): number {
    return ResponsiveUtils.getSpacing(baseSpacing);
  }
  
  // 构建响应式网格模板
  static buildGridTemplate(): string {
    const columns = ResponsiveUtils.getGridColumns();
    return `repeat(${columns}, 1fr)`;
  }
  
  // 构建响应式边距
  static buildMargin(baseMargin: number): MarginConfig {
    const margin = ResponsiveUtils.getSpacing(baseMargin);
    return {
      top: margin,
      bottom: margin,
      left: margin,
      right: margin
    };
  }
  
  // 构建响应式内边距
  static buildPadding(basePadding: number): PaddingConfig {
    const padding = ResponsiveUtils.getSpacing(basePadding);
    return {
      top: padding,
      bottom: padding,
      left: padding,
      right: padding
    };
  }
}