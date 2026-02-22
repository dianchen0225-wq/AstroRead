import { DesignSystem, CardStyle } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';

@ComponentV2
export struct AppCard {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  @Local isFocused: boolean = false;
  
  @Param cardPadding: number = DesignSystem.Spacing.lg;
  @Param cardMargin: number = 0;
  @Param cardBorderRadius: number = DesignSystem.BorderRadius.lg;
  @Param elevation: 'none' | 'sm' | 'md' | 'lg' = 'sm';
  @Param clickable: boolean = false;
  @Param accessibilityLabel: string = '';
  @Param onCardClick: () => void = () => {};
  
  @BuilderParam content: () => void;

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

  private getShadow(): string {
    switch (this.elevation) {
      case 'none':
        return '';
      case 'sm':
        return this.isLightMode ? DesignSystem.Shadows.sm.light : DesignSystem.Shadows.sm.dark;
      case 'md':
        return this.isLightMode ? DesignSystem.Shadows.md.light : DesignSystem.Shadows.md.dark;
      case 'lg':
        return this.isLightMode ? DesignSystem.Shadows.lg.light : DesignSystem.Shadows.lg.dark;
    }
  }

  build() {
    Column() {
      this.content();
    }
    .width('100%')
    .padding(this.cardPadding)
    .margin(this.cardMargin)
    .borderRadius(this.cardBorderRadius)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .shadow({
      radius: this.elevation === 'none' ? 0 : this.elevation === 'sm' ? 4 : this.elevation === 'md' ? 8 : 16,
      color: this.isLightMode ? 'rgba(0,0,0,0.05)' : 'rgba(0,0,0,0.3)',
      offsetX: 0,
      offsetY: this.elevation === 'none' ? 0 : 2
    })
    .opacity(this.isPressed && this.clickable ? 0.9 : 1)
    .scale({ x: this.isPressed && this.clickable ? 0.98 : 1, y: this.isPressed && this.clickable ? 0.98 : 1 })
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      if (this.clickable && this.onCardClick) {
        this.onCardClick();
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
}
