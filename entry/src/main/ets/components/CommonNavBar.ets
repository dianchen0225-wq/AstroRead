import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';
import { NavigationManager } from '../common/NavigationManager';

export interface NavBarAction {
  icon: string;
  text?: string;
  onClick: () => void;
  badge?: string;
}

export interface NavBarConfig {
  title: string | Resource;
  showBack?: boolean;
  backConfirm?: boolean;
  confirmMessage?: string;
  transparent?: boolean;
  rightActions?: NavBarAction[];
  onBackPress?: () => boolean;
}
@ComponentV2
export struct CommonNavBar {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  @Local showConfirmDialog: boolean = false;
  
  @Param title: string | Resource = '';
  @Param showBack: boolean = true;
  @Param backConfirm: boolean = false;
  @Param confirmMessage: string = '确定要返回吗？未保存的内容将丢失。';
  @Param transparent: boolean = false;
  @Param safeAreaTop: number = 0;
  @Param rightActions: NavBarAction[] = [];
  
  private onBackPress?: () => boolean;
  
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

  private handleBackPress(): void {
    if (this.onBackPress) {
      const handled = this.onBackPress();
      if (handled) {
        return;
      }
    }

    if (this.backConfirm) {
      this.showConfirmDialog = true;
    } else {
      NavigationManager.getInstance().navigateBack();
    }
  }

  private confirmBack(): void {
    this.showConfirmDialog = false;
    NavigationManager.getInstance().navigateBack();
  }

  build() {
    Column() {
      Row() {
        if (this.showBack) {
          this.buildBackButton()
        } else {
          Row().width(44)
        }

        this.buildTitle()

        this.buildRightActions()
      }
      .width('100%')
      .height(44)
      .padding({ left: DesignSystem.Spacing.sm, right: DesignSystem.Spacing.sm })
    }
    .width('100%')
    .height(44 + this.safeAreaTop)
    .padding({ top: this.safeAreaTop })
    .backgroundColor(this.transparent ? 'transparent' : DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: this.transparent ? 0 : { bottom: 1 },
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .bindSheet($$this.showConfirmDialog, this.buildConfirmDialog(), {
      height: 'auto',
      backgroundColor: Color.Transparent,
      dragBar: false,
      showClose: false
    })
  }

  @Builder
  buildBackButton() {
    Row() {
      Text('‹')
        .fontSize(DesignSystem.Typography.size.xxl)
        .fontColor(this.transparent ? '#FFFFFF' : DesignSystem.getPrimaryColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.medium)
    }
    .width(44)
    .height(44)
    .borderRadius(DesignSystem.BorderRadius.md)
    .backgroundColor(this.isPressed ?
      DesignSystem.getActiveColor(this.isLightMode) :
      (this.transparent ? 'rgba(255,255,255,0.2)' : DesignSystem.getSecondaryBackgroundColor(this.isLightMode)))
    .justifyContent(FlexAlign.Center)
    .scale({ x: this.isPressed ? 0.92 : 1, y: this.isPressed ? 0.92 : 1 })
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: Curve.EaseOut
    })
    .onClick(() => {
      this.handleBackPress();
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
  }

  @Builder
  buildTitle() {
    if (typeof this.title === 'string') {
      Text(this.title)
        .fontSize(DesignSystem.Typography.size.lg)
        .fontColor(this.transparent ? '#FFFFFF' : DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.semibold)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: DesignSystem.Spacing.sm, right: DesignSystem.Spacing.sm })
    } else {
      Text(this.title)
        .fontSize(DesignSystem.Typography.size.lg)
        .fontColor(this.transparent ? '#FFFFFF' : DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.semibold)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: DesignSystem.Spacing.sm, right: DesignSystem.Spacing.sm })
    }
  }

  @Builder
  buildRightActions() {
    if (this.rightActions && this.rightActions.length > 0) {
      Row({ space: DesignSystem.Spacing.sm }) {
        ForEach(this.rightActions, (action: NavBarAction, index: number) => {
          this.buildActionButton(action)
        })
      }
    } else {
      Row().width(44)
    }
  }

  @Builder
  buildActionButton(action: NavBarAction) {
    Stack() {
      Row() {
        if (action.text) {
          Text(action.text)
            .fontSize(DesignSystem.Typography.size.sm)
            .fontColor(this.transparent ? '#FFFFFF' : DesignSystem.getPrimaryColor(this.isLightMode))
        } else {
          Text(action.icon)
            .fontSize(DesignSystem.Typography.size.xl)
            .fontColor(this.transparent ? '#FFFFFF' : DesignSystem.getPrimaryColor(this.isLightMode))
        }
      }
      .padding({
        left: DesignSystem.Spacing.sm,
        right: DesignSystem.Spacing.sm,
        top: DesignSystem.Spacing.xs,
        bottom: DesignSystem.Spacing.xs
      })
      .borderRadius(DesignSystem.BorderRadius.md)
      .backgroundColor(this.transparent ? 'rgba(255,255,255,0.2)' : 'transparent')
      .onClick(() => {
        action.onClick();
      })

      if (action.badge) {
        Text(action.badge)
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor('#FFFFFF')
          .backgroundColor(DesignSystem.getErrorColor(this.isLightMode))
          .borderRadius(DesignSystem.BorderRadius.full)
          .padding({ left: DesignSystem.Spacing.xs, right: DesignSystem.Spacing.xs })
          .position({ x: '100%', y: 0 })
          .translate({ x: -4, y: -4 })
      }
    }
    .width(44)
    .height(44)
    .alignContent(Alignment.Center)
  }

  @Builder
  buildConfirmDialog() {
    Column() {
      Column() {
        Text('确认返回')
          .fontSize(DesignSystem.Typography.size.lg)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)
          .margin({ bottom: DesignSystem.Spacing.md })

        Text(this.confirmMessage)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .textAlign(TextAlign.Center)
          .lineHeight(22)
          .margin({ bottom: DesignSystem.Spacing.lg })

        Row({ space: DesignSystem.Spacing.md }) {
          Row() {
            Text('取消')
              .fontSize(DesignSystem.Typography.size.base)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .fontWeight(DesignSystem.Typography.weight.medium)
          }
          .layoutWeight(1)
          .height(44)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showConfirmDialog = false;
          })

          Row() {
            Text('确定')
              .fontSize(DesignSystem.Typography.size.base)
              .fontColor('#FFFFFF')
              .fontWeight(DesignSystem.Typography.weight.medium)
          }
          .layoutWeight(1)
          .height(44)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.confirmBack();
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding(DesignSystem.Spacing.lg)
      .borderRadius(DesignSystem.BorderRadius.xl)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    }
    .width('100%')
    .padding(DesignSystem.Spacing.lg)
  }

  setOnBackPress(handler: () => boolean): CommonNavBar {
    this.onBackPress = handler;
    return this;
  }
}
@ComponentV2
export struct PageHeader {
  @Local isLightMode: boolean = true;
  
  @Param title: string | Resource = '';
  @Param subtitle?: string | Resource;
  @Param safeAreaTop: number = 0;
  @Param showBack: boolean = false;
  
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
      if (this.showBack) {
        Row() {
          Row() {
            Text('‹')
              .fontSize(DesignSystem.Typography.size.xxl)
              .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
          }
          .width(40)
          .height(40)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            NavigationManager.getInstance().navigateBack();
          })
          
          Blank()
        }
        .width('100%')
        .margin({ bottom: DesignSystem.Spacing.md })
      }

      if (typeof this.title === 'string') {
        Text(this.title)
          .fontSize(DesignSystem.Typography.size.xxl)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.bold)
          .width('100%')
      } else {
        Text(this.title)
          .fontSize(DesignSystem.Typography.size.xxl)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.bold)
          .width('100%')
      }

      if (this.subtitle) {
        if (typeof this.subtitle === 'string') {
          Text(this.subtitle)
            .fontSize(DesignSystem.Typography.size.sm)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .width('100%')
            .margin({ top: DesignSystem.Spacing.xs })
        } else {
          Text(this.subtitle)
            .fontSize(DesignSystem.Typography.size.sm)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .width('100%')
            .margin({ top: DesignSystem.Spacing.xs })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: this.safeAreaTop + DesignSystem.Spacing.md,
      bottom: DesignSystem.Spacing.md
    })
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }
}
@ComponentV2
export struct SectionHeader {
  @Local isLightMode: boolean = true;
  
  @Param title: string | Resource = '';
  @Param actionText?: string;
  @Param onAction?: () => void;
  
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
      if (typeof this.title === 'string') {
        Text(this.title)
      } else {
        Text(this.title)
      }
      .fontSize(DesignSystem.Typography.size.base)
      .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
      .fontWeight(DesignSystem.Typography.weight.semibold)
      .layoutWeight(1)

      if (this.actionText && this.onAction) {
        Text(this.actionText)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .onClick(() => {
            if (this.onAction) {
              this.onAction();
            }
          })
      }
    }
    .width('100%')
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: DesignSystem.Spacing.md,
      bottom: DesignSystem.Spacing.sm
    })
  }
}
