import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';

export interface NavItem {
  id: string;
  label: string;
  icon: string;
  activeIcon: string;
}

@ComponentV2
export struct AppNavBar {
  @Local isLightMode: boolean = true;
  
  @Param title: string = '';
  @Param showBack: boolean = false;
  @Param showTitle: boolean = true;
  @Param rightIcon: string = '';
  @Param transparent: boolean = false;
  @Param safeAreaTop: number = 0;
  
  private onBackHandler?: () => void;
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

  build() {
    Row() {
      if (this.showBack) {
        Row() {
          Text('←')
            .fontSize(DesignSystem.Typography.size.xl)
            .fontColor(this.transparent ? '#FFFFFF' : DesignSystem.getPrimaryTextColor(this.isLightMode))
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.onBackHandler) {
            this.onBackHandler();
          }
        })
      } else {
        Row()
          .width(44)
      }

      if (this.showTitle) {
        Text(this.title)
          .fontSize(DesignSystem.Typography.size.lg)
          .fontColor(this.transparent ? '#FFFFFF' : DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Blank()
          .layoutWeight(1)
      }

      if (this.rightIcon) {
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
      } else {
        Row()
          .width(44)
      }
    }
    .width('100%')
    .height(44 + this.safeAreaTop)
    .padding({ top: this.safeAreaTop })
    .backgroundColor(this.transparent ? 'transparent' : DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }

  onBack(handler: () => void): AppNavBar {
    this.onBackHandler = handler;
    return this;
  }

  onRightClick(handler: () => void): AppNavBar {
    this.onRightClickHandler = handler;
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
