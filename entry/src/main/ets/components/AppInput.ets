import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';

@ComponentV2
export struct AppInput {
  @Local isLightMode: boolean = true;
  @Local isFocused: boolean = false;
  @Local inputValue: string = '';
  
  @Param placeholder: string = '';
  @Param value: string = '';
  @Param type: 'text' | 'password' | 'number' | 'email' = 'text';
  @Param maxLength: number = 0;
  @Param disabled: boolean = false;
  @Param clearable: boolean = false;
  @Param prefixIcon: string = '';
  @Param suffixIcon: string = '';
  @Param accessibilityLabel: string = '';
  @Param size: 'sm' | 'md' | 'lg' = 'md';
  @Param error: boolean = false;
  @Param errorMessage: string = '';
  
  private onChangeHandler?: (value: string) => void;
  private onSubmitHandler?: (value: string) => void;
  private onFocusHandler?: () => void;
  private onBlurHandler?: () => void;
  private onSuffixClickHandler?: () => void;
  
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    this.inputValue = this.value;
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  private getSizeStyles(): { height: number; fontSize: number; padding: number } {
    switch (this.size) {
      case 'sm':
        return { height: 36, fontSize: DesignSystem.Typography.size.xs, padding: DesignSystem.Spacing.sm };
      case 'lg':
        return { height: 52, fontSize: DesignSystem.Typography.size.base, padding: DesignSystem.Spacing.lg };
      default:
        return { height: 44, fontSize: DesignSystem.Typography.size.sm, padding: DesignSystem.Spacing.md };
    }
  }

  private getBorderColor(): string {
    if (this.error) {
      return DesignSystem.getErrorColor(this.isLightMode);
    }
    if (this.isFocused) {
      return DesignSystem.getPrimaryColor(this.isLightMode);
    }
    return DesignSystem.getBorderColor(this.isLightMode);
  }

  build() {
    Column() {
      Row() {
        if (this.prefixIcon) {
          Text(this.prefixIcon)
            .fontSize(this.getSizeStyles().fontSize + 2)
            .fontColor(this.disabled ? 
              DesignSystem.getTertiaryTextColor(this.isLightMode) : 
              DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ right: DesignSystem.Spacing.sm })
        }
        
        TextInput({
          placeholder: this.placeholder,
          text: this.inputValue
        })
          .layoutWeight(1)
          .type(this.type === 'password' ? InputType.Password : InputType.Normal)
          .maxLength(this.maxLength > 0 ? this.maxLength : undefined)
          .enabled(!this.disabled)
          .placeholderColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
          .placeholderFont({ size: this.getSizeStyles().fontSize })
          .fontColor(this.disabled ? 
            DesignSystem.getTertiaryTextColor(this.isLightMode) : 
            DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontSize(this.getSizeStyles().fontSize)
          .backgroundColor(Color.Transparent)
          .caretColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .caretHeight(20)
          .onChange((value: string) => {
            this.inputValue = value;
            if (this.onChangeHandler) {
              this.onChangeHandler(value);
            }
          })
          .onSubmit(() => {
            if (this.onSubmitHandler) {
              this.onSubmitHandler(this.inputValue);
            }
          })
          .onFocus(() => {
            this.isFocused = true;
            if (this.onFocusHandler) {
              this.onFocusHandler();
            }
          })
          .onBlur(() => {
            this.isFocused = false;
            if (this.onBlurHandler) {
              this.onBlurHandler();
            }
          })
        
        if (this.clearable && this.inputValue.length > 0 && !this.disabled) {
          Row() {
            Text('✕')
              .fontSize(this.getSizeStyles().fontSize - 2)
              .fontColor('#FFFFFF')
          }
          .width(18)
          .height(18)
          .borderRadius(9)
          .backgroundColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
          .justifyContent(FlexAlign.Center)
          .margin({ left: DesignSystem.Spacing.xs })
          .onClick(() => {
            this.inputValue = '';
            if (this.onChangeHandler) {
              this.onChangeHandler('');
            }
          })
        }
        
        if (this.suffixIcon) {
          Text(this.suffixIcon)
            .fontSize(this.getSizeStyles().fontSize + 2)
            .fontColor(this.disabled ? 
              DesignSystem.getTertiaryTextColor(this.isLightMode) : 
              DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ left: DesignSystem.Spacing.sm })
            .onClick(() => {
              if (this.onSuffixClickHandler) {
                this.onSuffixClickHandler();
              }
            })
        }
      }
      .width('100%')
      .height(this.getSizeStyles().height)
      .padding({ 
        left: this.getSizeStyles().padding, 
        right: this.getSizeStyles().padding 
      })
      .borderRadius(DesignSystem.BorderRadius.md)
      .backgroundColor(this.disabled ? 
        DesignSystem.getBorderColor(this.isLightMode) : 
        DesignSystem.getTertiaryBackgroundColor(this.isLightMode))
      .border({
        width: this.isFocused || this.error ? 2 : 1,
        color: this.getBorderColor()
      })
      .shadow(this.isFocused && !this.error ? {
        radius: 8,
        color: this.isLightMode ? 'rgba(184, 134, 11, 0.15)' : 'rgba(232, 197, 71, 0.2)',
        offsetX: 0,
        offsetY: 0
      } : undefined)
      .animation({
        duration: DesignSystem.AnimationDuration.fast,
        curve: DesignSystem.AnimationCurve.easeOut
      })
      
      if (this.error && this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getErrorColor(this.isLightMode))
          .margin({ top: DesignSystem.Spacing.xs, left: DesignSystem.Spacing.sm })
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  onChange(handler: (value: string) => void): AppInput {
    this.onChangeHandler = handler;
    return this;
  }

  onSubmit(handler: (value: string) => void): AppInput {
    this.onSubmitHandler = handler;
    return this;
  }

  onFocus(handler: () => void): AppInput {
    this.onFocusHandler = handler;
    return this;
  }

  onBlur(handler: () => void): AppInput {
    this.onBlurHandler = handler;
    return this;
  }

  onSuffixClick(handler: () => void): AppInput {
    this.onSuffixClickHandler = handler;
    return this;
  }
}
