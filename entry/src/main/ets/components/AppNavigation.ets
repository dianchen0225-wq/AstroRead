import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';
import { NavigationManager } from '../common/NavigationManager';

export interface NavItem {
  id: string;
  label: string;
  icon: string;
  activeIcon: string;
}

export interface NavBarAction {
  icon: string;
  text?: string;
  onClick: () => void;
  badge?: string;
}

@ComponentV2
export struct AppNavBar {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  @Local showConfirmDialog: boolean = false;

  @Param title: string | Resource = '';
  @Param showBack: boolean = true;
  @Param showTitle: boolean = true;
  @Param transparent: boolean = false;
  @Param safeAreaTop: number = 0;
  @Param rightActions: NavBarAction[] = [];
  @Param rightIcon: string = '';
  @Param backConfirm: boolean = false;
  @Param confirmMessage: string = '确定要返回吗？未保存的内容将丢失。';

  private onBackHandler?: () => void;
  private onBackPressHandler?: () => boolean;
  private onRightClickHandler?: () => void;

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
    if (this.onBackPressHandler) {
      const handled = this.onBackPressHandler();
      if (handled) {
        return;
      }
    }

    if (this.onBackHandler) {
      this.onBackHandler();
      return;
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

        if (this.rightActions && this.rightActions.length > 0) {
          this.buildRightActions()
        } else if (this.rightIcon) {
          this.buildRightIcon()
        } else {
          Row().width(44)
        }
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

  @Builder
  buildRightActions() {
    Row({ space: DesignSystem.Spacing.sm }) {
      ForEach(this.rightActions, (action: NavBarAction) => {
        this.buildActionButton(action)
      })
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
  buildRightIcon() {
    Row() {
      Text(this.rightIcon)
        .fontSize(DesignSystem.Typography.size.xl)
        .fontColor(this.transparent ? '#FFFFFF' : DesignSystem.getPrimaryTextColor(this.isLightMode))
    }
    .width(44)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.onRightClickHandler) {
        this.onRightClickHandler();
      }
    })
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
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
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

  onBack(handler: () => void): AppNavBar {
    this.onBackHandler = handler;
    return this;
  }

  onRightClick(handler: () => void): AppNavBar {
    this.onRightClickHandler = handler;
    return this;
  }

  setOnBackPress(handler: () => boolean): AppNavBar {
    this.onBackPressHandler = handler;
    return this;
  }
}

@ComponentV2
export struct AppTabBar {
  @Local isLightMode: boolean = true;

  @Param items: NavItem[] = [];
  @Param activeId: string = '';
  @Param safeAreaBottom: number = 0;

  private onItemClickHandler?: (id: string) => void;

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
      ForEach(this.items, (item: NavItem) => {
        Column() {
          Text(this.activeId === item.id ? item.activeIcon : item.icon)
            .fontSize(24)
            .fontColor(this.activeId === item.id ?
              DesignSystem.getPrimaryColor(this.isLightMode) :
              DesignSystem.getTertiaryTextColor(this.isLightMode))
            .animation({
              duration: DesignSystem.AnimationDuration.fast,
              curve: DesignSystem.AnimationCurve.easeOut
            })

          Text(item.label)
            .fontSize(10)
            .fontColor(this.activeId === item.id ?
              DesignSystem.getPrimaryColor(this.isLightMode) :
              DesignSystem.getTertiaryTextColor(this.isLightMode))
            .fontWeight(this.activeId === item.id ?
              DesignSystem.Typography.weight.medium :
              DesignSystem.Typography.weight.regular)
            .margin({ top: 2 })
            .animation({
              duration: DesignSystem.AnimationDuration.fast,
              curve: DesignSystem.AnimationCurve.easeOut
            })
        }
        .layoutWeight(1)
        .height(56)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.onItemClickHandler) {
            this.onItemClickHandler(item.id);
          }
        })
      })
    }
    .width('100%')
    .height(56 + this.safeAreaBottom)
    .padding({ bottom: this.safeAreaBottom })
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    .border({
      width: { top: 1, bottom: 0, left: 0, right: 0 },
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .shadow({
      radius: 8,
      color: this.isLightMode ? 'rgba(0,0,0,0.05)' : 'rgba(0,0,0,0.3)',
      offsetX: 0,
      offsetY: -2
    })
  }

  onItemClick(handler: (id: string) => void): AppTabBar {
    this.onItemClickHandler = handler;
    return this;
  }
}

@ComponentV2
export struct AppSegment {
  @Local isLightMode: boolean = true;

  @Param items: string[] = [];
  @Param activeIndex: number = 0;
  @Param fullWidth: boolean = false;

  private onIndexChangeHandler?: (index: number) => void;

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
      ForEach(this.items, (item: string, index: number) => {
        Row() {
          Text(item)
            .fontSize(DesignSystem.Typography.size.sm)
            .fontColor(this.activeIndex === index ?
              '#FFFFFF' :
              DesignSystem.getPrimaryTextColor(this.isLightMode))
            .fontWeight(this.activeIndex === index ?
              DesignSystem.Typography.weight.medium :
              DesignSystem.Typography.weight.regular)
        }
        .height(32)
        .padding({ left: DesignSystem.Spacing.md, right: DesignSystem.Spacing.md })
        .borderRadius(DesignSystem.BorderRadius.md)
        .backgroundColor(this.activeIndex === index ?
          DesignSystem.getPrimaryColor(this.isLightMode) :
          'transparent')
        .justifyContent(FlexAlign.Center)
        .layoutWeight(this.fullWidth ? 1 : 0)
        .onClick(() => {
          if (this.onIndexChangeHandler) {
            this.onIndexChangeHandler(index);
          }
        })
        .animation({
          duration: DesignSystem.AnimationDuration.fast,
          curve: DesignSystem.AnimationCurve.easeOut
        })
      })
    }
    .width(this.fullWidth ? '100%' : undefined)
    .padding(DesignSystem.Spacing.xs)
    .borderRadius(DesignSystem.BorderRadius.lg)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }

  onIndexChange(handler: (index: number) => void): AppSegment {
    this.onIndexChangeHandler = handler;
    return this;
  }
}

@ComponentV2
export struct PageHeader {
  @Local isLightMode: boolean = true;

  @Param title: string | Resource = '';
  @Param subtitle: string | Resource = '';
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

      Text(this.title)
        .fontSize(DesignSystem.Typography.size.xxl)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.bold)
        .width('100%')

      if (this.subtitle) {
        Text(this.subtitle)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .width('100%')
          .margin({ top: DesignSystem.Spacing.xs })
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
  @Param actionText: string = '';
  @Param onAction: () => void = () => {};

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
      Text(this.title)
        .fontSize(DesignSystem.Typography.size.base)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.semibold)
        .layoutWeight(1)

      if (this.actionText.length > 0) {
        Text(this.actionText)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .onClick(() => {
            this.onAction();
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
