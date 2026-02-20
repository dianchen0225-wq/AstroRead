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

  build() {
    Row() {
      if (this.prefixIcon) {
        Text(this.prefixIcon)
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
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
        .placeholderFont({ size: DesignSystem.Typography.size.sm })
        .fontColor(this.disabled ? DesignSystem.getTertiaryTextColor(this.isLightMode) : DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontSize(DesignSystem.Typography.size.sm)
        .backgroundColor(Color.Transparent)
        .caretColor(DesignSystem.getPrimaryColor(this.isLightMode))
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
        Text('✕')
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
          .padding(DesignSystem.Spacing.xs)
          .onClick(() => {
            this.inputValue = '';
            if (this.onChangeHandler) {
              this.onChangeHandler('');
            }
          })
      }
      
      if (this.suffixIcon) {
        Text(this.suffixIcon)
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .margin({ left: DesignSystem.Spacing.sm })
          .onClick(() => {
            if (this.onSuffixClickHandler) {
              this.onSuffixClickHandler();
            }
          })
      }
    }
    .width('100%')
    .height(44)
    .padding({ left: DesignSystem.Spacing.md, right: DesignSystem.Spacing.md })
    .borderRadius(DesignSystem.BorderRadius.md)
    .backgroundColor(this.disabled ? DesignSystem.getBorderColor(this.isLightMode) : DesignSystem.getTertiaryBackgroundColor(this.isLightMode))
    .border({
      width: this.isFocused ? 2 : 1,
      color: this.isFocused ? DesignSystem.getPrimaryColor(this.isLightMode) : DesignSystem.getBorderColor(this.isLightMode)
    })
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
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
