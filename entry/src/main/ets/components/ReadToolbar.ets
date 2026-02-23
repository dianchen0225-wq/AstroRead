/**
 * Copyright (c) 2025 AstroRead Project
 * 阅读页面工具栏组件
 * 提供统一的阅读功能入口和交互体验
 */

import { DesignSystem } from '../common/DesignSystem';
import { ReadConfig } from '../models/ReadConfig';

export interface ToolbarConfig {
  bookName: string;
  chapterTitle: string;
  chapterIndex: number;
  totalChapters: number;
  readConfig: ReadConfig;
}

export interface ToolbarCallbacks {
  onBack: () => void;
  onShowChapterList: () => void;
  onShowSettings: () => void;
  onPrevChapter: () => void;
  onNextChapter: () => void;
  onFontSizeChange: (size: number) => void;
  onPageTurnModeChange: (mode: string) => void;
  onNightModeChange: (isNight: boolean) => void;
}

@Component
export struct ReadToolbar {
  @Prop isVisible: boolean = false;
  @Prop isLightMode: boolean = true;
  @Prop config: ToolbarConfig = {
    bookName: '',
    chapterTitle: '',
    chapterIndex: 0,
    totalChapters: 0,
    readConfig: {
      fontSize: 18,
      lineSpacing: 1.5,
      letterSpacing: 0,
      pageTurnMode: 'cover',
      backgroundColor: '#FFFFFF',
      textColor: '#333333',
      isNightMode: false,
      brightness: 0.5,
      autoScroll: false,
      scrollSpeed: 50,
      fontFamily: 'HarmonyOS Sans',
      margins: { top: 20, bottom: 20, left: 20, right: 20 },
      volumeKeyPageTurn: true,
      clickPageTurn: true
    }
  };
  @Prop callbacks: ToolbarCallbacks = {
    onBack: () => {},
    onShowChapterList: () => {},
    onShowSettings: () => {},
    onPrevChapter: () => {},
    onNextChapter: () => {},
    onFontSizeChange: (size: number) => {},
    onPageTurnModeChange: (mode: string) => {},
    onNightModeChange: (isNight: boolean) => {}
  };

  @State private toolbarOpacity: number = 0;
  @State private topBarTranslateY: number = -100;
  @State private bottomBarTranslateY: number = 100;

  aboutToAppear(): void {
    if (this.isVisible) {
      this.showToolbar();
    }
  }

  showToolbar(): void {
    animateTo({
      duration: 250,
      curve: Curve.EaseOut
    }, () => {
      this.toolbarOpacity = 1;
      this.topBarTranslateY = 0;
      this.bottomBarTranslateY = 0;
    });
  }

  hideToolbar(): void {
    animateTo({
      duration: 200,
      curve: Curve.EaseIn
    }, () => {
      this.toolbarOpacity = 0;
      this.topBarTranslateY = -100;
      this.bottomBarTranslateY = 100;
    });
  }

  getPageTurnModeText(mode: string): string {
    const modeMap: Record<string, string> = {
      'cover': '覆盖',
      'slide': '滑动',
      'scroll': '滚动',
      'simulation': '仿真'
    };
    return modeMap[mode] || mode;
  }

  @Builder
  buildTopBar(): void {
    Row() {
      Button() {
        Text('‹')
          .fontSize(28)
          .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.medium)
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .margin({ right: DesignSystem.Spacing.md })
      .onClick(() => {
        this.callbacks.onBack();
      })

      Column() {
        Text(this.config.bookName)
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.config.chapterTitle) {
          Text(this.config.chapterTitle)
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: DesignSystem.Spacing.xs })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: DesignSystem.Spacing.lg,
      bottom: DesignSystem.Spacing.lg
    })
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: { bottom: 1 },
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
  }

  @Builder
  buildQuickActions(): void {
    Row() {
      this.QuickActionButton('目录', () => {
        this.callbacks.onShowChapterList();
      })

      this.QuickActionButton('设置', () => {
        this.callbacks.onShowSettings();
      })

      this.QuickActionButton('A-', () => {
        const newSize = Math.max(this.config.readConfig.fontSize - 2, 12);
        this.callbacks.onFontSizeChange(newSize);
      })

      this.QuickActionButton('A+', () => {
        const newSize = Math.min(this.config.readConfig.fontSize + 2, 32);
        this.callbacks.onFontSizeChange(newSize);
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: DesignSystem.Spacing.md,
      bottom: DesignSystem.Spacing.md
    })
  }

  @Builder
  QuickActionButton(label: string, action: () => void): void {
    Text(label)
      .fontSize(DesignSystem.Typography.size.sm)
      .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
      .backgroundColor(DesignSystem.getTertiaryBackgroundColor(this.isLightMode))
      .padding({
        left: DesignSystem.Spacing.lg,
        right: DesignSystem.Spacing.lg,
        top: DesignSystem.Spacing.sm,
        bottom: DesignSystem.Spacing.sm
      })
      .borderRadius(DesignSystem.BorderRadius.md)
      .onClick(() => {
        action();
      })
  }

  @Builder
  buildChapterNavigation(): void {
    Row() {
      Column() {
        Text('上一章')
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(this.config.chapterIndex > 0 ? 
            DesignSystem.getPrimaryTextColor(this.isLightMode) : 
            DesignSystem.getTertiaryTextColor(this.isLightMode))
          .backgroundColor(this.config.chapterIndex > 0 ? 
            DesignSystem.getTertiaryBackgroundColor(this.isLightMode) : 
            'transparent')
          .padding({
            left: DesignSystem.Spacing.xl,
            right: DesignSystem.Spacing.xl,
            top: DesignSystem.Spacing.sm,
            bottom: DesignSystem.Spacing.sm
          })
          .borderRadius(DesignSystem.BorderRadius.md)
          .onClick(() => {
            if (this.config.chapterIndex > 0) {
              this.callbacks.onPrevChapter();
            }
          })
      }

      Column() {
        Text(`${this.config.chapterIndex + 1} / ${this.config.totalChapters}`)
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))

        Progress({
          value: this.config.chapterIndex + 1,
          total: this.config.totalChapters > 0 ? this.config.totalChapters : 1,
          type: ProgressType.Linear
        })
          .width(100)
          .height(3)
          .margin({ top: DesignSystem.Spacing.xs })
          .color(DesignSystem.getPrimaryColor(this.isLightMode))
          .backgroundColor(DesignSystem.getBorderColor(this.isLightMode))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column() {
        Text('下一章')
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(this.config.chapterIndex < this.config.totalChapters - 1 ? 
            DesignSystem.getPrimaryTextColor(this.isLightMode) : 
            DesignSystem.getTertiaryTextColor(this.isLightMode))
          .backgroundColor(this.config.chapterIndex < this.config.totalChapters - 1 ? 
            DesignSystem.getTertiaryBackgroundColor(this.isLightMode) : 
            'transparent')
          .padding({
            left: DesignSystem.Spacing.xl,
            right: DesignSystem.Spacing.xl,
            top: DesignSystem.Spacing.sm,
            bottom: DesignSystem.Spacing.sm
          })
          .borderRadius(DesignSystem.BorderRadius.md)
          .onClick(() => {
            if (this.config.chapterIndex < this.config.totalChapters - 1) {
              this.callbacks.onNextChapter();
            }
          })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: DesignSystem.Spacing.sm,
      bottom: DesignSystem.Spacing.sm
    })
  }

  @Builder
  buildPageTurnModes(): void {
    Column() {
      Text('翻页模式')
        .fontSize(DesignSystem.Typography.size.xs)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .width('100%')
        .margin({ bottom: DesignSystem.Spacing.sm })

      Row() {
        ForEach(['cover', 'slide', 'scroll', 'simulation'], (mode: string) => {
          Text(this.getPageTurnModeText(mode))
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(this.config.readConfig.pageTurnMode === mode ? 
              '#FFFFFF' : 
              DesignSystem.getPrimaryTextColor(this.isLightMode))
            .backgroundColor(this.config.readConfig.pageTurnMode === mode ? 
              DesignSystem.getPrimaryColor(this.isLightMode) : 
              DesignSystem.getTertiaryBackgroundColor(this.isLightMode))
            .padding({
              left: DesignSystem.Spacing.md,
              right: DesignSystem.Spacing.md,
              top: DesignSystem.Spacing.xs,
              bottom: DesignSystem.Spacing.xs
            })
            .borderRadius(DesignSystem.BorderRadius.sm)
            .margin({ right: DesignSystem.Spacing.sm })
            .onClick(() => {
              this.callbacks.onPageTurnModeChange(mode);
            })
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: DesignSystem.Spacing.sm,
      bottom: DesignSystem.Spacing.md
    })
  }

  @Builder
  buildBottomBar(): void {
    Column() {
      this.buildQuickActions()
      this.buildChapterNavigation()
      this.buildPageTurnModes()
    }
    .width('100%')
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: { top: 1 },
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
  }

  build() {
    Stack() {
      Column() {
        Column() {
          this.buildTopBar()
        }
        .width('100%')
        .translate({ y: this.topBarTranslateY })

        Blank()

        Column() {
          this.buildBottomBar()
        }
        .width('100%')
        .translate({ y: this.bottomBarTranslateY })
      }
      .width('100%')
      .height('100%')
      .opacity(this.toolbarOpacity)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}

@Component
export struct ReadToolbarOverlay {
  @Prop isVisible: boolean = false;
  @Prop isLightMode: boolean = true;
  @Prop config: ToolbarConfig = {
    bookName: '',
    chapterTitle: '',
    chapterIndex: 0,
    totalChapters: 0,
    readConfig: {
      fontSize: 18,
      lineSpacing: 1.5,
      letterSpacing: 0,
      pageTurnMode: 'cover',
      backgroundColor: '#FFFFFF',
      textColor: '#333333',
      isNightMode: false,
      brightness: 0.5,
      autoScroll: false,
      scrollSpeed: 50,
      fontFamily: 'HarmonyOS Sans',
      margins: { top: 20, bottom: 20, left: 20, right: 20 },
      volumeKeyPageTurn: true,
      clickPageTurn: true
    }
  };
  @Prop callbacks: ToolbarCallbacks = {
    onBack: () => {},
    onShowChapterList: () => {},
    onShowSettings: () => {},
    onPrevChapter: () => {},
    onNextChapter: () => {},
    onFontSizeChange: (size: number) => {},
    onPageTurnModeChange: (mode: string) => {},
    onNightModeChange: (isNight: boolean) => {}
  };

  @State private overlayOpacity: number = 0;
  @State private contentOpacity: number = 0;

  aboutToAppear(): void {
    if (this.isVisible) {
      this.showOverlay();
    }
  }

  showOverlay(): void {
    animateTo({
      duration: 200,
      curve: Curve.EaseOut
    }, () => {
      this.overlayOpacity = 1;
    });

    setTimeout(() => {
      animateTo({
        duration: 150,
        curve: Curve.EaseOut
      }, () => {
        this.contentOpacity = 1;
      });
    }, 50);
  }

  hideOverlay(): void {
    animateTo({
      duration: 150,
      curve: Curve.EaseIn
    }, () => {
      this.contentOpacity = 0;
    });

    setTimeout(() => {
      animateTo({
        duration: 100,
        curve: Curve.EaseIn
      }, () => {
        this.overlayOpacity = 0;
      });
    }, 50);
  }
  build() {
    Stack() {
      Column() {
        Column() {
          this.buildTopBar()
        }
        .width('100%')
        .opacity(this.contentOpacity)

        Blank()

        Column() {
          this.buildBottomBar()
        }
        .width('100%')
        .opacity(this.contentOpacity)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.3)')
    .opacity(this.isVisible ? this.overlayOpacity : 0)
    .visibility(this.isVisible ? Visibility.Visible : Visibility.Hidden)
    .onClick(() => {
      this.callbacks.onBack();
    })
  }

  @Builder
  buildTopBar(): void {
    Row() {
      Button() {
        Text('‹')
          .fontSize(28)
          .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.medium)
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .margin({ right: DesignSystem.Spacing.md })
      .onClick(() => {
        this.callbacks.onBack();
      })

      Column() {
        Text(this.config.bookName)
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.config.chapterTitle) {
          Text(this.config.chapterTitle)
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: DesignSystem.Spacing.xs })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: DesignSystem.Spacing.lg,
      bottom: DesignSystem.Spacing.lg
    })
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: { bottom: 1 },
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
  }

  @Builder
  buildBottomBar(): void {
    Column() {
      Row() {
        this.QuickActionButton('目录', () => {
          this.callbacks.onShowChapterList();
        })

        this.QuickActionButton('设置', () => {
          this.callbacks.onShowSettings();
        })

        this.QuickActionButton('A-', () => {
          const newSize = Math.max(this.config.readConfig.fontSize - 2, 12);
          this.callbacks.onFontSizeChange(newSize);
        })

        this.QuickActionButton('A+', () => {
          const newSize = Math.min(this.config.readConfig.fontSize + 2, 32);
          this.callbacks.onFontSizeChange(newSize);
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .padding({
        left: DesignSystem.Spacing.lg,
        right: DesignSystem.Spacing.lg,
        top: DesignSystem.Spacing.md,
        bottom: DesignSystem.Spacing.md
      })

      Row() {
        Text('上一章')
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(this.config.chapterIndex > 0 ? 
            DesignSystem.getPrimaryTextColor(this.isLightMode) : 
            DesignSystem.getTertiaryTextColor(this.isLightMode))
          .backgroundColor(this.config.chapterIndex > 0 ? 
            DesignSystem.getTertiaryBackgroundColor(this.isLightMode) : 
            'transparent')
          .padding({
            left: DesignSystem.Spacing.xl,
            right: DesignSystem.Spacing.xl,
            top: DesignSystem.Spacing.sm,
            bottom: DesignSystem.Spacing.sm
          })
          .borderRadius(DesignSystem.BorderRadius.md)
          .onClick(() => {
            if (this.config.chapterIndex > 0) {
              this.callbacks.onPrevChapter();
            }
          })

        Column() {
          Text(`${this.config.chapterIndex + 1} / ${this.config.totalChapters}`)
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))

          Progress({
            value: this.config.chapterIndex + 1,
            total: this.config.totalChapters > 0 ? this.config.totalChapters : 1,
            type: ProgressType.Linear
          })
            .width(100)
            .height(3)
            .margin({ top: DesignSystem.Spacing.xs })
            .color(DesignSystem.getPrimaryColor(this.isLightMode))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Text('下一章')
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(this.config.chapterIndex < this.config.totalChapters - 1 ? 
            DesignSystem.getPrimaryTextColor(this.isLightMode) : 
            DesignSystem.getTertiaryTextColor(this.isLightMode))
          .backgroundColor(this.config.chapterIndex < this.config.totalChapters - 1 ? 
            DesignSystem.getTertiaryBackgroundColor(this.isLightMode) : 
            'transparent')
          .padding({
            left: DesignSystem.Spacing.xl,
            right: DesignSystem.Spacing.xl,
            top: DesignSystem.Spacing.sm,
            bottom: DesignSystem.Spacing.sm
          })
          .borderRadius(DesignSystem.BorderRadius.md)
          .onClick(() => {
            if (this.config.chapterIndex < this.config.totalChapters - 1) {
              this.callbacks.onNextChapter();
            }
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({
        left: DesignSystem.Spacing.lg,
        right: DesignSystem.Spacing.lg,
        top: DesignSystem.Spacing.sm,
        bottom: DesignSystem.Spacing.sm
      })

      Row() {
        Text('翻页模式:')
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))

        ForEach(['cover', 'slide', 'scroll', 'simulation'], (mode: string) => {
          Text(this.getPageTurnModeText(mode))
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(this.config.readConfig.pageTurnMode === mode ? 
              '#FFFFFF' : 
              DesignSystem.getPrimaryTextColor(this.isLightMode))
            .backgroundColor(this.config.readConfig.pageTurnMode === mode ? 
              DesignSystem.getPrimaryColor(this.isLightMode) : 
              DesignSystem.getTertiaryBackgroundColor(this.isLightMode))
            .padding({
              left: DesignSystem.Spacing.md,
              right: DesignSystem.Spacing.md,
              top: DesignSystem.Spacing.xs,
              bottom: DesignSystem.Spacing.xs
            })
            .borderRadius(DesignSystem.BorderRadius.sm)
            .margin({ left: DesignSystem.Spacing.sm })
            .onClick(() => {
              this.callbacks.onPageTurnModeChange(mode);
            })
        })
      }
      .width('100%')
      .padding({
        left: DesignSystem.Spacing.lg,
        right: DesignSystem.Spacing.lg,
        bottom: DesignSystem.Spacing.lg
      })
    }
    .width('100%')
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: { top: 1 },
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
  }

  @Builder
  QuickActionButton(label: string, action: () => void): void {
    Text(label)
      .fontSize(DesignSystem.Typography.size.sm)
      .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
      .backgroundColor(DesignSystem.getTertiaryBackgroundColor(this.isLightMode))
      .padding({
        left: DesignSystem.Spacing.lg,
        right: DesignSystem.Spacing.lg,
        top: DesignSystem.Spacing.sm,
        bottom: DesignSystem.Spacing.sm
      })
      .borderRadius(DesignSystem.BorderRadius.md)
      .onClick(() => {
        action();
      })
  }

  getPageTurnModeText(mode: string): string {
    const modeMap: Record<string, string> = {
      'cover': '覆盖',
      'slide': '滑动',
      'scroll': '滚动',
      'simulation': '仿真'
    };
    return modeMap[mode] || mode;
  }
}
