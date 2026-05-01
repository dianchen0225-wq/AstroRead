/**
 * HomeTokens - 首页语义化设计令牌
 * 扩展 DesignSystem 基础令牌，定义首页专用的视觉规范
 * 包含快捷操作区、功能菜单区、品牌标题区、低饱和渐变色配置
 */

import { DesignSystem, GradientVariant } from './DesignSystem';

interface QuickActionConfig {
  iconSize: number;
  iconContainerSize: number;
  labelSize: number;
}

interface FeatureMenuConfig {
  itemHeight: number;
  iconContainerSize: number;
  arrowSize: number;
}

interface BrandTitleConfig {
  fontSize: number;
  letterSpacing: number;
  subtitleSize: number;
}

interface HomeGradientsConfig {
  bookshelf: GradientVariant;
  search: GradientVariant;
  source: GradientVariant;
  settings: GradientVariant;
}

export class HomeTokens {
  static readonly QuickAction: QuickActionConfig = {
    iconSize: DesignSystem.IconSize.lg,
    iconContainerSize: 52,
    labelSize: DesignSystem.Typography.size.xs,
  };

  static readonly FeatureMenu: FeatureMenuConfig = {
    itemHeight: 76,
    iconContainerSize: 48,
    arrowSize: 32,
  };

  static readonly BrandTitle: BrandTitleConfig = {
    fontSize: DesignSystem.Typography.size.xxxl,
    letterSpacing: 4,
    subtitleSize: DesignSystem.Typography.size.sm,
  };

  // 低饱和渐变色配置 - 适配阅读场景的柔和配色
  // 浅色模式基于金棕色系衍生，深色模式自动提亮
  static readonly Gradients: HomeGradientsConfig = {
    bookshelf: {
      light: [['#8B7355', 0], ['#A0896C', 1]],
      dark: [['#C4A882', 0], ['#D4BC9A', 1]]
    },
    search: {
      light: [['#7B6B8A', 0], ['#8E7B9E', 1]],
      dark: [['#A898B8', 0], ['#BCA8CC', 1]]
    },
    source: {
      light: [['#5B7B8A', 0], ['#6E8E9E', 1]],
      dark: [['#88A8B8', 0], ['#9CBCCE', 1]]
    },
    settings: {
      light: [['#6B8B6B', 0], ['#7E9E7E', 1]],
      dark: [['#98B898', 0], ['#ACCCAC', 1]]
    }
  };

  // 获取指定菜单项的渐变色
  static getGradientColors(key: string, isLightMode: boolean): Array<[string, number]> {
    let gradient: GradientVariant | undefined = undefined;
    if (key === 'bookshelf') {
      gradient = HomeTokens.Gradients.bookshelf;
    } else if (key === 'search') {
      gradient = HomeTokens.Gradients.search;
    } else if (key === 'source') {
      gradient = HomeTokens.Gradients.source;
    } else if (key === 'settings') {
      gradient = HomeTokens.Gradients.settings;
    }
    if (gradient) {
      return isLightMode ? gradient.light : gradient.dark;
    }
    const fallback = HomeTokens.Gradients.bookshelf;
    return isLightMode ? fallback.light : fallback.dark;
  }

  // 获取渐变起始色（用于阴影装饰）
  static getGradientStartColor(key: string, isLightMode: boolean): string {
    const colors = HomeTokens.getGradientColors(key, isLightMode);
    return colors.length > 0 ? colors[0][0] : '#8B7355';
  }
}
