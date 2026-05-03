/**
 * AstroRead MainPage
 */

import { SearchPage } from './SearchPage';
import { BookshelfPage } from './BookshelfPage';
import { SourcePage } from './SourcePage';
import { SettingsPage } from './SettingsPage';
import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { Logger } from '../utils/performance/Logger';
import { window } from '@kit.ArkUI';
import { display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BookDetailPage } from './BookDetailPage';
import { ReadPage } from './ReadPage';
import { ImportPage } from './ImportPage';
import { gestureController, GestureEvent } from '../utils/ui/GestureController';
import { getApiVersion, isApiVersionAtLeast, SystemVersion } from '../utils/SystemVersionUtils';

enum PageIndex {
  Home = 0,
  Search = 1,
  Bookshelf = 2,
  Source = 3,
  Settings = 4
}

@Entry
@ComponentV2
struct MainPage {
  @Local currentPageIndex: number = PageIndex.Home;
  @Local isLightMode: boolean = true;
  @Local safeAreaTop: number = 0;
  @Local safeAreaBottom: number = 0;
  @Local currentDetailPage: string = '';
  @Local currentReadPage: string = '';
  @Local currentReadChapterIndex: number = 0;
  @Local currentReadChapterUrl: string = '';
  @Local currentImportPage: string = '';
  @Local screenWidth: number = 360;
  @Local screenHeight: number = 780;
  @Local apiVersion: number = 12;
  @Local currentScrollOffset: number = 0;

  private scroller: Scroller = new Scroller();

  private isComponentActive: boolean = false;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isComponentActive = true;

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    viewModelManager.setContext(context);
    themeManager.setContext(context);

    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);

    this.apiVersion = getApiVersion();
    Logger.info('MainPage', `API版本: ${this.apiVersion}`);

    // 设置手势控制器
    gestureController.setScreenSize(this.screenWidth, this.screenHeight);
    gestureController.setKioskMode(false);

    this.setWindowImmersive();
    this.measureScreen();
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
  }

  private measureScreen(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const displayInfo = display.getDefaultDisplaySync();
      // displayInfo.width/height 返回的是物理像素(px)，直接使用即可
      // vp2px() 是将虚拟像素(vp)转换为物理像素(px)，不应对已经是px的值再次转换
      this.screenWidth = displayInfo.width;
      this.screenHeight = displayInfo.height;
      gestureController.setScreenSize(this.screenWidth, this.screenHeight);
    } catch (error) {
      Logger.error('MainPage', `测量屏幕失败: ${error}`);
    }
  }

  async setWindowImmersive(): Promise<void> {
    if (!this.isComponentActive) return;

    try {
      const windowStage = AppStorage.get('windowStage') as window.WindowStage;
      if (windowStage) {
        const mainWindow = await windowStage.getMainWindow();
        const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        this.safeAreaTop = avoidArea.topRect.height;
        this.safeAreaBottom = avoidArea.bottomRect.height;
      }
    } catch (error) {
      Logger.error('MainPage', `设置窗口沉浸式失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private getScrollOffset(): number {
    try {
      const offset = this.scroller.currentOffset();
      const newOffset = offset.yOffset;
      const delta = newOffset - this.currentScrollOffset;
      this.currentScrollOffset = newOffset;
      return newOffset;
    } catch (e) {
      return this.currentScrollOffset;
    }
  }

  @Builder
  buildCurrentPage() {
    if (this.currentPageIndex === PageIndex.Home) {
      Column() {
        Text('Home')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.currentPageIndex === PageIndex.Search) {
      SearchPage()
    } else if (this.currentPageIndex === PageIndex.Bookshelf) {
      BookshelfPage()
    } else if (this.currentPageIndex === PageIndex.Source) {
      SourcePage()
    } else if (this.currentPageIndex === PageIndex.Settings) {
      SettingsPage()
    }
  }

  build() {
    Stack() {
      if (this.apiVersion >= SystemVersion.API_17) {
        Scroll(this.scroller) {
          Column() {
            this.buildCurrentPage()
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      } else {
        Scroll(this.scroller) {
          Column() {
            this.buildCurrentPage()
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
        .padding({ bottom: this.safeAreaBottom })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }

      // 子页面覆盖层
      if (this.currentDetailPage) {
        BookDetailPage({ bookId: this.currentDetailPage })
      }

      if (this.currentReadPage) {
        ReadPage({
          bookId: this.currentReadPage,
          initialChapterIndex: this.currentReadChapterIndex,
          initialChapterUrl: this.currentReadChapterUrl
        })
      }

      if (this.currentImportPage) {
        ImportPage({ path: this.currentImportPage })
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopStart)
  }
}
