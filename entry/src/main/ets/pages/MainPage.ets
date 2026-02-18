/**
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { HomePage } from './HomePage';
import { SearchPage } from './SearchPage';
import { BookshelfPage } from './BookshelfPage';
import { SourcePage } from './SourcePage';
import { SettingsPage } from './SettingsPage';
import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { Logger } from '../utils/Logger';
import window from '@ohos.window';
import common from '@ohos.app.ability.common';
import { NavigationManager } from '../common/NavigationManager';
import BookDetailPage from './BookDetailPage';
import ReadPage from './ReadPage';
import ImportPage from './ImportPage';
import router from '@ohos.router';
import hilog from '@ohos.hilog';

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
  @Local safeAreaTop: number = 0;
  @Local safeAreaBottom: number = 0;
    @Local currentDetailPage: string = '';
    @Local currentReadPage: string = '';
    @Local currentImportPage: string = '';
  
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
    this.setWindowImmersive();
    NavigationManager.getInstance().setPageChangeListener((pageName: string, params?: ESObject) => {
        if (pageName === 'BookDetailPage') {
          this.currentDetailPage = params?.bookId || '';
        } else if (pageName === 'ReadPage') {
          this.currentReadPage = params?.bookId || '';
        } else if (pageName === 'ImportPage') {
          this.currentImportPage = params?.path || '';
        } else if (pageName === 'MainPage') {
          this.currentDetailPage = '';
          this.currentReadPage = '';
          this.currentImportPage = '';
        }
      });
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
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

      if (this.currentDetailPage) {
        BookDetailPage()
      }

      if (this.currentReadPage) {
        ReadPage()
      }

      if (this.currentImportPage) {
        ImportPage()
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopStart)
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
