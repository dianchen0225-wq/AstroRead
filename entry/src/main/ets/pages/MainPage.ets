import { HomePage } from './HomePage';
import { SearchPage } from './SearchPage';
import { BookshelfPage } from './BookshelfPage';
import { SourcePage } from './SourcePage';
import { SettingsPage } from './SettingsPage';

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
  @Local isLightMode: boolean = true;

  handleModeChange(): void {
    this.isLightMode = !this.isLightMode;
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentPageIndex }) {
        TabContent() {
          HomePage({ isLightMode: this.isLightMode, onModeChange: this.handleModeChange })
        }
        .tabBar(this.buildTabBar(PageIndex.Home))

        TabContent() {
          SearchPage({ isLightMode: this.isLightMode })
        }
        .tabBar(this.buildTabBar(PageIndex.Search))

        TabContent() {
          BookshelfPage({ isLightMode: this.isLightMode })
        }
        .tabBar(this.buildTabBar(PageIndex.Bookshelf))

        TabContent() {
          SourcePage({ isLightMode: this.isLightMode })
        }
        .tabBar(this.buildTabBar(PageIndex.Source))

        TabContent() {
          SettingsPage({ isLightMode: this.isLightMode })
        }
        .tabBar(this.buildTabBar(PageIndex.Settings))

        TabContent() {
          this.buildMorePage()
        }
        .tabBar(this.buildTabBar(PageIndex.More))
      }
      .barMode(BarMode.Fixed)
      .barBackgroundColor(this.isLightMode ? '#f0ebe0' : '#0f0f0f')
      .onChange((index: number) => {
        this.currentPageIndex = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isLightMode ? '#f5f1e8' : '#0a0a0a')
  }

  @Builder
  buildTabBar(index: PageIndex) {
    Column() {
      Image(this.getTabIcon(index))
        .width(18)
        .height(18)
        .fillColor(this.currentPageIndex === index ?
          (this.isLightMode ? '#8a6d3b' : '#d4b483') :
          (this.isLightMode ? '#666' : '#8a7f6e'))
        .margin({ bottom: 5 })

      Text(this.getTabText(index))
        .fontSize(11)
        .fontColor(this.currentPageIndex === index ?
          (this.isLightMode ? '#8a6d3b' : '#d4b483') :
          (this.isLightMode ? '#666' : '#8a7f6e'))
    }
    .padding({ top: 8, bottom: 8 })
    .width('100%')
  }

  @Builder
  buildMorePage() {
    Column() {
      Text('更多功能')
        .fontSize(24)
        .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
        .fontWeight(600)
        .margin({ top: 100 })

      Text('敬请期待...')
        .fontSize(14)
        .fontColor(this.isLightMode ? '#666' : '#8a7f6e')
        .margin({ top: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isLightMode ? '#f5f1e8' : 'transparent')
    .justifyContent(FlexAlign.Start)
  }

  getTabIcon(index: PageIndex): Resource {
    switch (index) {
      case PageIndex.Home:
        return $r('app.media.ic_home');
      case PageIndex.Search:
        return $r('app.media.ic_search');
      case PageIndex.Bookshelf:
        return $r('app.media.ic_bookshelf');
      case PageIndex.Source:
        return $r('app.media.ic_book_source');
      case PageIndex.Settings:
        return $r('app.media.ic_settings');
      case PageIndex.More:
        return $r('app.media.ic_more_line');
      default:
        return $r('app.media.ic_home');
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
