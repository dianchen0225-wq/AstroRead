import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';
import {
  LiquidGlassConfig,
  LiquidGlassPreset,
  LiquidGlassAnimator,
  LiquidGlassPerformanceMonitor,
  LiquidGlassUtils,
  getOptimalGlassConfig
} from '../utils/effects/LiquidGlassConfig';
import {
  cancelAnimationFrame
} from '../utils/effects/HarmonyOSCompat';

export interface LiquidGlassStyle {
  backgroundColor: string;
  backdropBlur: number;
  opacity: number;
  borderRadius: number;
  borderWidth: number;
  borderColor: string;
  shadowRadius: number;
  shadowColor: string;
  shadowOffsetY: number;
}

export interface TouchFeedback {
  scale: number;
  opacity: number;
  rippleX: number;
  rippleY: number;
  rippleIntensity: number;
}

export interface SizeConfig {
  padding: number;
  fontSize: number;
  iconSize: number;
}

@ComponentV2
export struct LiquidGlassEffect {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  @Local isHovered: boolean = false;
  @Local isFocused: boolean = false;
  @Local currentScale: number = 1;
  @Local currentOpacity: number = 1;
  @Local currentBlur: number = 20;
  @Local glowIntensity: number = 0;
  @Local morphProgress: number = 0;

  @Param preset: 'default' | 'silk' | 'crystal' | 'water' | 'frosted' | 'amber' = 'default';
  @Param customConfig: Partial<LiquidGlassConfig> = {};
  @Param glassWidth: number | string = '100%';
  @Param glassHeight: number | string = 'auto';
  @Param glassPadding: number = DesignSystem.Spacing.lg;
  @Param glassMargin: number = 0;
  @Param glassBorderRadius: number = DesignSystem.BorderRadius.xl;
  @Param interactive: boolean = true;
  @Param hapticFeedback: boolean = true;
  @Param adaptivePerformance: boolean = true;
  @Param accessibilityLabel: string = '';
  @Param onClickCallback: () => void = () => {};

  @BuilderParam
  content: () => void;

  private animator: LiquidGlassAnimator | null = null;
  private performanceMonitor: LiquidGlassPerformanceMonitor = new LiquidGlassPerformanceMonitor();
  private config: LiquidGlassConfig = LiquidGlassPreset.DEFAULT;
  private lastTouchX: number = 0;
  private lastTouchY: number = 0;
  private animationFrameId: number = -1;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
    this.updateThemeAwareConfig();
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    this.initializeConfig();
    this.initializeAnimator();
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
    this.disposeAnimator();
  }

  private initializeConfig(): void {
    const presetConfigs: Record<string, LiquidGlassConfig> = {
      'default': LiquidGlassPreset.DEFAULT,
      'silk': LiquidGlassPreset.SILK,
      'crystal': LiquidGlassPreset.CRYSTAL,
      'water': LiquidGlassPreset.WATER,
      'frosted': LiquidGlassPreset.FROSTED,
      'amber': LiquidGlassPreset.AMBER
    };

    const baseConfig = presetConfigs[this.preset] || LiquidGlassPreset.DEFAULT;

    // 手动合并配置
    this.config = {
      fluidity: this.customConfig.fluidity ?? baseConfig.fluidity,
      viscosity: this.customConfig.viscosity ?? baseConfig.viscosity,
      surfaceTension: this.customConfig.surfaceTension ?? baseConfig.surfaceTension,
      transparency: this.customConfig.transparency ?? baseConfig.transparency,
      refractionIndex: this.customConfig.refractionIndex ?? baseConfig.refractionIndex,
      blurIntensity: this.customConfig.blurIntensity ?? baseConfig.blurIntensity,
      colorTint: this.customConfig.colorTint ?? baseConfig.colorTint,
      rippleEnabled: this.customConfig.rippleEnabled ?? baseConfig.rippleEnabled,
      rippleIntensity: this.customConfig.rippleIntensity ?? baseConfig.rippleIntensity,
      rippleDecay: this.customConfig.rippleDecay ?? baseConfig.rippleDecay,
      morphEnabled: this.customConfig.morphEnabled ?? baseConfig.morphEnabled,
      morphSpeed: this.customConfig.morphSpeed ?? baseConfig.morphSpeed,
      morphAmplitude: this.customConfig.morphAmplitude ?? baseConfig.morphAmplitude,
      glowEnabled: this.customConfig.glowEnabled ?? baseConfig.glowEnabled,
      glowIntensity: this.customConfig.glowIntensity ?? baseConfig.glowIntensity,
      glowColor: this.customConfig.glowColor ?? baseConfig.glowColor,
      shadowSoftness: this.customConfig.shadowSoftness ?? baseConfig.shadowSoftness,
      animationFrameRate: this.customConfig.animationFrameRate ?? baseConfig.animationFrameRate,
      reducedMotion: this.customConfig.reducedMotion ?? baseConfig.reducedMotion
    };

    this.config = LiquidGlassPreset.getThemeAwareConfig(this.config, this.isLightMode);

    if (this.adaptivePerformance) {
      const stats = this.performanceMonitor.getStats();
      this.config = getOptimalGlassConfig(this.config, stats.recommendedQuality);
    }

    this.currentBlur = this.config.blurIntensity;
    this.currentOpacity = this.config.transparency;
    this.glowIntensity = this.config.glowIntensity;
  }

  private initializeAnimator(): void {
    this.animator = new LiquidGlassAnimator(this.config);
  }

  private disposeAnimator(): void {
    if (this.animator) {
      this.animator.dispose();
      this.animator = null;
    }
    if (this.animationFrameId !== -1) {
      cancelAnimationFrame(this.animationFrameId);
      this.animationFrameId = -1;
    }
  }

  private updateThemeAwareConfig(): void {
    this.config = LiquidGlassPreset.getThemeAwareConfig(this.config, this.isLightMode);
    if (this.animator) {
      this.animator.updateConfig(this.config);
    }
  }

  private getGlassStyle(): LiquidGlassStyle {
    const baseColor = this.isLightMode 
      ? 'rgba(255, 255, 255, ' 
      : 'rgba(26, 26, 26, ';
    
    const opacity = LiquidGlassUtils.clamp(this.currentOpacity, 0.5, 1);
    const bgColor = baseColor + opacity.toFixed(2) + ')';

    const borderColor = this.isLightMode
      ? 'rgba(255, 255, 255, 0.3)'
      : 'rgba(255, 255, 255, 0.1)';

    const shadowColor = this.isLightMode
      ? 'rgba(0, 0, 0, 0.1)'
      : 'rgba(0, 0, 0, 0.4)';

    return {
      backgroundColor: bgColor,
      backdropBlur: Math.round(this.currentBlur),
      opacity: opacity,
      borderRadius: this.glassBorderRadius,
      borderWidth: 1,
      borderColor: borderColor,
      shadowRadius: Math.round(12 * this.config.shadowSoftness),
      shadowColor: shadowColor,
      shadowOffsetY: 4
    };
  }

  private getTouchFeedback(): TouchFeedback {
    const scale = this.isPressed ? 0.98 : (this.isHovered ? 1.02 : 1);
    const opacity = this.isPressed ? 0.9 : (this.isHovered ? 0.95 : 1);
    
    return {
      scale,
      opacity,
      rippleX: this.lastTouchX,
      rippleY: this.lastTouchY,
      rippleIntensity: this.isPressed ? this.config.rippleIntensity : 0
    };
  }

  private handleTouchDown(x: number, y: number): void {
    if (!this.interactive) return;
    
    this.isPressed = true;
    this.lastTouchX = x;
    this.lastTouchY = y;

    if (this.animator && this.config.rippleEnabled) {
      this.animator.addRipple(x, y, this.config.rippleIntensity);
    }

    this.animatePressState(true);
  }

  private handleTouchUp(): void {
    if (!this.interactive) return;
    
    this.isPressed = false;
    this.animatePressState(false);
  }

  private handleHover(isHovered: boolean): void {
    if (!this.interactive) return;
    
    this.isHovered = isHovered;
    this.animateHoverState(isHovered);
  }

  private animatePressState(isPressed: boolean): void {
    const targetScale = isPressed ? 0.98 : 1;
    const targetOpacity = isPressed ? 0.9 : 1;
    
    animateTo({
      duration: 100,
      curve: Curve.EaseOut
    }, () => {
      this.currentScale = targetScale;
      this.currentOpacity = targetOpacity;
    });
  }

  private animateHoverState(isHovered: boolean): void {
    const targetScale = isHovered ? 1.02 : 1;
    const targetBlur = isHovered 
      ? this.config.blurIntensity * 1.2 
      : this.config.blurIntensity;
    const targetGlow = isHovered 
      ? this.config.glowIntensity * 1.5 
      : this.config.glowIntensity;

    animateTo({
      duration: 200,
      curve: Curve.EaseOut
    }, () => {
      this.currentScale = targetScale;
      this.currentBlur = targetBlur;
      this.glowIntensity = targetGlow;
    });
  }

  build() {
    Stack() {
      Column() {
        this.content();
      }
      .width('100%')
      .padding(this.glassPadding)
    }
    .width(this.glassWidth)
    .height(this.glassHeight)
    .margin(this.glassMargin)
    .borderRadius(this.glassBorderRadius)
    .backgroundColor(this.getGlassStyle().backgroundColor)
    .backdropBlur(this.getGlassStyle().backdropBlur)
    .border({
      width: this.getGlassStyle().borderWidth,
      color: this.getGlassStyle().borderColor
    })
    .shadow({
      radius: this.getGlassStyle().shadowRadius,
      color: this.getGlassStyle().shadowColor,
      offsetX: 0,
      offsetY: this.getGlassStyle().shadowOffsetY
    })
    .opacity(this.getTouchFeedback().opacity)
    .scale({
      x: this.currentScale,
      y: this.currentScale
    })
    .animation({
      duration: 150,
      curve: Curve.EaseOut
    })
    .onClick(() => {
      if (this.interactive) {
        this.handleTouchUp();
        this.onClickCallback();
      }
    })
    .onTouch((event: TouchEvent) => {
      if (!this.interactive) return;
      
      if (event.type === TouchType.Down) {
        this.handleTouchDown(0, 0);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.handleTouchUp();
      }
    })
    .onHover((isHover: boolean) => {
      this.handleHover(isHover);
    })
    .focusable(this.interactive)
    .onFocus(() => {
      this.isFocused = true;
    })
    .onBlur(() => {
      this.isFocused = false;
    })
  }
}

@ComponentV2
export struct LiquidGlassCard {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  @Local isHovered: boolean = false;

  @Param title: string = '';
  @Param subtitle: string = '';
  @Param preset: 'default' | 'silk' | 'crystal' | 'water' | 'frosted' | 'amber' = 'default';
  @Param cardPadding: number = DesignSystem.Spacing.lg;
  @Param cardMargin: number = DesignSystem.Spacing.sm;
  @Param cardBorderRadius: number = DesignSystem.BorderRadius.lg;
  @Param interactive: boolean = true;
  @Param showGlow: boolean = true;

  @BuilderParam
  content: () => void;

  @BuilderParam
  header: () => void;

  @BuilderParam
  footer: () => void;

  private onClickHandler?: () => void;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  build() {
    LiquidGlassEffect({
      preset: this.preset,
      glassPadding: this.cardPadding,
      glassMargin: this.cardMargin,
      glassBorderRadius: this.cardBorderRadius,
      interactive: this.interactive,
      onClickCallback: this.onClickHandler
    }) {
      Column() {
        if (this.title || this.header) {
          Column() {
            if (this.header) {
              this.header();
            } else {
              Text(this.title)
                .fontSize(DesignSystem.Typography.size.lg)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .fontWeight(DesignSystem.Typography.weight.semibold)

              if (this.subtitle) {
                Text(this.subtitle)
                  .fontSize(DesignSystem.Typography.size.sm)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  .margin({ top: DesignSystem.Spacing.xs })
              }
            }
          }
          .width('100%')
          .margin({ bottom: DesignSystem.Spacing.md })
        }

        this.content();

        if (this.footer) {
          Column() {
            this.footer();
          }
          .width('100%')
          .margin({ top: DesignSystem.Spacing.md })
        }
      }
      .width('100%')
    }
  }

  setOnClick(handler: () => void): LiquidGlassCard {
    this.onClickHandler = handler;
    return this;
  }
}

@ComponentV2
export struct LiquidGlassButton {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  @Local currentScale: number = 1;
  @Local buttonOpacity: number = 1;

  @Param text: string = '';
  @Param icon: string = '';
  @Param preset: 'default' | 'silk' | 'crystal' | 'water' | 'amber' = 'default';
  @Param buttonSize: 'sm' | 'md' | 'lg' = 'md';
  @Param disabled: boolean = false;
  @Param loading: boolean = false;
  @Param fullWidth: boolean = false;

  private onClickHandler?: () => void;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    this.buttonOpacity = this.disabled ? 0.5 : 1;
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  private getSizeConfig(): SizeConfig {
    if (this.buttonSize === 'sm') {
      return {
        padding: DesignSystem.Spacing.sm,
        fontSize: DesignSystem.Typography.size.sm,
        iconSize: DesignSystem.IconSize.sm
      };
    } else if (this.buttonSize === 'lg') {
      return {
        padding: DesignSystem.Spacing.lg,
        fontSize: DesignSystem.Typography.size.lg,
        iconSize: DesignSystem.IconSize.lg
      };
    } else {
      return {
        padding: DesignSystem.Spacing.md,
        fontSize: DesignSystem.Typography.size.base,
        iconSize: DesignSystem.IconSize.md
      };
    }
  }

  build() {
    LiquidGlassEffect({
      preset: this.preset,
      glassPadding: this.getSizeConfig().padding,
      glassBorderRadius: DesignSystem.BorderRadius.md,
      interactive: !this.disabled && !this.loading,
      glassWidth: this.fullWidth ? '100%' : 'auto',
      onClickCallback: !this.disabled && !this.loading ? this.onClickHandler : undefined
    }) {
      Row() {
        if (this.loading) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(DesignSystem.getPrimaryColor(this.isLightMode))
        } else {
          if (this.icon) {
            Text(this.icon)
              .fontSize(this.getSizeConfig().iconSize)
              .margin({ right: this.text ? DesignSystem.Spacing.sm : 0 })
          }

          if (this.text) {
            Text(this.text)
              .fontSize(this.getSizeConfig().fontSize)
              .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
              .fontWeight(DesignSystem.Typography.weight.medium)
          }
        }
      }
      .justifyContent(FlexAlign.Center)
      .width(this.fullWidth ? '100%' : 'auto')
      .opacity(this.buttonOpacity)
    }
  }

  setOnClick(handler: () => void): LiquidGlassButton {
    this.onClickHandler = handler;
    return this;
  }
}

@ComponentV2
export struct LiquidGlassOverlay {
  @Local isLightMode: boolean = true;
  @Local overlayOpacity: number = 0;

  @Param visible: boolean = false;
  @Param preset: 'default' | 'frosted' = 'frosted';
  @Param blurIntensity: number = 30;
  @Param animationDuration: number = 300;

  @BuilderParam
  content: () => void;

  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    
    if (this.visible) {
      this.showOverlay();
    }
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  private showOverlay(): void {
    animateTo({
      duration: this.animationDuration,
      curve: Curve.EaseOut
    }, () => {
      this.overlayOpacity = 1;
    });
  }

  build() {
    Stack() {
      Column() {
        this.content();
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isLightMode 
      ? 'rgba(255, 255, 255, 0.8)' 
      : 'rgba(0, 0, 0, 0.85)')
    .backdropBlur(this.blurIntensity)
    .opacity(this.visible ? this.overlayOpacity : 0)
    .visibility(this.visible || this.overlayOpacity > 0 ? Visibility.Visible : Visibility.None)
    .animation({
      duration: this.animationDuration,
      curve: Curve.EaseOut
    })
  }
}


export function createLiquidGlassStyle(
  isLightMode: boolean,
  preset: string = 'DEFAULT'
): LiquidGlassStyle {
  let config: LiquidGlassConfig;

  switch (preset) {
    case 'SILK':
      config = LiquidGlassPreset.SILK;
      break;
    case 'CRYSTAL':
      config = LiquidGlassPreset.CRYSTAL;
      break;
    case 'WATER':
      config = LiquidGlassPreset.WATER;
      break;
    case 'FROSTED':
      config = LiquidGlassPreset.FROSTED;
      break;
    case 'AMBER':
      config = LiquidGlassPreset.AMBER;
      break;
    default:
      config = LiquidGlassPreset.DEFAULT;
  }

  const themeConfig = LiquidGlassPreset.getThemeAwareConfig(config, isLightMode);

  return {
    backgroundColor: isLightMode
      ? `rgba(255, 255, 255, ${themeConfig.transparency})`
      : `rgba(26, 26, 26, ${themeConfig.transparency})`,
    backdropBlur: themeConfig.blurIntensity,
    opacity: themeConfig.transparency,
    borderRadius: DesignSystem.BorderRadius.xl,
    borderWidth: 1,
    borderColor: isLightMode
      ? 'rgba(255, 255, 255, 0.3)'
      : 'rgba(255, 255, 255, 0.1)',
    shadowRadius: Math.round(12 * themeConfig.shadowSoftness),
    shadowColor: isLightMode
      ? 'rgba(0, 0, 0, 0.1)'
      : 'rgba(0, 0, 0, 0.4)',
    shadowOffsetY: 4
  };
}
