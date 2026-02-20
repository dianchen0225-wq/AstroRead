import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';

export type BadgeVariant = 'default' | 'success' | 'warning' | 'error' | 'info';
export type BadgeSize = 'sm' | 'md' | 'lg';

@ComponentV2
export struct AppBadge {
  @Local isLightMode: boolean = true;
  
  @Param text: string = '';
  @Param variant: BadgeVariant = 'default';
  @Param size: BadgeSize = 'md';
  @Param dot: boolean = false;
  @Param count: number = 0;
  
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
    switch (this.variant) {
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

  private getSize(): { height: number; fontSize: number; padding: number } {
    switch (this.size) {
      case 'sm':
        return { height: 16, fontSize: 10, padding: 4 };
      case 'lg':
        return { height: 24, fontSize: 14, padding: 8 };
      default:
        return { height: 20, fontSize: 12, padding: 6 };
    }
  }

  build() {
    if (this.dot) {
      Row()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(this.getBackgroundColor())
    } else if (this.count > 0) {
      Row() {
        Text(this.count > 99 ? '99+' : this.count.toString())
          .fontSize(this.getSize().fontSize)
          .fontColor('#FFFFFF')
          .fontWeight(DesignSystem.Typography.weight.medium)
      }
      .height(this.getSize().height)
      .padding({ left: this.getSize().padding, right: this.getSize().padding })
      .borderRadius(this.getSize().height / 2)
      .backgroundColor(this.getBackgroundColor())
      .justifyContent(FlexAlign.Center)
    } else if (this.text) {
      Row() {
        Text(this.text)
          .fontSize(this.getSize().fontSize)
          .fontColor('#FFFFFF')
          .fontWeight(DesignSystem.Typography.weight.medium)
      }
      .height(this.getSize().height)
      .padding({ left: this.getSize().padding, right: this.getSize().padding })
      .borderRadius(this.getSize().height / 2)
      .backgroundColor(this.getBackgroundColor())
      .justifyContent(FlexAlign.Center)
    }
  }
}

@ComponentV2
export struct AppLoading {
  @Local isLightMode: boolean = true;
  
  @Param size: number = 40;
  @Param text: string = '';
  @Param fullScreen: boolean = false;
  
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
        .width(this.size)
        .height(this.size)
        .color(DesignSystem.getPrimaryColor(this.isLightMode))
      
      if (this.text) {
        Text(this.text)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .margin({ top: DesignSystem.Spacing.md })
      }
    }
    .width(this.fullScreen ? '100%' : undefined)
    .height(this.fullScreen ? '100%' : undefined)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.fullScreen ? DesignSystem.getPrimaryBackgroundColor(this.isLightMode) : 'transparent')
  }
}

@ComponentV2
export struct AppEmpty {
  @Local isLightMode: boolean = true;
  
  @Param icon: string = '📭';
  @Param title: string = '暂无数据';
  @Param description: string = '';
  @Param actionText: string = '';
  
  private onActionHandler?: () => void;
  
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
      Text(this.icon)
        .fontSize(48)
        .margin({ bottom: DesignSystem.Spacing.lg })
      
      Text(this.title)
        .fontSize(DesignSystem.Typography.size.lg)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.medium)
        .margin({ bottom: DesignSystem.Spacing.sm })
      
      if (this.description) {
        Text(this.description)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .textAlign(TextAlign.Center)
          .margin({ bottom: DesignSystem.Spacing.lg })
      }
      
      if (this.actionText && this.onActionHandler) {
        Row() {
          Text(this.actionText)
            .fontSize(DesignSystem.Typography.size.sm)
            .fontColor('#FFFFFF')
            .fontWeight(DesignSystem.Typography.weight.medium)
        }
        .padding({ left: DesignSystem.Spacing.lg, right: DesignSystem.Spacing.lg, top: DesignSystem.Spacing.sm, bottom: DesignSystem.Spacing.sm })
        .borderRadius(DesignSystem.BorderRadius.md)
        .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
        .onClick(() => {
          if (this.onActionHandler) {
            this.onActionHandler();
          }
        })
      }
    }
    .width('100%')
    .padding(DesignSystem.Spacing.xxl)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  onAction(handler: () => void): AppEmpty {
    this.onActionHandler = handler;
    return this;
  }
}

@ComponentV2
export struct AppDivider {
  @Local isLightMode: boolean = true;
  
  @Param vertical: boolean = false;
  @Param dashed: boolean = false;
  @Param margin: number = DesignSystem.Spacing.md;
  
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
      .width(this.vertical ? 1 : '100%')
      .height(this.vertical ? '100%' : 1)
      .margin(this.vertical ? 0 : { top: this.margin, bottom: this.margin })
      .backgroundColor(DesignSystem.getBorderColor(this.isLightMode))
  }
}

@ComponentV2
export struct AppToast {
  @Local isLightMode: boolean = true;
  @Local visible: boolean = false;
  
  @Param message: string = '';
  @Param type: 'info' | 'success' | 'warning' | 'error' = 'info';
  @Param duration: number = 2000;
  
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

  show(message: string, type: 'info' | 'success' | 'warning' | 'error' = 'info'): void {
    this.message = message;
    this.type = type;
    this.visible = true;
    
    setTimeout(() => {
      this.visible = false;
    }, this.duration);
  }

  private getBackgroundColor(): string {
    switch (this.type) {
      case 'success':
        return DesignSystem.getSuccessColor(this.isLightMode);
      case 'warning':
        return DesignSystem.getWarningColor(this.isLightMode);
      case 'error':
        return DesignSystem.getErrorColor(this.isLightMode);
      default:
        return this.isLightMode ? 'rgba(0,0,0,0.8)' : 'rgba(255,255,255,0.9)';
    }
  }

  private getTextColor(): string {
    return this.type === 'info' ? '#FFFFFF' : '#FFFFFF';
  }

  build() {
    if (this.visible) {
      Column() {
        Text(this.message)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(this.getTextColor())
          .fontWeight(DesignSystem.Typography.weight.medium)
      }
      .padding({ left: DesignSystem.Spacing.lg, right: DesignSystem.Spacing.lg, top: DesignSystem.Spacing.md, bottom: DesignSystem.Spacing.md })
      .borderRadius(DesignSystem.BorderRadius.lg)
      .backgroundColor(this.getBackgroundColor())
      .shadow({
        radius: 8,
        color: 'rgba(0,0,0,0.15)',
        offsetX: 0,
        offsetY: 4
      })
      .opacity(this.visible ? 1 : 0)
      .animation({
        duration: DesignSystem.AnimationDuration.normal,
        curve: DesignSystem.AnimationCurve.easeOut
      })
    }
  }
}
