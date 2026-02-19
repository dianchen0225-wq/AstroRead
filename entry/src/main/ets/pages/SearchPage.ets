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

import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { BookSource } from '../models/BookSource';
import { Book } from '../models/Book';
import { PagedSearchResult, SearchProgress, SourceSearchStats } from '../models/SearchResult';
import { Logger } from '../utils/Logger';
import { NavigationManager } from '../common/NavigationManager';
import { common } from '@kit.AbilityKit';
import { NetworkManager } from '../utils/NetworkManager';
import { ContentPurifier, purifyIntro } from '../utils/ContentPurifier';
import { router } from '@kit.ArkUI';

export interface RankColor {
  light: string;
  dark: string;
}

@ComponentV2
export struct SearchPage {
  @Local isLightMode: boolean = true;
  @Local searchText: string = '';
  @Local searchHistory: string[] = [];
  @Local hotSearchList: string[] = ['完美世界', '雪中悍刀行', '诡秘之主', '庆余年', '赘婿'];
  @Local searchResults: Book[] = [];
  @Local isSearching: boolean = false;
  @Local hasSearched: boolean = false;
  @Local errorMessage: string = '';
  @Local hasEnabledSources: boolean = true;
  @Local currentPage: number = 1;
  @Local totalPages: number = 1;
  @Local totalCount: number = 0;
  @Local hasMore: boolean = false;
  @Local searchProgress: string = '';
  @Local sourceStats: SourceSearchStats[] = [];

  private bookSources: BookSource[] = [];
  private isComponentActive: boolean = false;
  private lastSearchKeyword: string = '';
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isComponentActive = true;
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    viewModelManager.setContext(context);
    NetworkManager.getInstance().setContext(context);
    
    this.loadSearchHistory();
    this.loadBookSources();
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    this.searchResults = [];
    this.bookSources = [];
  }

  private async loadSearchHistory(): Promise<void> {
    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      this.searchHistory = bookViewModel.getSearchHistory();
    } catch (error) {
      Logger.error('SearchPage', `加载搜索历史失败: ${error}`);
    }
  }

  private async loadBookSources(): Promise<void> {
    if (!this.isComponentActive) return;
    
    try {
      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      this.bookSources = await bookSourceViewModel.loadEnabledBookSources();
      this.hasEnabledSources = this.bookSources.length > 0;
      Logger.info('SearchPage', `加载了${this.bookSources.length}个书源`);
      
      if (this.bookSources.length > 0) {
        for (let i = 0; i < Math.min(3, this.bookSources.length); i++) {
          const source = this.bookSources[i];
          Logger.info('SearchPage', `书源[${i}]: ${source.name}, searchUrl=${source.searchUrl}, ruleType=${source.ruleType}`);
        }
      }
    } catch (error) {
      Logger.error('SearchPage', `加载书源失败: ${error}`);
      this.hasEnabledSources = false;
    }
  }

  private async performSearch(page: number = 1): Promise<void> {
    if (!this.searchText.trim()) {
      Logger.info('SearchPage', '请输入搜索关键词');
      return;
    }

    this.isSearching = true;
    this.hasSearched = true;
    this.errorMessage = '';
    this.searchProgress = '正在初始化搜索...';

    if (page === 1) {
      this.searchResults = [];
      this.currentPage = 1;
    }

    try {
      Logger.info('SearchPage', `开始搜索: ${this.searchText}, 第${page}页`);

      if (this.bookSources.length === 0) {
        await this.loadBookSources();
      }

      if (this.bookSources.length === 0) {
        this.errorMessage = '没有可用的书源';
        this.hasEnabledSources = false;
        this.isSearching = false;
        return;
      }

      const sourcesToUse = this.bookSources;
      Logger.info('SearchPage', `使用${sourcesToUse.length}个书源进行搜索`);

      const bookViewModel = viewModelManager.getBookViewModel();
      
      const progressCallback = (progress: SearchProgress): void => {
        if (this.isComponentActive) {
          this.searchProgress = `正在搜索 ${progress.currentSource}... (${progress.completedSources}/${progress.totalSources})`;
        }
      };

      const result: PagedSearchResult = await bookViewModel.searchBooksWithPaging(
        this.searchText.trim(),
        sourcesToUse,
        page,
        progressCallback
      );

      if (this.isComponentActive) {
        this.searchResults = result.books;
        this.currentPage = result.currentPage;
        this.totalPages = result.totalPages;
        this.totalCount = result.totalCount;
        this.hasMore = result.hasMore;
        this.sourceStats = result.sourceStats;
        this.lastSearchKeyword = this.searchText.trim();

        Logger.info('SearchPage', 
          `搜索完成，共${result.totalCount}本书，当前第${result.currentPage}/${result.totalPages}页`
        );
        Logger.info('SearchPage', `searchResults.length = ${this.searchResults.length}`);

        if (result.totalCount === 0) {
          this.errorMessage = '当前启用的书源无匹配结果';
        }
      }

    } catch (error) {
      Logger.error('SearchPage', `搜索失败: ${error}`);
      if (this.isComponentActive) {
        const errorMsg = error instanceof Error ? error.message : '未知错误';
        
        if (errorMsg.includes('network') || errorMsg.includes('网络')) {
          this.errorMessage = '网络连接失败，请检查网络设置';
        } else if (errorMsg.includes('timeout') || errorMsg.includes('超时')) {
          this.errorMessage = '搜索超时，请稍后重试';
        } else {
          this.errorMessage = `搜索失败: ${errorMsg}`;
        }
      }
    } finally {
      if (this.isComponentActive) {
        this.isSearching = false;
        this.searchProgress = '';
      }
    }
  }

  private async loadNextPage(): Promise<void> {
    if (!this.hasMore || this.isSearching) {
      return;
    }
    await this.performSearch(this.currentPage + 1);
  }

  private async loadPreviousPage(): Promise<void> {
    if (this.currentPage <= 1 || this.isSearching) {
      return;
    }
    await this.performSearch(this.currentPage - 1);
  }

  private async goToPage(page: number): Promise<void> {
    if (page < 1 || page > this.totalPages || page === this.currentPage || this.isSearching) {
      return;
    }
    await this.performSearch(page);
  }

  private async addToBookshelf(book: Book): Promise<void> {
    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      
      if (!book.id) {
        book.id = `book_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      }
      if (!book.addTime) {
        book.addTime = Date.now();
      }
      if (!book.lastUpdateTime) {
        book.lastUpdateTime = Date.now();
      }
      if (!book.readProgress) {
        book.readProgress = 0;
      }
      
      Logger.info('SearchPage', `准备添加书籍: id=${book.id}, name=${book.name}, bookSourceId=${book.bookSourceId}`);
      
      const bookId = await bookViewModel.addBook(book);
      Logger.info('SearchPage', `已添加到书架，ID: ${bookId}`);
    } catch (error) {
      Logger.error('SearchPage', `添加到书架失败: ${error}`);
    }
  }
  private async openBook(book: Book): Promise<void> {
    try {
      await this.addToBookshelf(book);
      
      NavigationManager.getInstance().navigateTo('BookDetailPage', {
        bookId: book.id
      });
    } catch (error) {
      Logger.error('SearchPage', `打开书籍失败: ${error}`);
    }
  }
  private navigateToSourcePage(): void {
    try {
      NavigationManager.getInstance().navigateTo('MainPage', { tabIndex: 3 });
    } catch (err) {
      Logger.error('SearchPage', `跳转失败: ${err}`);
    }
  }

  private async clearSearchHistory(): Promise<void> {
    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      await bookViewModel.clearSearchHistory();
      this.searchHistory = [];
    } catch (error) {
      Logger.error('SearchPage', `清除搜索历史失败: ${error}`);
    }
  }

  build() {
    Column() {
      Row() {
        Row() {
          Text('‹')
            .fontSize(20)
            .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .justifyContent(FlexAlign.Center)
        .margin({ right: 15 })
        .onClick(() => {
          NavigationManager.getInstance().navigateBack();
        })

        Text($r('app.string.search_books'))
          .fontSize(18)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(600)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 15, right: 20, top: 15, bottom: 15 })
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .border({
        width: { bottom: 1 },
        color: DesignSystem.getBorderColor(this.isLightMode)
      })

      Scroll() {
        Column() {
          Row() {
            Text('🔍')
              .fontSize(18)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .margin({ right: 10 })

            TextInput({ placeholder: $r('app.string.search_placeholder'), text: this.searchText })
              .layoutWeight(1)
              .backgroundColor(Color.Transparent)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .placeholderColor(this.isLightMode ? '#666' : '#8a7f6e')
              .onChange((value: string) => {
                this.searchText = value;
              })
              .onSubmit(() => {
                this.performSearch();
              })

            Button($r('app.string.search_button'))
              .fontSize(14)
              .fontColor(DesignSystem.Colors.text.primary.light)
              .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
              .borderRadius(8)
              .padding({ left: 15, right: 15, top: 8, bottom: 8 })
              .margin({ left: 10 })
              .enabled(!this.isSearching)
              .onClick(() => {
                this.performSearch(1);
              })
          }
          .width('100%')
          .padding(15)
          .borderRadius(12)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .border({
            width: 1,
            color: DesignSystem.getBorderColor(this.isLightMode)
          })
          .margin({ bottom: 20 })

          if (this.isSearching) {
            Column() {
              LoadingProgress()
                .width(40)
                .height(40)
                .color(DesignSystem.getPrimaryColor(this.isLightMode))
              Text(this.searchProgress || '正在搜索...')
                .fontSize(14)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                .margin({ top: 10 })
            }
            .width('100%')
            .height(200)
            .justifyContent(FlexAlign.Center)
          }

          if (this.hasSearched && !this.isSearching) {
            if (this.errorMessage) {
              Column() {
                Text('😔')
                  .fontSize(40)
                Text(this.errorMessage)
                  .fontSize(14)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  .margin({ top: 10 })
                  .textAlign(TextAlign.Center)
                
                Column() {
                  if (!this.hasEnabledSources) {
                    Text('请先导入书源后再进行搜索')
                      .fontSize(12)
                      .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                      .margin({ top: 8 })
                  } else {
                    Text('可尝试以下操作：')
                      .fontSize(12)
                      .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                      .margin({ top: 8 })
                  }
                  
                  Row() {
                    Button('网络导入书源')
                      .fontSize(13)
                      .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                      .fontColor('#fff')
                      .borderRadius(6)
                      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                      .margin({ top: 12, right: 10 })
                      .onClick(() => {
                        this.navigateToSourcePage();
                      })
                    
                    if (this.hasEnabledSources) {
                      Button('验证书源')
                        .fontSize(13)
                        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                        .borderRadius(6)
                        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                        .margin({ top: 12 })
                        .onClick(() => {
                          this.navigateToSourcePage();
                        })
                    }
                  }
                }
                .margin({ top: 8 })
              }
              .width('100%')
              .height(250)
              .justifyContent(FlexAlign.Center)
            } else if (this.searchResults.length > 0) {
              Column() {
                Row() {
                  Text(`共 ${this.totalCount} 本书籍 (显示 ${this.searchResults.length} 本)`)
                    .fontSize(14)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  
                  Blank()
                  
                  Text(`第 ${this.currentPage}/${this.totalPages} 页`)
                    .fontSize(12)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                }
                .width('100%')
                .margin({ bottom: 12 })

                List() {
                  ForEach(this.searchResults, (book: Book, index: number) => {
                    ListItem() {
                      Row() {
                        if (book.cover) {
                          Image(book.cover)
                            .width(60)
                            .height(80)
                            .borderRadius(4)
                            .objectFit(ImageFit.Cover)
                        } else {
                          Column() {
                            Text('📖')
                              .fontSize(24)
                          }
                          .width(60)
                          .height(80)
                          .borderRadius(4)
                          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                          .justifyContent(FlexAlign.Center)
                        }

                        Column() {
                          Text(book.name)
                            .fontSize(16)
                            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                            .fontWeight(500)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })

                          if (book.author) {
                            Text(book.author)
                              .fontSize(12)
                              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                              .margin({ top: 4 })
                          }

                          if (book.intro) {
                            Text(purifyIntro(book.intro))
                              .fontSize(12)
                              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                              .margin({ top: 4 })
                              .maxLines(2)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                          }

                          if (book.bookSourceName) {
                            Text(`来源: ${book.bookSourceName}`)
                              .fontSize(10)
                              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                              .margin({ top: 4 })
                          }
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)
                        .margin({ left: 12 })

                        Button('加入书架')
                          .fontSize(12)
                          .fontColor(DesignSystem.Colors.text.primary.light)
                          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                          .borderRadius(6)
                          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
                          .margin({ left: 8 })
                          .onClick(() => {
                            this.addToBookshelf(book);
                          })
                      }
                      .width('100%')
                      .padding(12)
                      .borderRadius(8)
                      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                      .onClick(() => {
                        this.openBook(book);
                      })
                    }
                    .margin({ bottom: 8 })
                  }, (book: Book, index: number) => `book_${index}_${book.name}_${book.bookSourceId}`)
                }
                .width('100%')
                .height(this.searchResults.length * 120 + 20)
                .cachedCount(5)
                .nestedScroll({
                  scrollForward: NestedScrollMode.PARENT_FIRST,
                  scrollBackward: NestedScrollMode.SELF_FIRST
                })

                if (this.totalPages > 1) {
                  Row() {
                    Button('上一页')
                      .fontSize(13)
                      .backgroundColor(this.currentPage > 1 ? 
                        DesignSystem.getPrimaryColor(this.isLightMode) : 
                        DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                      .fontColor(this.currentPage > 1 ? '#fff' : DesignSystem.getSecondaryTextColor(this.isLightMode))
                      .borderRadius(6)
                      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                      .enabled(this.currentPage > 1 && !this.isSearching)
                      .onClick(() => {
                        this.loadPreviousPage();
                      })

                    Text(`${this.currentPage} / ${this.totalPages}`)
                      .fontSize(14)
                      .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                      .margin({ left: 16, right: 16 })

                    Button('下一页')
                      .fontSize(13)
                      .backgroundColor(this.hasMore ? 
                        DesignSystem.getPrimaryColor(this.isLightMode) : 
                        DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                      .fontColor(this.hasMore ? '#fff' : DesignSystem.getSecondaryTextColor(this.isLightMode))
                      .borderRadius(6)
                      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                      .enabled(this.hasMore && !this.isSearching)
                      .onClick(() => {
                        this.loadNextPage();
                      })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  .margin({ top: 16, bottom: 16 })
                }
              }
              .width('100%')
            }
          }

          if (!this.hasSearched) {
            if (!this.hasEnabledSources) {
              Column() {
                Text('📚')
                  .fontSize(48)
                  .margin({ bottom: 16 })
                Text('暂无可用书源')
                  .fontSize(16)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  .margin({ bottom: 8 })
                Text('请先导入书源后再进行搜索')
                  .fontSize(14)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  .margin({ bottom: 16 })
                Button('去导入书源')
                  .fontSize(14)
                  .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                  .fontColor('#fff')
                  .borderRadius(8)
                  .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                  .onClick(() => {
                    this.navigateToSourcePage();
                  })
              }
              .width('100%')
              .height(200)
              .justifyContent(FlexAlign.Center)
              .margin({ bottom: 20 })
            }

            if (this.searchHistory.length > 0) {
              Column() {
                Row() {
                  Text($r('app.string.search_history'))
                    .fontSize(14)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                    .fontWeight(500)

                  Blank()

                  Text($r('app.string.clear_history'))
                    .fontSize(12)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                    .onClick(() => {
                      this.clearSearchHistory();
                    })
                }
                .width('100%')
                .margin({ bottom: 12 })

                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.searchHistory, (item: string) => {
                    Text(item)
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                      .borderRadius(15)
                      .fontSize(12)
                      .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                      .margin({ right: 8, bottom: 8 })
                      .onClick(() => {
                        this.searchText = item;
                        this.performSearch(1);
                      })
                  })
                }
              }
              .width('100%')
              .margin({ bottom: 25 })
            }

            Column() {
              Text($r('app.string.hot_search'))
                .width('100%')
                .fontSize(14)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                .fontWeight(500)
                .margin({ bottom: 12 })

              Column() {
                ForEach(this.hotSearchList, (item: string, index: number) => {
                  Row() {
                    Text((index + 1).toString())
                      .width(20)
                      .height(20)
                      .borderRadius(10)
                      .backgroundColor(this.getRankColor(index))
                      .fontColor(DesignSystem.Colors.text.primary.light)
                      .fontSize(12)
                      .fontWeight(600)
                      .textAlign(TextAlign.Center)
                      .margin({ right: 12 })

                    Text(item)
                      .fontSize(14)
                      .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                  }
                  .width('100%')
                  .margin({ bottom: 12 })
                  .onClick(() => {
                    this.searchText = item;
                    this.performSearch(1);
                  })
                })
              }
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding(20)
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }

  private getRankColor(index: number): string {
    const rankColors: RankColor[] = [
      { light: '#e8d9b0', dark: '#d4b483' },
      { light: '#ede0c3', dark: '#e0c595' },
      { light: '#f2e8d6', dark: '#eddfc8' }
    ];
    const color = rankColors[index] || rankColors[0];
    return this.isLightMode ? color.light : color.dark;
  }
}
