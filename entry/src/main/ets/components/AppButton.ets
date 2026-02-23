import { DesignSystem, ButtonStyle } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'success';
export type ButtonSize = 'sm' | 'md' | 'lg';

@ComponentV2
export struct AppButton {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  @Local isFocused: boolean = false;
  
  @Param text: string = '';
  @Param variant: ButtonVariant = 'primary';
  @Param size: ButtonSize = 'md';
  @Param disabled: boolean = false;
  @Param loading: boolean = false;
  @Param fullWidth: boolean = false;
  @Param icon: string = '';
  @Param accessibilityLabel: string = '';
  @Param accessibilityHint: string = '';
  
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

  private getSizeStyles(): { height: number; padding: number; fontSize: number; iconSize: number } {
    switch (this.size) {
      case 'sm':
        return { 
          height: 32, 
          padding: DesignSystem.Spacing.lg, 
          fontSize: DesignSystem.Typography.size.xs,
          iconSize: DesignSystem.IconSize.xs
        };
      case 'lg':
        return { 
          height: 52, 
          padding: DesignSystem.Spacing.xxl, 
          fontSize: DesignSystem.Typography.size.base,
          iconSize: DesignSystem.IconSize.md
        };
      default:
        return { 
          height: 44, 
          padding: DesignSystem.Spacing.xl, 
          fontSize: DesignSystem.Typography.size.sm,
          iconSize: DesignSystem.IconSize.sm
        };
    }
  }

  private getVariantStyles(): { bgColor: string; textColor: string; borderColor: string; hasGradient: boolean } {
    const pressed = this.isPressed && !this.disabled;
    
    switch (this.variant) {
      case 'primary':
        return {
          bgColor: pressed ? this.darkenColor(DesignSystem.getPrimaryColor(this.isLightMode), 0.12) : DesignSystem.getPrimaryColor(this.isLightMode),
          textColor: '#FFFFFF',
          borderColor: 'transparent',
          hasGradient: false
        };
      case 'secondary':
        return {
          bgColor: pressed ? DesignSystem.getActiveColor(this.isLightMode) : DesignSystem.getSecondaryBackgroundColor(this.isLightMode),
          textColor: DesignSystem.getPrimaryTextColor(this.isLightMode),
          borderColor: DesignSystem.getBorderColor(this.isLightMode),
          hasGradient: false
        };
      case 'ghost':
        return {
          bgColor: pressed ? DesignSystem.getHoverColor(this.isLightMode) : 'transparent',
          textColor: DesignSystem.getPrimaryColor(this.isLightMode),
          borderColor: 'transparent',
          hasGradient: false
        };
      case 'danger':
        return {
          bgColor: pressed ? this.darkenColor(DesignSystem.getErrorColor(this.isLightMode), 0.12) : DesignSystem.getErrorColor(this.isLightMode),
          textColor: '#FFFFFF',
          borderColor: 'transparent',
          hasGradient: false
        };
      case 'success':
        return {
          bgColor: pressed ? this.darkenColor(DesignSystem.getSuccessColor(this.isLightMode), 0.12) : DesignSystem.getSuccessColor(this.isLightMode),
          textColor: '#FFFFFF',
          borderColor: 'transparent',
          hasGradient: false
        };
    }
  }

  private darkenColor(color: string, amount: number): string {
    const hex = color.replace('#', '');
    const r = Math.max(0, parseInt(hex.substr(0, 2), 16) - Math.round(255 * amount));
    const g = Math.max(0, parseInt(hex.substr(2, 2), 16) - Math.round(255 * amount));
    const b = Math.max(0, parseInt(hex.substr(4, 2), 16) - Math.round(255 * amount));
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }

  build() {
    Row() {
      if (this.loading) {
        LoadingProgress()
          .width(this.getSizeStyles().iconSize)
          .height(this.getSizeStyles().iconSize)
          .color(this.getVariantStyles().textColor)
          .margin({ right: this.text ? DesignSystem.Spacing.sm : 0 })
      } else if (this.icon) {
        Text(this.icon)
          .fontSize(this.getSizeStyles().iconSize)
          .margin({ right: this.text ? DesignSystem.Spacing.sm : 0 })
      }
      
      if (this.text) {
        Text(this.text)
          .fontSize(this.getSizeStyles().fontSize)
          .fontColor(this.disabled ? DesignSystem.getTertiaryTextColor(this.isLightMode) : this.getVariantStyles().textColor)
          .fontWeight(DesignSystem.Typography.weight.medium)
          .letterSpacing(0.5)
      }
    }
    .width(this.fullWidth ? '100%' : undefined)
    .height(this.getSizeStyles().height)
    .padding({ left: this.getSizeStyles().padding, right: this.getSizeStyles().padding })
    .borderRadius(DesignSystem.BorderRadius.md)
    .backgroundColor(this.disabled ? DesignSystem.getBorderColor(this.isLightMode) : this.getVariantStyles().bgColor)
    .border({
      width: this.getVariantStyles().borderColor === 'transparent' ? 0 : 1,
      color: this.getVariantStyles().borderColor
    })
    .opacity(this.disabled ? 0.5 : (this.isPressed ? 0.92 : 1))
    .shadow(this.variant === 'primary' && !this.disabled ? {
      radius: 8,
      color: this.isLightMode ? 'rgba(184, 134, 11, 0.25)' : 'rgba(232, 197, 71, 0.3)',
      offsetX: 0,
      offsetY: 4
    } : undefined)
    .justifyContent(FlexAlign.Center)
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      if (!this.disabled && !this.loading && this.onClickHandler) {
        this.onClickHandler();
      }
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .focusable(true)
    .onFocus(() => {
      this.isFocused = true;
    })
    .onBlur(() => {
      this.isFocused = false;
    })
  }

  onClick(handler: () => void): AppButton {
    this.onClickHandler = handler;
    return this;
  }
}
