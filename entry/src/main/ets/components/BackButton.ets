
import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';
import { NavigationManager } from '../common/NavigationManager';

interface SizeConfig {
  buttonSize: number;
  iconSize: number;
  hitArea: number;
}
@ComponentV2
export struct BackButton {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;

  @Param buttonSize: 'small' | 'medium' | 'large' = 'medium';
  @Param style: 'default' | 'minimal' | 'circle' = 'default';
  @Param color: string = '';
  @Param onBack?: () => void;

  private themeListener = (isDark: boolean): void => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }
  private getSizeConfig(): SizeConfig {
    switch (this.buttonSize) {
      case 'small':
        return { buttonSize: 36, iconSize: 18, hitArea: 48 } as SizeConfig;
      case 'large':
        return { buttonSize: 52, iconSize: 28, hitArea: 64 } as SizeConfig;
      default:
        return { buttonSize: 44, iconSize: 22, hitArea: 56 } as SizeConfig;
    }
  }

  private handleBack(): void {
    if (this.onBack) {
      this.onBack();
    } else {
      NavigationManager.getInstance().navigateBack();
    }
  }

  build() {
    Stack() {
      Row() {
        Text('‹')
          .fontSize(this.getSizeConfig().iconSize)
          .fontColor(this.color ?? DesignSystem.getPrimaryColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.bold)
      }
      .width(this.getSizeConfig().buttonSize)
      .height(this.getSizeConfig().buttonSize)
      .borderRadius(this.style === 'circle' ? this.getSizeConfig().buttonSize / 2 : DesignSystem.BorderRadius.md)
      .backgroundColor(this.style === 'minimal' ? 'transparent' : 
        this.isPressed ? DesignSystem.getActiveColor(this.isLightMode) : 
        DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .justifyContent(FlexAlign.Center)
      .border(this.style === 'minimal' ? { width: 0 } : {
        width: 1,
        color: DesignSystem.getBorderColor(this.isLightMode)
      })
      .scale({
        x: this.isPressed ? 0.95 : 1,
        y: this.isPressed ? 0.95 : 1
      })
      .animation({
        duration: DesignSystem.AnimationDuration.fast,
        curve: DesignSystem.AnimationCurve.easeOut
      })
    }
    .width(this.getSizeConfig().hitArea)
    .height(this.getSizeConfig().hitArea)
    .onClick(() => {
      this.handleBack();
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
  }
}
@ComponentV2
export struct PageHeader {
  @Local isLightMode: boolean = true;

  @Param title: string = '';
  @Param @Require subtitle?: string;
  @Param showBack: boolean = true;
  @Param @Require rightAction?: () => void;
  @Param @Require rightIcon?: string;
  @Param safeAreaTop: number = 0;
  @Param @Require onBack?: () => void;

  private themeListener = (isDark: boolean): void => {
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
      if (this.showBack) {
        BackButton({
          buttonSize: 'medium',
          style: 'default',
          onBack: this.onBack
        })
      }

      Column() {
        Text(this.title)
          .fontSize(DesignSystem.Typography.size.xl)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: this.showBack ? DesignSystem.Spacing.sm : 0 })

      if (this.rightIcon) {
        Row() {
          Text(this.rightIcon)
            .fontSize(DesignSystem.IconSize.md)
            .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
        }
        .width(44)
        .height(44)
        .borderRadius(DesignSystem.BorderRadius.md)
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.rightAction) {
            this.rightAction();
          }
        })
      }
    }
    .width('100%')
    .padding({
      left: DesignSystem.Spacing.md,
      right: DesignSystem.Spacing.md,
      top: this.safeAreaTop + DesignSystem.Spacing.sm,
      bottom: DesignSystem.Spacing.sm
    })
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }
}
