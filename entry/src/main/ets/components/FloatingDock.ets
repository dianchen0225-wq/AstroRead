import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';

export interface DockItem {
  id: string;
  icon: string;
  label: string;
  badge?: string;
  enabled: boolean;
  route?: string;
}

export interface FloatingDockConfig {
  items: DockItem[];
  activeIndex: number;
  position: 'bottom' | 'top';
  collapsedWidth: number;
  expandedWidth: number;
  height: number;
  autoHide: boolean;
  autoHideDelay: number;
  glassIntensity: number;
  enableGlow: boolean;
  enableHaptic: boolean;
}

const DEFAULT_GLASS_INTENSITY = 0.85;

@ObservedV2
export class FloatingDockState {
  @Trace isVisible: boolean = true;
  @Trace isExpanded: boolean = false;
  @Trace motionProgress: number = 0;
  @Trace dockOpacity: number = 1.0;
  @Trace dockTranslateY: number = 0;
  @Trace glassBlur: number = 24;
  @Trace glowOpacity: number = 0.15;
  @Trace activeGlowX: number = 0;
}

@ComponentV2
export struct FloatingDock {
  @Param items: DockItem[] = [];
  @Param activeIndex: number = 0;
  @Param onItemClick: (index: number, item: DockItem) => void = () => {};
  @Param dockPosition: 'bottom' | 'top' = 'bottom';
  @Param collapsedWidth: number = 64;
  @Param expandedWidth: number = 320;
  @Param dockHeight: number = 56;
  @Param autoHide: boolean = false;
  @Param autoHideDelay: number = 3000;
  @Param glassIntensity: number = 0.85;
  @Param enableGlow: boolean = true;
  @Param screenWidth: number = 360;
  @Param screenHeight: number = 780;
  @Param safeAreaBottom: number = 0;
  @Param safeAreaTop: number = 0;

  @Local isLightMode: boolean = true;
  @Local state: FloatingDockState = new FloatingDockState();
  @Local hideTimer: number = -1;
  @Local internalExpanded: boolean = false;

  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    this.state.isVisible = true;

    if (this.autoHide) {
      this.startAutoHide();
    }

    // 入场动画
    setTimeout(() => {
      animateTo({
        duration: 400,
        curve: Curve.Smooth
      }, () => {
        this.state.dockTranslateY = 0;
        this.state.dockOpacity = 1.0;
      });
    }, 100);
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
    this.clearAutoHide();
  }

  private startAutoHide(): void {
    this.clearAutoHide();
    this.hideTimer = setTimeout(() => {
      this.hideDock();
    }, this.autoHideDelay);
  }

  private clearAutoHide(): void {
    if (this.hideTimer !== -1) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
  }

  hideDock(): void {
    animateTo({
      duration: 250,
      curve: Curve.EaseOut
    }, () => {
      this.state.isVisible = false;
      this.state.dockOpacity = 0.3;
      this.state.dockTranslateY = this.dockPosition === 'bottom' ? 80 : -80;
    });
  }

  showDock(): void {
    this.clearAutoHide();
    animateTo({
      duration: 200,
      curve: Curve.EaseOut
    }, () => {
      this.state.isVisible = true;
      this.state.dockOpacity = 1.0;
      this.state.dockTranslateY = 0;
    });

    if (this.autoHide) {
      this.startAutoHide();
    }
  }

  toggleExpand(): void {
    this.internalExpanded = !this.internalExpanded;
    this.showDock();
  }

  private getDockWidth(): number {
    return this.internalExpanded ? this.expandedWidth : this.collapsedWidth;
  }

  private getGlassBackground(): string {
    const alpha = Math.floor(this.glassIntensity * 255).toString(16).padStart(2, '0');
    if (this.isLightMode) {
      return `#FFFFFF${alpha}`;
    } else {
      return `#1A1A1A${alpha}`;
    }
  }

  private getBorderColor(): string {
    return this.isLightMode
      ? `rgba(255,255,255,0.5)`
      : `rgba(255,255,255,0.1)`;
  }

  private getGlowColor(): string {
    return this.isLightMode
      ? `rgba(184,134,11,${this.state.glowOpacity})`
      : `rgba(232,197,71,${this.state.glowOpacity * 1.3})`;
  }

  build() {
    Stack() {
      // 底部玻璃光感Dock
      Stack() {
        Column() {
          if (this.internalExpanded) {
            this.buildExpandedContent()
          } else {
            this.buildCollapsedContent()
          }
        }
        .width('100%')
        .height('100%')
      }
      .width(this.getDockWidth())
      .height(this.dockHeight)
      .borderRadius(this.dockHeight / 2)
      .backgroundColor(this.getGlassBackground())
      .backdropBlur(this.state.glassBlur)
      .border({
        width: 1,
        color: this.getBorderColor()
      })
      .shadow({
        radius: this.isLightMode ? 20 : 24,
        color: this.isLightMode
          ? 'rgba(0,0,0,0.12)'
          : 'rgba(0,0,0,0.5)',
        offsetX: 0,
        offsetY: this.dockPosition === 'bottom' ? 8 : -8
      })
      .opacity(this.state.dockOpacity)
      .translate({ x: 0, y: this.state.dockTranslateY })
      .scale({
        x: this.state.isVisible ? 1 : 0.92,
        y: this.state.isVisible ? 1 : 0.92
      })
      .position(this.getDockPosition())
      .animation({
        duration: 250,
        curve: Curve.EaseInOut
      })
      .onClick(() => {
        this.showDock();
      })

      // 光晕装饰
      if (this.enableGlow && this.state.isVisible) {
        Circle()
          .width(this.dockHeight * 0.6)
          .height(this.dockHeight * 0.15)
          .fill(this.getGlowColor())
          .position({
            x: `calc(50% - ${this.dockHeight * 0.3}px)`,
            y: this.dockPosition === 'bottom' ? 0 : this.dockHeight - 2
          })
          .animation({
            duration: 400,
            curve: Curve.EaseOut
          })
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  buildExpandedContent() {
    Row() {
      ForEach(this.items, (item: DockItem, index: number) => {
        if (item.enabled) {
          Column() {
            Text(item.icon)
              .fontSize(20)
              .fontColor(this.activeIndex === index
                ? DesignSystem.getPrimaryColor(this.isLightMode)
                : DesignSystem.getSecondaryTextColor(this.isLightMode))
              .scale({
                x: this.activeIndex === index ? 1.15 : 1,
                y: this.activeIndex === index ? 1.15 : 1
              })
              .animation({ duration: 200, curve: Curve.EaseOut })

            Text(item.label)
              .fontSize(10)
              .fontColor(this.activeIndex === index
                ? DesignSystem.getPrimaryColor(this.isLightMode)
                : DesignSystem.getSecondaryTextColor(this.isLightMode))
              .margin({ top: 2 })
              .animation({ duration: 200, curve: Curve.EaseOut })
          }
          .padding({ left: 6, right: 6 })
          .borderRadius(12)
          .backgroundColor(this.activeIndex === index
            ? (this.isLightMode ? 'rgba(184,134,11,0.1)' : 'rgba(232,197,71,0.15)')
            : Color.Transparent)
          .onClick(() => {
            this.showDock();
            this.onItemClick(index, item);
          })

          if (item.badge) {
            Badge({
              value: item.badge,
              position: BadgePosition.RightTop,
              style: { badgeSize: 14, badgeColor: DesignSystem.getErrorColor(this.isLightMode) }
            })
          }
        }
      })

      // 折叠按钮
      Column() {
        Text('⋯')
          .fontSize(16)
          .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
      }
      .width(28)
      .height(28)
      .borderRadius(14)
      .backgroundColor(this.isLightMode
        ? 'rgba(0,0,0,0.04)'
        : 'rgba(255,255,255,0.06)')
      .onClick(() => {
        this.toggleExpand();
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildCollapsedContent() {
    Row() {
      // 中心主图标
      Text(this.items[this.activeIndex]?.icon || '🏠')
        .fontSize(24)
        .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
        .scale({ x: 1.1, y: 1.1 })
        .animation({ duration: 200, curve: Curve.EaseOut })

      Image($r('sys.symbol.chevron_up'))
        .width(12)
        .height(12)
        .fillColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
        .margin({ left: 4 })
        .rotate({ angle: 0 })
        .animation({ duration: 200 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.toggleExpand();
    })
  }

  private getDockPosition(): Position {
    const dockWidth = this.getDockWidth();
    const leftX = (this.screenWidth - dockWidth) / 2;
    const bottomGap = this.safeAreaBottom > 0
      ? this.safeAreaBottom + 8
      : 20;

    if (this.dockPosition === 'bottom') {
      return {
        x: leftX,
        y: this.screenHeight - this.dockHeight - bottomGap
      };
    } else {
      return {
        x: leftX,
        y: this.safeAreaTop > 0 ? this.safeAreaTop + 8 : 8
      };
    }
  }
}

@ComponentV2
export struct SimpleFloatingDock {
  @Param items: DockItem[] = [];
  @Param activeIndex: number = 0;
  @Param onItemClick: (index: number, item: DockItem) => void = () => {};
  @Param screenWidth: number = 360;
  @Param screenHeight: number = 780;
  @Param safeAreaBottom: number = 0;

  @Local isLightMode: boolean = true;
  @Local isVisible: boolean = true;
  @Local dockOpacity: number = 1;
  @Local dockTranslateY: number = 0;

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

  setVisible(visible: boolean): void {
    animateTo({
      duration: 250,
      curve: Curve.EaseInOut
    }, () => {
      this.isVisible = visible;
      this.dockTranslateY = visible ? 0 : 100;
      this.dockOpacity = visible ? 1 : 0;
    });
  }

  build() {
    Row() {
      ForEach(this.items, (item: DockItem, index: number) => {
        Column() {
          Text(item.icon)
            .fontSize(20)
            .fontColor(this.activeIndex === index
              ? DesignSystem.getPrimaryColor(this.isLightMode)
              : DesignSystem.getSecondaryTextColor(this.isLightMode))
            .scale({
              x: this.activeIndex === index ? 1.15 : 1,
              y: this.activeIndex === index ? 1.15 : 1
            })
            .animation({ duration: 200, curve: Curve.EaseOut })

          Text(item.label)
            .fontSize(10)
            .fontColor(this.activeIndex === index
              ? DesignSystem.getPrimaryColor(this.isLightMode)
              : DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ top: 2 })
        }
        .padding({ left: 12, right: 12 })
        .borderRadius(14)
        .backgroundColor(this.activeIndex === index
          ? (this.isLightMode ? 'rgba(184,134,11,0.1)' : 'rgba(232,197,71,0.15)')
          : Color.Transparent)
        .onClick(() => {
          if (item.enabled) {
            this.onItemClick(index, item);
          }
        })
      })
    }
    .width(300)
    .height(56)
    .borderRadius(28)
    .backgroundColor(this.isLightMode
      ? 'rgba(255,255,255,0.85)'
      : 'rgba(26,26,26,0.9)')
    .backdropBlur(24)
    .border({
      width: 1,
      color: this.isLightMode
        ? 'rgba(255,255,255,0.5)'
        : 'rgba(255,255,255,0.1)'
    })
    .shadow({
      radius: 16,
      color: this.isLightMode
        ? 'rgba(0,0,0,0.1)'
        : 'rgba(0,0,0,0.5)',
      offsetX: 0,
      offsetY: 6
    })
    .opacity(this.dockOpacity)
    .translate({ x: 0, y: this.dockTranslateY })
    .position({
      x: (this.screenWidth - 300) / 2,
      y: this.screenHeight - 56 - (this.safeAreaBottom > 0 ? this.safeAreaBottom + 8 : 20)
    })
    .justifyContent(FlexAlign.SpaceEvenly)
    .animation({
      duration: 250,
      curve: Curve.EaseInOut
    })
  }
}
