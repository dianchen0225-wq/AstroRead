  import { HomePage } from './HomePage';
  import { SearchPage } from './SearchPage';
  import { BookshelfPage } from './BookshelfPage';
  import { SourcePage } from './SourcePage';
  import { SettingsPage } from './SettingsPage';
  import { themeManager } from '../common/ThemeManager';
  import { DesignSystem } from '../common/DesignSystem';
  import window from '@ohos.window';

  enum PageIndex {
    Home = 0,
    Search = 1,
    Bookshelf = 2,
    Source = 3,
    Settings = 4,
    More = 5
  }

  @Entry
  @ComponentV2
  struct MainPage {
    @Local currentPageIndex: number = PageIndex.Home;
    @Local isLightMode: boolean = themeManager.isLightTheme();
    @Local safeAreaTop: number = 0;
    @Local safeAreaBottom: number = 0;
    private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
      this.isLightMode = !isDark;
    };

    aboutToAppear(): void {
      themeManager.addListener(this.themeListener);
      this.isLightMode = themeManager.isLightTheme();
      this.setWindowImmersive();
    }

    aboutToDisappear(): void {
      themeManager.removeListener(this.themeListener);
    }

    async setWindowImmersive(): Promise<void> {
      try {
        const windowStage = AppStorage.get('windowStage') as window.WindowStage;
        if (windowStage) {
          const mainWindow = await windowStage.getMainWindow();
          const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
          this.safeAreaTop = avoidArea.topRect.height;
          this.safeAreaBottom = avoidArea.bottomRect.height;

          await mainWindow.setWindowSystemBarProperties({
            statusBarColor: this.isLightMode ? '#F5F1E8' : '#1a1a1a',
            statusBarContentColor: this.isLightMode ? '#333333' : '#e0d8c9',
            navigationBarColor: this.isLightMode ? '#F5F1E8' : '#1a1a1a',
            navigationBarContentColor: this.isLightMode ? '#333333' : '#e0d8c9'
          });
        }
      } catch (error) {
        console.error('setWindowImmersive error:', error);
      }
    }

    build() {
      Column() {
        Tabs({ barPosition: BarPosition.End, index: this.currentPageIndex }) {
          TabContent() {
            HomePage({ safeAreaTop: this.safeAreaTop })
          }
          .tabBar(this.buildTabBar(PageIndex.Home))

          TabContent() {
            SearchPage()
          }
          .tabBar(this.buildTabBar(PageIndex.Search))

          TabContent() {
            BookshelfPage()
          }
          .tabBar(this.buildTabBar(PageIndex.Bookshelf))

          TabContent() {
            SourcePage()
          }
          .tabBar(this.buildTabBar(PageIndex.Source))

          TabContent() {
            SettingsPage()
          }
          .tabBar(this.buildTabBar(PageIndex.Settings))

          TabContent() {
            this.buildMorePage()
          }
          .tabBar(this.buildTabBar(PageIndex.More))
        }
        .barMode(BarMode.Fixed)
        .barHeight(56 + this.safeAreaBottom)
        .barBackgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
        .onChange((index: number) => {
          this.currentPageIndex = index;
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }

    @Builder
    buildTabBar(index: PageIndex) {
      Column() {
        Text(this.getTabIconText(index))
          .fontSize(20)
          .fontColor(this.currentPageIndex === index ? DesignSystem.getPrimaryColor(this.isLightMode) : DesignSystem.getSecondaryTextColor(this.isLightMode))
          .scale({ x: this.currentPageIndex === index ? 1.1 : 1, y: this.currentPageIndex === index ? 1.1 : 1 })
          .animation({ duration: 200, curve: Curve.EaseOut })

        Text(this.getTabText(index))
          .fontSize(12)
          .lineHeight(16)
          .fontColor(this.currentPageIndex === index ? DesignSystem.getPrimaryColor(this.isLightMode) : DesignSystem.getSecondaryTextColor(this.isLightMode))
          .fontWeight(this.currentPageIndex === index ? 500 : 400)
          .margin({ top: 4 })
      }
      .height(48)
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .padding({ bottom: this.safeAreaBottom })
    }

    @Builder
    buildMorePage() {
      Column() {
        Text('更多功能')
          .fontSize(24)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(600)
          .margin({ top: 100 })

        Text('敬请期待...')
          .fontSize(14)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .margin({ top: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
      .justifyContent(FlexAlign.Start)
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
        case PageIndex.More:
          return '⋯';
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
        case PageIndex.More:
          return '更多';
        default:
          return '首页';
      }
    }
  }
