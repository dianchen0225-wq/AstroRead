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
import { Book } from '../models/Book';
import { Chapter } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { Logger } from '../utils/Logger';
import { AlertDialog } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import common from '@ohos.app.ability.common';

interface RouterParams {
  bookId?: string;
}

@Entry
@ComponentV2
struct BookDetailPage {
  @Local isLightMode: boolean = true;
  @Local book: Book | null = null;
  @Local chapters: Chapter[] = [];
  @Local isLoadingChapters: boolean = false;
  @Local bookSource: BookSource | null = null;
  @Local showChapterList: boolean = false;
  @Local currentChapterIndex: number = 0;
  @Local isAdded: boolean = false;

  private bookId: string = '';
  private isComponentActive: boolean = false;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isComponentActive = true;
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    viewModelManager.setContext(context);
    
    this.loadBookDetail();
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    this.chapters = [];
    this.book = null;
    this.bookSource = null;
  }

  async loadBookDetail() {
    if (!this.isComponentActive) return;
    const params = router.getParams() as RouterParams;
    this.bookId = params?.bookId || '';
    Logger.info('BookDetailPage', `bookId: ${this.bookId}`);
    
    if (this.bookId) {
      try {
        const bookViewModel = viewModelManager.getBookViewModel();
        this.book = await bookViewModel.getBookById(this.bookId);
        
        if (this.book && this.isComponentActive) {
          const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
          this.bookSource = bookSourceViewModel.getBookSourceById(this.book.bookSourceId) || null;
        }
      } catch (error) {
        Logger.error('BookDetailPage', `加载书籍详情失败: ${error}`);
      }
    }
    
    await this.loadChapters();
    
    if (this.isComponentActive && this.bookId) {
      try {
        const bookViewModel = viewModelManager.getBookViewModel();
        this.isAdded = await bookViewModel.isBookAdded(this.bookId);
      } catch (error) {
        Logger.error('BookDetailPage', `检查书籍状态失败: ${error}`);
      }
    }
  }

  async loadChapters() {
    if (!this.book || !this.isComponentActive) {
      return;
    }
    
    this.isLoadingChapters = true;
    try {
      const chapterViewModel = viewModelManager.getChapterViewModel();
      this.chapters = await chapterViewModel.getChapters(this.bookId);
      
      if (this.chapters.length === 0 && this.bookSource && this.isComponentActive) {
        this.chapters = await chapterViewModel.fetchAndSaveChapters(
          this.bookId, 
          this.bookSource, 
          this.book.bookUrl
        );
      }
    } catch (error) {
      Logger.error('BookDetailPage', `加载章节失败: ${error}`);
    } finally {
      if (this.isComponentActive) {
        this.isLoadingChapters = false;
      }
    }
  }

  async addBook() {
    if (!this.book || !this.isComponentActive) {
      return;
    }
    
    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      await bookViewModel.addBook(this.book);
      this.isAdded = true;
      try {
        AlertDialog.show({
        title: '提示',
        message: '添加成功',
        primaryButton: {
              value: "确定",
              action: () => {}
            }
      });
      } catch (e) {
        Logger.error('BookDetailPage', `AlertDialog.show failed: ${e}`);
      }
    } catch (error) {
      Logger.error('BookDetailPage', `添加书籍失败: ${error}`);
      try {
        AlertDialog.show({
          title: '提示',
          message: '添加失败',
          primaryButton: {
              value: "确定",
              action: () => {}
            }
        });
      } catch (e) {
        Logger.error('BookDetailPage', `AlertDialog.show failed: ${e}`);
      }
    }
  }

  async startRead() {
    if (this.chapters.length === 0) {
      try {
        AlertDialog.show({
          title: '提示',
          message: '暂无章节',
          primaryButton: {
              value: "确定",
              action: () => {}
            }
        });
      } catch (e) {
        Logger.error('BookDetailPage', `AlertDialog.show failed: ${e}`);
      }
      return;
    }

    try {
      const chapterIndex = this.book?.lastReadChapterIndex ? this.book.lastReadChapterIndex : 0;
      router.pushUrl({
        url: 'pages/ReadPage',
        params: {
          bookId: this.bookId,
          chapterIndex: chapterIndex,
          chapterUrl: this.chapters[chapterIndex].url
        }
      });
      hilog.info(0, 'BookDetailPage', 'push page success');
    } catch (err) {
      hilog.error(0, 'BookDetailPage', `pushPage failed: ${err}`);
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

        Text('书籍详情')
          .fontSize(18)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(600)
          .layoutWeight(1)

        Button(this.isAdded ? '已添加' : '添加书架')
          .fontSize(14)
          .fontColor(this.isAdded ? 
            DesignSystem.getSecondaryTextColor(this.isLightMode) : 
            DesignSystem.Colors.text.primary.light)
          .backgroundColor(this.isAdded ? 
            DesignSystem.getSecondaryBackgroundColor(this.isLightMode) : 
            DesignSystem.getPrimaryColor(this.isLightMode))
          .borderRadius(8)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .margin({ left: 10 })
          .onClick(() => {
            if (!this.isAdded) {
              this.addBook();
            }
          })
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
          if (this.book) {
            Column() {
              Row() {
                if (this.book.cover) {
                  Image(this.book.cover)
                    .width(90)
                    .height(120)
                    .borderRadius(6)
                } else {
                  Column() {
                    Text('📖')
                      .fontSize(32)
                  }
                  .width(90)
                  .height(120)
                  .borderRadius(6)
                  .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                  .justifyContent(FlexAlign.Center)
                }
                Column() {
                  Text(this.book.name)
                    .fontSize(20)
                    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                    .fontWeight(600)
                    .margin({ bottom: 8 })

                  if (this.book.author) {
                    Text(this.book.author)
                      .fontSize(14)
                      .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                      .margin({ bottom: 4 })
                  }

                  if (this.book.bookSourceName) {
                    Text(`来源: ${this.book.bookSourceName}`)
                      .fontSize(12)
                      .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                      .margin({ bottom: 4 })
                  }

                  if (this.book.bookUrl) {
                    Text(this.book.bookUrl)
                      .fontSize(10)
                      .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                      .margin({ bottom: 4 })
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 12 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)

              if (this.book.intro) {
                Column() {
                  Text('简介')
                    .fontSize(14)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                    .fontWeight(500)
                    .width('100%')
                    .margin({ bottom: 8 })

                  Text(this.book.intro)
                    .fontSize(14)
                    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                    .lineHeight(22)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .margin({ top: 16 })
              }

              Button(this.chapters.length > 0 ? '开始阅读' : '加载章节')
                .width('100%')
                .height(44)
                .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                .fontColor(DesignSystem.Colors.text.primary.light)
                .borderRadius(8)
                .margin({ top: 20 })
                .onClick(() => {
                  this.startRead();
                })
            }
            .width('100%')
            .padding(20)
            .alignItems(HorizontalAlign.Start)
          }

          if (this.isLoadingChapters) {
            Column() {
              LoadingProgress()
                .width(40)
                .height(40)
                .color(DesignSystem.getPrimaryColor(this.isLightMode))
              Text('加载中...')
                .fontSize(14)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                .margin({ top: 10 })
            }
            .width('100%')
            .height(200)
            .justifyContent(FlexAlign.Center)
          } else if (this.chapters.length > 0) {
            Column() {
              Text(`目录（${this.chapters.length}章）`)
                .fontSize(14)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                .fontWeight(500)
                .width('100%')
                .margin({ bottom: 12 })

              List() {
                ForEach(this.chapters, (chapter: Chapter, index: number) => {
                  ListItem() {
                    Row() {
                      Text(chapter.title)
                        .fontSize(14)
                        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)

                      if (chapter.isVip) {
                        Text('VIP')
                          .fontSize(10)
                          .fontColor(DesignSystem.Colors.text.primary.light)
                          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                          .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                          .borderRadius(4)
                          .margin({ left: 8 })
                      }
                    }
                    .width('100%')
                    .padding(12)
                    .borderRadius(8)
                    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                  }
                  .margin({ bottom: 8 })
                  .onClick(() => {
                    this.currentChapterIndex = index;
                    try {
                      router.pushUrl({
                        url: 'pages/ReadPage',
                        params: {
                          bookId: this.bookId,
                          chapterIndex: index,
                          chapterUrl: chapter.url
                        }
                      });
                      hilog.info(0, 'BookDetailPage', 'push page success');
                    } catch (err) {
                      hilog.error(0, 'BookDetailPage', `pushPage failed: ${err}`);
                    }
                  })
                }, (chapter: Chapter) => chapter.id || chapter.url)
              }
              .width('100%')
              .height('100%')
              .cachedCount(10)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ top: 20 })
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
}

export default BookDetailPage;
