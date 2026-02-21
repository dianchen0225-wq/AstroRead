import { DesignSystem, ButtonStyle } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
export type ButtonSize = 'sm' | 'md' | 'lg';

interface SizeStyles {
  height: number;
  padding: number;
  fontSize: number;
}

interface VariantStyles {
  bgColor: string;
  textColor: string;
  borderColor: string;
}

@ComponentV2
export struct AppButton {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  @Local isFocused: boolean = false;
  
  @Param text: string = '';
  @Param variant: ButtonVariant = 'primary';
  @Param buttonSize: ButtonSize = 'md';
  @Param disabled: boolean = false;
  @Param loading: boolean = false;
  @Param fullWidth: boolean = false;
  @Param icon: string = '';
  @Param accessibilityLabel: string = '';
  @Param accessibilityHint: string = '';
  @Param onClicked: () => void = () => {};
  
  private clickHandler?: () => void;
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

  private getSizeStyles(): SizeStyles {
    switch (this.buttonSize) {
      case 'sm':
        return { height: 32, padding: DesignSystem.Spacing.sm, fontSize: DesignSystem.Typography.size.xs };
      case 'lg':
        return { height: 48, padding: DesignSystem.Spacing.lg, fontSize: DesignSystem.Typography.size.base };
      default:
        return { height: 40, padding: DesignSystem.Spacing.md, fontSize: DesignSystem.Typography.size.sm };
    }
  }

  private getVariantStyles(): VariantStyles {
    const pressed = this.isPressed && !this.disabled;
    
    switch (this.variant) {
      case 'primary':
        return {
          bgColor: pressed ? this.darkenColor(DesignSystem.getPrimaryColor(this.isLightMode), 0.1) : DesignSystem.getPrimaryColor(this.isLightMode),
          textColor: '#FFFFFF',
          borderColor: 'transparent'
        };
      case 'secondary':
        return {
          bgColor: pressed ? DesignSystem.getActiveColor(this.isLightMode) : DesignSystem.getSecondaryBackgroundColor(this.isLightMode),
          textColor: DesignSystem.getPrimaryTextColor(this.isLightMode),
          borderColor: DesignSystem.getBorderColor(this.isLightMode)
        };
      case 'ghost':
        return {
          bgColor: pressed ? DesignSystem.getHoverColor(this.isLightMode) : 'transparent',
          textColor: DesignSystem.getPrimaryColor(this.isLightMode),
          borderColor: 'transparent'
        };
      case 'danger':
        return {
          bgColor: pressed ? this.darkenColor(DesignSystem.getErrorColor(this.isLightMode), 0.1) : DesignSystem.getErrorColor(this.isLightMode),
          textColor: '#FFFFFF',
          borderColor: 'transparent'
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
          .width(this.getSizeStyles().fontSize + 2)
          .height(this.getSizeStyles().fontSize + 2)
          .color(this.getVariantStyles().textColor)
          .margin({ right: this.text ? DesignSystem.Spacing.xs : 0 })
      } else if (this.icon) {
        Text(this.icon)
          .fontSize(this.getSizeStyles().fontSize + 2)
          .margin({ right: this.text ? DesignSystem.Spacing.xs : 0 })
      }
      
      if (this.text) {
        Text(this.text)
          .fontSize(this.getSizeStyles().fontSize)
          .fontColor(this.disabled ? DesignSystem.getTertiaryTextColor(this.isLightMode) : this.getVariantStyles().textColor)
          .fontWeight(DesignSystem.Typography.weight.medium)
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
    .opacity(this.disabled ? 0.6 : 1)
    .justifyContent(FlexAlign.Center)
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      if (!this.disabled && !this.loading) {
        if (this.onClicked) {
          this.onClicked();
        } else if (this.clickHandler) {
          this.clickHandler();
        }
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

  setClickHandler(handler: () => void): AppButton {
    this.clickHandler = handler;
    return this;
  }
}
