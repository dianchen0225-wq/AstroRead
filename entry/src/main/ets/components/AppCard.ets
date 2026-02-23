import { DesignSystem, CardStyle } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';

@ComponentV2
export struct AppCard {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  @Local isFocused: boolean = false;
  
  @Param padding: number = DesignSystem.Spacing.lg;
  @Param margin: number = 0;
  @Param borderRadius: number = DesignSystem.BorderRadius.md;
  @Param elevation: 'none' | 'sm' | 'md' | 'lg' | 'xl' = 'sm';
  @Param clickable: boolean = false;
  @Param accessibilityLabel: string = '';
  @Param variant: 'default' | 'outlined' | 'elevated' = 'default';
  
  @BuilderParam content: () => void = () => {};
  
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

  private getShadowConfig(): { radius: number; color: string; offsetY: number } {
    if (this.elevation === 'none') {
      return { radius: 0, color: 'transparent', offsetY: 0 };
    }
    
    const shadowConfigs: Record<string, { radius: number; color: string; offsetY: number }> = {
      sm: { 
        radius: 4, 
        color: this.isLightMode ? 'rgba(0,0,0,0.06)' : 'rgba(0,0,0,0.35)', 
        offsetY: 2 
      },
      md: { 
        radius: 8, 
        color: this.isLightMode ? 'rgba(0,0,0,0.08)' : 'rgba(0,0,0,0.45)', 
        offsetY: 4 
      },
      lg: { 
        radius: 16, 
        color: this.isLightMode ? 'rgba(0,0,0,0.1)' : 'rgba(0,0,0,0.55)', 
        offsetY: 8 
      },
      xl: { 
        radius: 24, 
        color: this.isLightMode ? 'rgba(0,0,0,0.12)' : 'rgba(0,0,0,0.65)', 
        offsetY: 12 
      }
    };
    
    return shadowConfigs[this.elevation] || shadowConfigs.sm;
  }

  build() {
    Column() {
      this.content();
    }
    .width('100%')
    .padding(this.padding)
    .margin(this.margin)
    .borderRadius(this.borderRadius)
    .backgroundColor(this.variant === 'outlined' ? 
      DesignSystem.getTertiaryBackgroundColor(this.isLightMode) : 
      DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: this.variant === 'outlined' ? 2 : 1,
      color: this.variant === 'outlined' ? 
        DesignSystem.getPrimaryColor(this.isLightMode) : 
        DesignSystem.getBorderColor(this.isLightMode)
    })
    .shadow(this.variant === 'elevated' || this.elevation !== 'none' ? {
      radius: this.getShadowConfig().radius,
      color: this.getShadowConfig().color,
      offsetX: 0,
      offsetY: this.getShadowConfig().offsetY
    } : undefined)
    .opacity(this.isPressed && this.clickable ? 0.88 : 1)
    .scale({ x: this.isPressed && this.clickable ? 0.98 : 1, y: this.isPressed && this.clickable ? 0.98 : 1 })
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      if (this.clickable && this.onClickHandler) {
        this.onClickHandler();
      }
    })
    .onTouch((event: TouchEvent) => {
      if (!this.clickable) return;
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .focusable(this.clickable)
    .onFocus(() => {
      this.isFocused = true;
    })
    .onBlur(() => {
      this.isFocused = false;
    })
  }

  onClick(handler: () => void): AppCard {
    this.onClickHandler = handler;
    return this;
  }
}
