import { HomePage } from './HomePage';
import { SearchPage } from './SearchPage';
import { BookshelfPage } from './BookshelfPage';
import { SourcePage } from './SourcePage';
import { SettingsPage } from './SettingsPage';
import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { Logger } from '../utils/Logger';
import { NavigationManager, NavigationChangeListener } from '../common/NavigationManager';
import { floatingNavManager, FloatingNavConfig } from '../common/FloatingNavManager';
import { FloatingNavBar } from '../components/FloatingNavBar';
import BookDetailPage from './BookDetailPage';
import ReadPage from './ReadPage';
import ImportPage from './ImportPage';
import window from '@ohos.window';
import display from '@ohos.display';
import common from '@ohos.app.ability.common';

enum PageIndex {
  Home = 0,
  Search = 1,
  Bookshelf = 2,
  Source = 3,
  Settings = 4
}

interface OverlayPage {
  type: 'detail' | 'read' | 'import';
  params: ESObject;
}

@Entry
@ComponentV2
struct MainPage {
  @Local currentPageIndex: number = PageIndex.Home;
  @Local isLightMode: boolean = true;
  @Local safeAreaTop: number = 0;
  @Local safeAreaBottom: number = 0;
  @Local overlayPages: OverlayPage[] = [];
  @Local pageTransitionOpacity: number = 1;
  @Local pageTransitionOffset: number = 0;
  @Local floatingNavConfig: FloatingNavConfig = floatingNavManager.getConfig();
  @Local screenWidth: number = 360;
  @Local screenHeight: number = 780;
  
  private isComponentActive: boolean = false;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };
  private navigationListener: NavigationChangeListener = (pageName: string, action: 'push' | 'pop' | 'replace', params?: ESObject) => {
    this.handleNavigationChange(pageName, params, action);
  };
  private floatingNavListener: (config: FloatingNavConfig) => void = (config: FloatingNavConfig) => {
    this.floatingNavConfig = config;
  };

  aboutToAppear(): void {
    this.isComponentActive = true;

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    viewModelManager.setContext(context);
    themeManager.setContext(context);
    floatingNavManager.loadConfig();

    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    floatingNavManager.addConfigChangeListener(this.floatingNavListener);

    NavigationManager.getInstance().initializeStack('MainPage');
    NavigationManager.getInstance().addNavigationChangeListener(this.navigationListener);

    this.setWindowImmersive();
    this.getScreenSize();
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    floatingNavManager.removeConfigChangeListener(this.floatingNavListener);
    NavigationManager.getInstance().removeNavigationChangeListener(this.navigationListener);
  }

  private getScreenSize(): void {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      this.screenWidth = displayInfo.width;
      this.screenHeight = displayInfo.height;
    } catch (error) {
      Logger.error('MainPage', `获取屏幕尺寸失败: ${error}`);
    }
  }

  private handleNavigationChange(pageName: string, action: 'push' | 'pop' | 'replace', params?: ESObject): void {
    if (!this.isComponentActive) return;

    if (action === 'push') {
      this.animatePageTransition(() => {
        this.pushOverlayPage(pageName, params);
      });
    } else if (action === 'pop') {
      this.animatePageTransition(() => {
        this.popOverlayPage();
      });
    } else if (action === 'replace') {
      this.popOverlayPage();
      this.pushOverlayPage(pageName, params);
    }
  }

  private pushOverlayPage(pageName: string, params?: ESObject): void {
    switch (pageName) {
      case 'BookDetailPage':
        this.overlayPages.push({
          type: 'detail',
          params: { bookId: params?.bookId || '' }
        });
        break;
      case 'ReadPage':
        this.overlayPages.push({
          type: 'read',
          params: {
            bookId: params?.bookId || '',
            initialChapterIndex: params?.initialChapterIndex || 0,
            initialChapterUrl: params?.initialChapterUrl || ''
          }
        });
        break;
      case 'ImportPage':
        this.overlayPages.push({
          type: 'import',
          params: { path: params?.path || '' }
        });
        break;
      case 'MainPage':
        this.overlayPages = [];
        if (params?.tabIndex !== undefined) {
          this.currentPageIndex = params.tabIndex;
        }
        break;
      case 'TabSwitch':
        if (params?.tabIndex !== undefined) {
          this.currentPageIndex = params.tabIndex;
        }
        break;
      default:
        Logger.warn('MainPage', `未知页面: ${pageName}`);
    }
  }

  private popOverlayPage(): void {
    if (this.overlayPages.length > 0) {
      this.overlayPages.pop();
    }
  }

  private animatePageTransition(callback: () => void): void {
    this.pageTransitionOpacity = 0;
    this.pageTransitionOffset = 20;
    
    setTimeout(() => {
      callback();
      this.pageTransitionOpacity = 1;
      this.pageTransitionOffset = 0;
    }, 100);
  }

  private handleHomeNavigate(route: string, params?: ESObject): void {
    if (route === 'TabSwitch' && params?.tabIndex !== undefined) {
      this.currentPageIndex = params.tabIndex;
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

        await mainWindow.setWindowSystemBarProperties({
          statusBarColor: DesignSystem.getPrimaryBackgroundColor(this.isLightMode),
          statusBarContentColor: DesignSystem.getPrimaryTextColor(this.isLightMode),
          navigationBarColor: DesignSystem.getPrimaryBackgroundColor(this.isLightMode),
          navigationBarContentColor: DesignSystem.getPrimaryTextColor(this.isLightMode)
        });
      }
    } catch (error) {
      Logger.error('MainPage', `设置窗口沉浸式失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  build() {
    Stack() {
      Column() {
        Tabs({ barPosition: BarPosition.End, index: this.currentPageIndex }) {
          TabContent() {
            HomePage({
              safeAreaTop: this.safeAreaTop,
              onNavigate: (route: string, params?: ESObject) => {
                this.handleHomeNavigate(route, params);
              }
            })
          }
          .tabBar(this.buildTabBar(PageIndex.Home))

          TabContent() {
            SearchPage({ safeAreaTop: this.safeAreaTop })
          }
          .tabBar(this.buildTabBar(PageIndex.Search))

          TabContent() {
            BookshelfPage({ safeAreaTop: this.safeAreaTop })
          }
          .tabBar(this.buildTabBar(PageIndex.Bookshelf))

          TabContent() {
            SourcePage()
          }
          .tabBar(this.buildTabBar(PageIndex.Source))

          TabContent() {
            SettingsPage({
              safeAreaTop: this.safeAreaTop,
              safeAreaBottom: this.safeAreaBottom
            })
          }
          .tabBar(this.buildTabBar(PageIndex.Settings))
        }
        .barMode(BarMode.Fixed)
        .barHeight(this.floatingNavConfig.enabled ? 0 : 56 + this.safeAreaBottom)
        .barBackgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
        .onChange((index: number) => {
          this.currentPageIndex = index;
        })
        .animationDuration(DesignSystem.AnimationDuration.normal)
        .visibility(this.floatingNavConfig.enabled ? Visibility.Hidden : Visibility.Visible)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .opacity(this.overlayPages.length > 0 ? 0 : 1)

      if (this.overlayPages.length > 0) {
        this.buildOverlayPages()
      }

      if (this.floatingNavConfig.enabled && this.overlayPages.length === 0) {
        FloatingNavBar({
          currentIndex: this.currentPageIndex,
          onTabChange: (index: number) => {
            this.currentPageIndex = index;
          },
          screenWidth: this.screenWidth,
          screenHeight: this.screenHeight,
          safeAreaBottom: this.safeAreaBottom
        })
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopStart)
  }

  @Builder
  buildOverlayPages() {
    Column() {
      ForEach(this.overlayPages, (page: OverlayPage, index: number) => {
        if (index === this.overlayPages.length - 1) {
          this.buildOverlayPage(page)
        }
      })
    }
    .width('100%')
    .height('100%')
    .opacity(this.pageTransitionOpacity)
    .translate({ x: this.pageTransitionOffset })
    .animation({
      duration: DesignSystem.AnimationDuration.normal,
      curve: Curve.EaseOut
    })
  }

  @Builder
    buildOverlayPage(page: OverlayPage) {
      if (page.type === 'detail') {
        BookDetailPage({ bookId: page.params.bookId as string })
      } else if (page.type === 'read') {
        ReadPage({
          bookId: page.params.bookId as string,
          initialChapterIndex: page.params.initialChapterIndex as number,
          initialChapterUrl: page.params.initialChapterUrl as string
        })
      } else if (page.type === 'import') {
        ImportPage({ path: page.params.path as string })
      }
    }

  @Builder
  buildTabBar(index: PageIndex) {
    Column() {
      Text(this.getTabIconText(index))
        .fontSize(20)
        .fontColor(this.currentPageIndex === index ? 
          DesignSystem.getPrimaryColor(this.isLightMode) : 
          DesignSystem.getSecondaryTextColor(this.isLightMode))
        .scale({ x: this.currentPageIndex === index ? 1.1 : 1, y: this.currentPageIndex === index ? 1.1 : 1 })
        .animation({ duration: 200, curve: Curve.EaseOut })

      Text(this.getTabText(index))
        .fontSize(12)
        .lineHeight(16)
        .fontColor(this.currentPageIndex === index ? 
          DesignSystem.getPrimaryColor(this.isLightMode) : 
          DesignSystem.getSecondaryTextColor(this.isLightMode))
        .fontWeight(this.currentPageIndex === index ? 500 : 400)
        .margin({ top: 4 })
    }
    .height(48)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({ bottom: this.safeAreaBottom })
  }

  getTabIconText(index: PageIndex): string {
    switch (index) {
      case PageIndex.Home:
        return '🏠';
      case PageIndex.Search:
        return '🔍';
      case PageIndex.Bookshelf:
        return '📚';
      case PageIndex.Source:
        return '📖';
      case PageIndex.Settings:
        return '⚙️';
      default:
        return '🏠';
    }
  }

  getTabText(index: PageIndex): string {
    switch (index) {
      case PageIndex.Home:
        return '首页';
      case PageIndex.Search:
        return '搜索';
      case PageIndex.Bookshelf:
        return '书架';
      case PageIndex.Source:
        return '书源';
      case PageIndex.Settings:
        return '设置';
      default:
        return '首页';
    }
  }
}
