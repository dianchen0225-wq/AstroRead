/**
 * AstroRead MainPage - 沉浸式悬浮交互主页面
 * 使用 FloatingDock + SideDock + GestureController 替代传统 TabBar
 */

import { HomePage } from './HomePage';
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
import { NavigationManager, NavParams } from '../common/NavigationManager';
import { BookDetailPage } from './BookDetailPage';
import { ReadPage } from './ReadPage';
import { ImportPage } from './ImportPage';
import { SimpleFloatingDock, DockItem } from '../components/FloatingDock';
import { QuickSettingsSideDock } from '../components/SideDock';
import { gestureController, GestureEvent } from '../utils/ui/GestureController';
import { immersiveUI, UIVisibility } from '../utils/ui/ImmersiveUIManager';

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
  @Local dockVisible: boolean = true;

  private isComponentActive: boolean = false;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };
  private gestureHandler: (event: GestureEvent) => void = (event: GestureEvent) => {
    if (event.type === 'swipe_up_hold' && event.isComplete) {
      this.dockVisible = !this.dockVisible;
    }
  };
  private visibilityHandler: (visibility: UIVisibility) => void = (_visibility: UIVisibility) => {
    // Dock remains by user control only (via swipe gesture)
    // Immersive UI scroll behavior must not hide the main navigation
  };

  private dockItems: DockItem[] = [
    { id: 'home', icon: '🏠', label: '首页', enabled: true, route: 'MainPage' },
    { id: 'search', icon: '🔍', label: '搜索', enabled: true, route: 'SearchPage' },
    { id: 'shelf', icon: '📚', label: '书架', enabled: true, route: 'BookshelfPage' },
    { id: 'source', icon: '📖', label: '书源', enabled: true, route: 'SourcePage' },
    { id: 'settings', icon: '⚙️', label: '设置', enabled: true, route: 'SettingsPage' }
  ];

  aboutToAppear(): void {
    this.isComponentActive = true;

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    viewModelManager.setContext(context);
    themeManager.setContext(context);

    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);

    // 设置手势控制器
    gestureController.setScreenSize(this.screenWidth, this.screenHeight);
    gestureController.setKioskMode(false);
    gestureController.addCallback(this.gestureHandler);

    // 设置沉浸式管理器
    immersiveUI.addCallback(this.visibilityHandler);

    this.setWindowImmersive();
    this.measureScreen();

    NavigationManager.getInstance().setPageChangeListener((pageName: string, params?: NavParams) => {
      if (pageName === 'BookDetailPage') {
        this.currentDetailPage = String(params?.bookId || '');
      } else if (pageName === 'ReadPage') {
        this.currentReadPage = String(params?.bookId || '');
        this.currentReadChapterIndex = Number(params?.initialChapterIndex || 0);
        this.currentReadChapterUrl = String(params?.initialChapterUrl || '');
      } else if (pageName === 'ImportPage') {
        this.currentImportPage = '';
      } else if (pageName === 'MainPage') {
        this.currentDetailPage = '';
        this.currentReadPage = '';
        this.currentReadChapterIndex = 0;
        this.currentReadChapterUrl = '';
        this.currentImportPage = '';
      } else if (pageName === 'BookshelfPage') {
        this.currentPageIndex = PageIndex.Bookshelf;
      } else if (pageName === 'SearchPage') {
        this.currentPageIndex = PageIndex.Search;
      } else if (pageName === 'SourcePage') {
        this.currentPageIndex = PageIndex.Source;
      } else if (pageName === 'SettingsPage') {
        this.currentPageIndex = PageIndex.Settings;
      }
    });
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    gestureController.removeCallback(this.gestureHandler);
    immersiveUI.removeCallback(this.visibilityHandler);
  }

  private measureScreen(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const displayInfo = display.getDefaultDisplaySync();
      this.screenWidth = vp2px(displayInfo.width);
      this.screenHeight = vp2px(displayInfo.height);
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

        // 设置沉浸式导航栏 - 透明背景
        await mainWindow.setWindowSystemBarProperties({
          statusBarColor: DesignSystem.getPrimaryBackgroundColor(this.isLightMode),
          statusBarContentColor: DesignSystem.getPrimaryTextColor(this.isLightMode),
          navigationBarColor: 'rgba(0,0,0,0)',
          navigationBarContentColor: DesignSystem.getPrimaryTextColor(this.isLightMode)
        });

        // 启用全屏布局
        await mainWindow.setWindowLayoutFullScreen(true);
      }
    } catch (error) {
      Logger.error('MainPage', `设置窗口沉浸式失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private handleDockItemClick(index: number, item: DockItem): void {
    this.currentPageIndex = index;

    // 路由映射到下划线页面
    switch (index) {
      case PageIndex.Search:
        NavigationManager.getInstance().navigateTo('SearchPage');
        break;
      case PageIndex.Bookshelf:
        NavigationManager.getInstance().navigateTo('BookshelfPage');
        break;
      case PageIndex.Source:
        NavigationManager.getInstance().navigateTo('SourcePage');
        break;
      case PageIndex.Settings:
        NavigationManager.getInstance().navigateTo('SettingsPage');
        break;
      default:
        break;
    }
  }

  @Builder
  buildCurrentPage() {
    if (this.currentPageIndex === PageIndex.Home) {
      HomePage({
        safeAreaTop: this.safeAreaTop,
        onNavigate: (route: string, params?: ESObject) => {
          if (route === 'TabSwitch' && params && (params as Record<string, Object>).tabIndex !== undefined) {
            this.currentPageIndex = (params as Record<string, number>).tabIndex as number;
          }
        }
      })
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
      // 主内容区 - 占据全屏，不再有固定 TabBar
      Column() {
        this.buildCurrentPage()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 侧边 Dock
      QuickSettingsSideDock({
        screenWidth: this.screenWidth,
        screenHeight: this.screenHeight,
        safeAreaTop: this.safeAreaTop
      })

      // 悬浮底栏 - 不占用固定实体空间，基于 Stack 绝对定位
      if (this.dockVisible) {
        SimpleFloatingDock({
          items: this.dockItems,
          activeIndex: this.currentPageIndex,
          onItemClick: (index: number, item: DockItem) => {
            this.handleDockItemClick(index, item);
          },
          screenWidth: this.screenWidth,
          screenHeight: this.screenHeight,
          safeAreaBottom: this.safeAreaBottom
        })
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
