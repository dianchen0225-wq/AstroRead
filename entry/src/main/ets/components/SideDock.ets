import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';
import { gestureController } from '../utils/ui/GestureController';

export interface SideDockItem {
  id: string;
  icon: string;
  label: string;
  color: string;
  onTap: () => void;
}

export interface SideDockSection {
  title: string;
  items: SideDockItem[];
}

@ObservedV2
export class SideDockState {
  @Trace isOpen: boolean = false;
  @Trace slideProgress: number = 0;
  @Trace overlayOpacity: number = 0;
  @Trace panelTranslateX: number = -320;
  @Trace edgeGlowOpacity: number = 0;
}

@ComponentV2
export struct SideDock {
  @Param sections: SideDockSection[] = [];
  @Param panelWidth: number = 280;
  @Param edgeGlowWidth: number = 28;
  @Param animationDuration: number = 280;
  @Param screenWidth: number = 360;
  @Param screenHeight: number = 780;
  @Param safeAreaTop: number = 0;

  @Local isLightMode: boolean = true;
  @Local state: SideDockState = new SideDockState();
  @Local startX: number = 0;
  @Local currentSwipeX: number = 0;
  @Local isSwiping: boolean = false;
  @Local edgeIndicatorOpacity: number = 0.4;

  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);

    gestureController.addCallback((event) => {
      if (event.type === 'edge_swipe_hold' && event.isComplete) {
        this.open();
      }
    });
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  open(): void {
    animateTo({
      duration: this.animationDuration,
      curve: Curve.EaseOut
    }, () => {
      this.state.isOpen = true;
      this.state.panelTranslateX = 0;
      this.state.overlayOpacity = 0.4;
      this.state.slideProgress = 1;
    });
  }

  close(): void {
    animateTo({
      duration: this.animationDuration,
      curve: Curve.EaseIn
    }, () => {
      this.state.isOpen = false;
      this.state.panelTranslateX = -this.panelWidth;
      this.state.overlayOpacity = 0;
      this.state.slideProgress = 0;
    });
  }

  toggle(): void {
    if (this.state.isOpen) {
      this.close();
    } else {
      this.open();
    }
  }

  private getGlassBackground(): string {
    if (this.isLightMode) {
      return 'rgba(255,255,255,0.92)';
    } else {
      return 'rgba(22,22,22,0.95)';
    }
  }

  build() {
    Stack() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(this.state.overlayOpacity)
        .visibility(this.state.isOpen ? Visibility.Visible : Visibility.None)
        .onClick(() => {
          this.close();
        })
        .animation({
          duration: this.animationDuration,
          curve: Curve.EaseInOut
        })

      // 侧边面板 - 玻璃光感
      Column() {
        // 顶部手柄区域
        Row() {
          Text('快捷操作')
            .fontSize(DesignSystem.Typography.size.lg)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .fontWeight(DesignSystem.Typography.weight.semibold)

          Blank()

          Text('✕')
            .fontSize(18)
            .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
            .width(32)
            .height(32)
            .borderRadius(16)
            .backgroundColor(this.isLightMode
              ? 'rgba(0,0,0,0.04)'
              : 'rgba(255,255,255,0.06)')
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.close();
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 20, right: 16, top: this.safeAreaTop + 8 })

        // 分隔线
        Divider()
          .width('100%')
          .height(0.5)
          .color(DesignSystem.getBorderColor(this.isLightMode))
          .opacity(0.5)

        // 内容区域
        Scroll() {
          Column() {
            ForEach(this.sections, (section: SideDockSection) => {
              Column() {
                // 分组标题
                Text(section.title)
                  .fontSize(DesignSystem.Typography.size.xs)
                  .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
                  .fontWeight(DesignSystem.Typography.weight.medium)
                  .textCase(TextCase.UpperCase)
                  .letterSpacing(1.5)
                  .opacity(0.7)
                  .width('100%')
                  .padding({ left: 4, bottom: 8 })
                  .margin({ top: 16 })

                // 分组项目
                ForEach(section.items, (item: SideDockItem) => {
                  Row() {
                    // 颜色指示器
                    Circle()
                      .width(8)
                      .height(8)
                      .fill(item.color)
                      .margin({ right: 12 })

                    Text(item.icon)
                      .fontSize(18)
                      .margin({ right: 12 })

                    Text(item.label)
                      .fontSize(DesignSystem.Typography.size.base)
                      .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

                    Blank()

                    Image($r('sys.symbol.chevron_right'))
                      .width(10)
                      .height(10)
                      .fillColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
                      .opacity(0.5)
                  }
                  .width('100%')
                  .height(48)
                  .borderRadius(DesignSystem.BorderRadius.md)
                  .padding({ left: 16, right: 16 })
                  .backgroundColor(Color.Transparent)
                  .onClick(() => {
                    item.onTap();
                    this.close();
                  })
                  .onHover((isHover: boolean) => {
                    // hover 交互由系统处理
                  })
                })

                Divider()
                  .width('100%')
                  .height(0.5)
                  .color(DesignSystem.getBorderColor(this.isLightMode))
                  .opacity(0.3)
                  .margin({ top: 8 })
              }
              .width('100%')
              .padding({ left: 12, right: 12 })
            })
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width(this.panelWidth)
      .height('100%')
      .backgroundColor(this.getGlassBackground())
      .backdropBlur(28)
      .border({
        width: { top: 0, bottom: 0, left: 0, right: 1 },
        color: this.isLightMode
          ? 'rgba(0,0,0,0.06)'
          : 'rgba(255,255,255,0.08)'
      })
      .shadow({
        radius: 20,
        color: this.isLightMode
          ? 'rgba(0,0,0,0.15)'
          : 'rgba(0,0,0,0.6)',
        offsetX: this.state.isOpen ? 8 : 0,
        offsetY: 0
      })
      .translate({ x: this.state.panelTranslateX, y: 0 })
      .animation({
        duration: this.animationDuration,
        curve: Curve.EaseOut
      })
      .zIndex(DesignSystem.ZIndex.popover)

      // 边缘触发条
      if (!this.state.isOpen) {
        Column()
          .width(this.edgeGlowWidth)
          .height('100%')
          .backgroundColor(this.isLightMode
            ? 'rgba(184,134,11,0.08)'
            : 'rgba(232,197,71,0.04)')
          .position({ x: 0, y: 0 })
          .opacity(this.edgeIndicatorOpacity)
          .animation({
            duration: 2000,
            curve: Curve.EaseInOut,
            iterations: -1,
            playMode: PlayMode.AlternateReverse
          })
          .onClick(() => {
            this.open();
          })
          .hitTestBehavior(HitTestMode.Block)
      }
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .visibility(this.state.isOpen ? Visibility.Visible : Visibility.None)
    .hitTestBehavior(this.state.isOpen ? HitTestMode.Block : HitTestMode.None)
    .zIndex(DesignSystem.ZIndex.popover)
  }
}

@ComponentV2
export struct QuickSettingsSideDock {
  @Param screenWidth: number = 360;
  @Param screenHeight: number = 780;
  @Param safeAreaTop: number = 0;

  @Local isLightMode: boolean = true;

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
    SideDock({
      sections: [
        {
          title: '功能',
          items: [
            {
              id: 'shelf',
              icon: '📚',
              label: '我的书架',
              color: DesignSystem.getPrimaryColor(this.isLightMode),
              onTap: () => { /* 导航到书架 */ }
            },
            {
              id: 'search',
              icon: '🔍',
              label: '搜索书籍',
              color: '#4A90D9',
              onTap: () => { /* 导航到搜索 */ }
            },
            {
              id: 'source',
              icon: '📡',
              label: '书源管理',
              color: '#E85D3A',
              onTap: () => { /* 导航到书源 */ }
            },
            {
              id: 'download',
              icon: '⬇️',
              label: '离线下载',
              color: '#2E7D32',
              onTap: () => { /* 下载管理 */ }
            }
          ]
        },
        {
          title: '工具',
          items: [
            {
              id: 'settings',
              icon: '⚙️',
              label: '设置',
              color: '#6A6A6A',
              onTap: () => { /* 导航到设置 */ }
            },
            {
              id: 'theme',
              icon: '🌓',
              label: '切换主题',
              color: '#F5A623',
              onTap: () => { themeManager.toggleTheme(); }
            },
            {
              id: 'cache',
              icon: '🗑️',
              label: '清除缓存',
              color: '#C62828',
              onTap: () => { /* 清除缓存 */ }
            }
          ]
        }
      ],
      panelWidth: 280,
      animationDuration: 280,
      screenWidth: this.screenWidth,
      screenHeight: this.screenHeight,
      safeAreaTop: this.safeAreaTop
    })
  }
}
