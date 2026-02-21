import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
export type ButtonSizeType = 'sm' | 'md' | 'lg';

@ComponentV2
export struct AppButton {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  
  @Param buttonText: string = '';
  @Param variant: ButtonVariant = 'primary';
  @Param buttonSize: ButtonSizeType = 'md';
  @Param disabled: boolean = false;
  @Param loading: boolean = false;
  @Param fullWidth: boolean = false;
  @Param buttonIcon: string = '';
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

  private getButtonHeight(): number {
    switch (this.buttonSize) {
      case 'sm':
        return 32;
      case 'md':
        return 44;
      case 'lg':
        return 52;
      default:
        return 44;
    }
  }

  private getButtonFontSize(): number {
    switch (this.buttonSize) {
      case 'sm':
        return DesignSystem.Typography.size.xs;
      case 'md':
        return DesignSystem.Typography.size.sm;
      case 'lg':
        return DesignSystem.Typography.size.base;
      default:
        return DesignSystem.Typography.size.sm;
    }
  }

  private getBackgroundColor(): string {
    if (this.disabled) {
      return DesignSystem.getBorderColor(this.isLightMode);
    }
    
    switch (this.variant) {
      case 'primary':
        return DesignSystem.getPrimaryColor(this.isLightMode);
      case 'secondary':
        return DesignSystem.getSecondaryBackgroundColor(this.isLightMode);
      case 'ghost':
        return 'transparent';
      case 'danger':
        return DesignSystem.getErrorColor(this.isLightMode);
      default:
        return DesignSystem.getPrimaryColor(this.isLightMode);
    }
  }

  private getTextColor(): string {
    if (this.disabled) {
      return DesignSystem.getTertiaryTextColor(this.isLightMode);
    }
    
    switch (this.variant) {
      case 'primary':
      case 'danger':
        return '#FFFFFF';
      case 'secondary':
      case 'ghost':
        return DesignSystem.getPrimaryTextColor(this.isLightMode);
      default:
        return '#FFFFFF';
    }
  }

  build() {
    Row() {
      if (this.loading) {
        LoadingProgress()
          .width(this.getButtonFontSize())
          .height(this.getButtonFontSize())
          .color(this.getTextColor())
          .margin({ right: this.buttonText ? DesignSystem.Spacing.sm : 0 })
      } else if (this.buttonIcon) {
        Text(this.buttonIcon)
          .fontSize(this.getButtonFontSize())
          .margin({ right: this.buttonText ? DesignSystem.Spacing.sm : 0 })
      }
      
      if (this.buttonText) {
        Text(this.buttonText)
          .fontSize(this.getButtonFontSize())
          .fontColor(this.getTextColor())
          .fontWeight(DesignSystem.Typography.weight.medium)
      }
    }
    .width(this.fullWidth ? '100%' : undefined)
    .height(this.getButtonHeight())
    .padding({
      left: this.fullWidth ? DesignSystem.Spacing.lg : undefined,
      right: this.fullWidth ? DesignSystem.Spacing.lg : undefined
    })
    .justifyContent(FlexAlign.Center)
    .borderRadius(DesignSystem.BorderRadius.md)
    .backgroundColor(this.getBackgroundColor())
    .border({
      width: this.variant === 'secondary' ? 1 : 0,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .opacity(this.disabled ? 0.6 : (this.isPressed ? 0.8 : 1))
    .scale({ x: this.isPressed && !this.disabled ? 0.98 : 1, y: this.isPressed && !this.disabled ? 0.98 : 1 })
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: Curve.EaseOut
    })
    .onClick(() => {
      if (!this.disabled && !this.loading) {
        if (this.clickHandler) {
          this.clickHandler();
        } else if (this.onClicked) {
          this.onClicked();
        }
      }
    })
    .onTouch((event: TouchEvent) => {
      if (!this.disabled && !this.loading) {
        if (event.type === TouchType.Down) {
          this.isPressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.isPressed = false;
        }
      }
    })
  }

  setOnClick(handler: () => void): AppButton {
    this.clickHandler = handler;
    return this;
  }
}

@ComponentV2
export struct AppCard {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  
  @Param cardPadding: number = DesignSystem.Spacing.md;
  @Param cardBorderRadius: number = DesignSystem.BorderRadius.lg;
  @Param showShadow: boolean = true;
  @Param clickable: boolean = false;
  
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

  @Builder
  defaultContent() {}

  @BuilderParam
  content: () => void = this.defaultContent;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.cardPadding)
    .borderRadius(this.cardBorderRadius)
    .backgroundColor(this.isPressed ?
      DesignSystem.getActiveColor(this.isLightMode) :
      DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .shadow(this.showShadow ? {
      radius: this.isPressed ? 2 : 4,
      color: this.isLightMode ? 'rgba(0,0,0,0.04)' : 'rgba(0,0,0,0.2)',
      offsetX: 0,
      offsetY: this.isPressed ? 1 : 2
    } : undefined)
    .scale({ x: this.isPressed && this.clickable ? 0.98 : 1, y: this.isPressed && this.clickable ? 0.98 : 1 })
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: Curve.EaseOut
    })
    .onClick(() => {
      if (this.clickable && this.clickHandler) {
        this.clickHandler();
      }
    })
    .onTouch((event: TouchEvent) => {
      if (this.clickable) {
        if (event.type === TouchType.Down) {
          this.isPressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.isPressed = false;
        }
      }
    })
  }

  setOnClick(handler: () => void): AppCard {
    this.clickHandler = handler;
    return this;
  }
}

@ComponentV2
export struct AppInput {
  @Local isLightMode: boolean = true;
  @Local isFocused: boolean = false;
  
  @Param inputPlaceholder: string = '';
  @Param inputValue: string = '';
  @Param inputType: InputType = InputType.Normal;
  @Param inputMaxLength: number = 100;
  @Param showClear: boolean = true;
  @Param prefixIcon: string = '';
  @Param suffixIcon: string = '';
  
  private changeHandler?: (value: string) => void;
  private submitHandler?: () => void;
  private suffixClickHandler?: () => void;
  
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
    Row() {
      if (this.prefixIcon) {
        Text(this.prefixIcon)
          .fontSize(DesignSystem.IconSize.md)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .margin({ right: DesignSystem.Spacing.sm })
      }

      TextInput({ placeholder: this.inputPlaceholder, text: this.inputValue })
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontSize(DesignSystem.Typography.size.base)
        .placeholderColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
        .type(this.inputType)
        .maxLength(this.inputMaxLength)
        .onChange((value: string) => {
          if (this.changeHandler) {
            this.changeHandler(value);
          }
        })
        .onSubmit(() => {
          if (this.submitHandler) {
            this.submitHandler();
          }
        })
        .onFocus(() => {
          this.isFocused = true;
        })
        .onBlur(() => {
          this.isFocused = false;
        })

      if (this.showClear && this.inputValue.length > 0) {
        Text('✕')
          .fontSize(DesignSystem.IconSize.sm)
          .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
          .margin({ left: DesignSystem.Spacing.sm })
          .onClick(() => {
            if (this.changeHandler) {
              this.changeHandler('');
            }
          })
      }

      if (this.suffixIcon) {
        Text(this.suffixIcon)
          .fontSize(DesignSystem.IconSize.md)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .margin({ left: DesignSystem.Spacing.sm })
          .onClick(() => {
            if (this.suffixClickHandler) {
              this.suffixClickHandler();
            }
          })
      }
    }
    .width('100%')
    .height(44)
    .padding({
      left: DesignSystem.Spacing.md,
      right: DesignSystem.Spacing.md
    })
    .borderRadius(DesignSystem.BorderRadius.md)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: this.isFocused ? 2 : 1,
      color: this.isFocused ?
        DesignSystem.getPrimaryColor(this.isLightMode) :
        DesignSystem.getBorderColor(this.isLightMode)
    })
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: Curve.EaseOut
    })
  }

  setOnChange(handler: (value: string) => void): AppInput {
    this.changeHandler = handler;
    return this;
  }

  setOnSubmit(handler: () => void): AppInput {
    this.submitHandler = handler;
    return this;
  }

  setOnSuffixClick(handler: () => void): AppInput {
    this.suffixClickHandler = handler;
    return this;
  }
}

@ComponentV2
export struct AppDivider {
  @Local isLightMode: boolean = true;
  
  @Param dividerMargin: number = DesignSystem.Spacing.md;
  
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
    Row()
      .width('100%')
      .height(1)
      .backgroundColor(DesignSystem.getBorderColor(this.isLightMode))
      .margin({ top: this.dividerMargin, bottom: this.dividerMargin })
  }
}

@ComponentV2
export struct AppEmpty {
  @Local isLightMode: boolean = true;
  
  @Param emptyIcon: string = '📭';
  @Param emptyTitle: string = '暂无数据';
  @Param emptyDescription: string = '';
  @Param actionText: string = '';
  
  private actionHandler?: () => void;
  
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
    Column() {
      Text(this.emptyIcon)
        .fontSize(64)
        .margin({ bottom: DesignSystem.Spacing.lg })

      Text(this.emptyTitle)
        .fontSize(DesignSystem.Typography.size.lg)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.medium)
        .margin({ bottom: DesignSystem.Spacing.sm })

      if (this.emptyDescription) {
        Text(this.emptyDescription)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .textAlign(TextAlign.Center)
          .margin({ bottom: DesignSystem.Spacing.lg })
      }

      if (this.actionText && this.actionHandler) {
        Row() {
          Text(this.actionText)
            .fontSize(DesignSystem.Typography.size.sm)
            .fontColor('#FFFFFF')
            .fontWeight(DesignSystem.Typography.weight.medium)
        }
        .padding({
          left: DesignSystem.Spacing.lg,
          right: DesignSystem.Spacing.lg,
          top: DesignSystem.Spacing.sm,
          bottom: DesignSystem.Spacing.sm
        })
        .borderRadius(DesignSystem.BorderRadius.md)
        .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
        .onClick(() => {
          if (this.actionHandler) {
            this.actionHandler();
          }
        })
      }
    }
    .width('100%')
    .padding(DesignSystem.Spacing.xxl)
  }

  setOnAction(handler: () => void): AppEmpty {
    this.actionHandler = handler;
    return this;
  }
}

@ComponentV2
export struct AppLoading {
  @Local isLightMode: boolean = true;
  
  @Param loadingText: string = '加载中...';
  @Param loadingSize: number = 40;
  
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
    Column() {
      LoadingProgress()
        .width(this.loadingSize)
        .height(this.loadingSize)
        .color(DesignSystem.getPrimaryColor(this.isLightMode))

      if (this.loadingText) {
        Text(this.loadingText)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .margin({ top: DesignSystem.Spacing.md })
      }
    }
    .width('100%')
    .padding(DesignSystem.Spacing.xl)
  }
}

@ComponentV2
export struct AppBadge {
  @Local isLightMode: boolean = true;
  
  @Param badgeText: string = '';
  @Param badgeType: 'primary' | 'success' | 'warning' | 'error' | 'info' = 'primary';
  @Param badgeSize: 'sm' | 'md' = 'sm';
  
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

  private getBackgroundColor(): string {
    switch (this.badgeType) {
      case 'primary':
        return DesignSystem.getPrimaryColor(this.isLightMode);
      case 'success':
        return DesignSystem.getSuccessColor(this.isLightMode);
      case 'warning':
        return DesignSystem.getWarningColor(this.isLightMode);
      case 'error':
        return DesignSystem.getErrorColor(this.isLightMode);
      case 'info':
        return DesignSystem.getInfoColor(this.isLightMode);
      default:
        return DesignSystem.getPrimaryColor(this.isLightMode);
    }
  }

  private getFontSize(): number {
    return this.badgeSize === 'sm' ? DesignSystem.Typography.size.xs : DesignSystem.Typography.size.sm;
  }

  build() {
    Text(this.badgeText)
      .fontSize(this.getFontSize())
      .fontColor('#FFFFFF')
      .fontWeight(DesignSystem.Typography.weight.medium)
      .padding({
        left: DesignSystem.Spacing.sm,
        right: DesignSystem.Spacing.sm,
        top: DesignSystem.Spacing.xs,
        bottom: DesignSystem.Spacing.xs
      })
      .borderRadius(DesignSystem.BorderRadius.full)
      .backgroundColor(this.getBackgroundColor())
  }
}

@ComponentV2
export struct AppListItem {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  
  @Param itemTitle: string = '';
  @Param itemSubtitle: string = '';
  @Param itemIcon: string = '';
  @Param showArrow: boolean = false;
  @Param showDivider: boolean = true;
  
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

  @Builder
  defaultTrailing() {}

  @BuilderParam
  trailing: () => void = this.defaultTrailing;

  build() {
    Column() {
      Row() {
        if (this.itemIcon) {
          Row() {
            Text(this.itemIcon)
              .fontSize(DesignSystem.IconSize.md)
          }
          .width(32)
          .height(32)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(DesignSystem.getHoverColor(this.isLightMode))
          .justifyContent(FlexAlign.Center)
          .margin({ right: DesignSystem.Spacing.md })
        }

        Column() {
          Text(this.itemTitle)
            .fontSize(DesignSystem.Typography.size.base)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .fontWeight(DesignSystem.Typography.weight.medium)

          if (this.itemSubtitle) {
            Text(this.itemSubtitle)
              .fontSize(DesignSystem.Typography.size.xs)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .margin({ top: 2 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.trailing()

        if (this.showArrow) {
          Text('›')
            .fontSize(DesignSystem.Typography.size.xl)
            .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
            .margin({ left: DesignSystem.Spacing.sm })
        }
      }
      .width('100%')
      .padding(DesignSystem.Spacing.md)
      .backgroundColor(this.isPressed ?
        DesignSystem.getActiveColor(this.isLightMode) :
        Color.Transparent)
      .scale({ x: this.isPressed ? 0.98 : 1, y: this.isPressed ? 0.98 : 1 })
      .animation({
        duration: DesignSystem.AnimationDuration.fast,
        curve: Curve.EaseOut
      })
      .onClick(() => {
        if (this.clickHandler) {
          this.clickHandler();
        }
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.isPressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.isPressed = false;
        }
      })

      if (this.showDivider) {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(DesignSystem.getBorderColor(this.isLightMode))
          .margin({ left: this.itemIcon ? 48 + DesignSystem.Spacing.md : DesignSystem.Spacing.md })
      }
    }
    .width('100%')
  }

  setOnClick(handler: () => void): AppListItem {
    this.clickHandler = handler;
    return this;
  }
}
