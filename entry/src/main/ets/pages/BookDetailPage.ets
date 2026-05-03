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
import { Logger } from '../utils/performance/Logger';
import { common } from '@kit.AbilityKit';

@Entry
@ComponentV2
struct BookDetailPage {
  @Param bookId: string = '';
  @Local isLightMode: boolean = true;
  @Local book: Book | null = null;
  @Local chapters: Chapter[] = [];
  @Local isLoadingChapters: boolean = false;
  @Local bookSource: BookSource | null = null;
  @Local showChapterList: boolean = false;
  @Local currentChapterIndex: number = 0;
  @Local isAdded: boolean = false;
  @Local dialogController: CustomDialogController = new CustomDialogController({
    builder: this.dialogBuilder,
    cancel: this.handleCancel,
    autoCancel: true
  })
  private isComponentActive: boolean = false;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  @Builder
  dialogBuilder() {
    Column() {
      Text('添加成功')
        .fontSize(24)
        .fontColor(("app.color.text_primary"))
        .margin({ bottom: 20 })
      
      Row() {
        Button('确定')
          .fontSize(16)
            .backgroundColor(("app.color.primary"))
            .fontColor(("app.color.text_white"))
          .borderRadius(8)
          .layoutWeight(1)
          .margin({ right: 10 })
          .onClick(() => {
            this.dialogController.close();
          })
          
        Button('取消')
          .fontSize(16)
            .backgroundColor(("app.color.background_secondary"))
            .fontColor(("app.color.text_primary"))
          .borderRadius(8)
          .layoutWeight(1)
          .onClick(() => {
            this.dialogController.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .padding(20)
    .width('300vp')
  }

  handleCancel(): void {
    // 处理对话框取消逻辑
  }

  aboutToAppear(): void {
    this.isComponentActive = true;
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    viewModelManager.setContext(context);

    Logger.info('BookDetailPage', `接收到的 bookId: ${this.bookId}`);

    this.loadBookDetail();
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    this.chapters = [];
    this.book = null;
    this.bookSource = null;
  }
  async loadBookDetail(): Promise<void> {
    if (!this.isComponentActive) return;
    
    Logger.info('BookDetailPage', `bookId: ${this.bookId}`);

    if (this.bookId) {
      try {
        const bookViewModel = viewModelManager.getBookViewModel();
        Logger.info('BookDetailPage', '开始查询书籍...');
        this.book = await bookViewModel.getBookById(this.bookId);
        Logger.info('BookDetailPage', `查询结果: ${this.book ? '找到书籍' : '未找到书籍'}`);
        if (this.book) {
          Logger.info('BookDetailPage', `书籍详情: name=${this.book.name}, bookSourceId=${this.book.bookSourceId}`);
        }

        if (this.book && this.isComponentActive) {
          const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
          this.bookSource = await bookSourceViewModel.getBookSourceById(this.book.bookSourceId);
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

  async loadChapters(): Promise<void> {
    if (!this.book || !this.isComponentActive) {
      Logger.warn('BookDetailPage', '无法加载章节：书籍为空或组件未激活');
      return;
    }

    Logger.info('BookDetailPage', '开始加载章节...');
    this.isLoadingChapters = true;
    try {
      const chapterViewModel = viewModelManager.getChapterViewModel();
      Logger.info('BookDetailPage', '先从本地获取章节...');
      this.chapters = await chapterViewModel.getChapters(this.bookId);
      Logger.info('BookDetailPage', `本地章节数: ${this.chapters.length}`);

      if (this.chapters.length === 0 && this.bookSource && this.isComponentActive) {
        if (!this.book.bookUrl || this.book.bookUrl.trim() === '') {
          Logger.warn('BookDetailPage', '书籍URL为空，无法从网络获取章节');
          return;
        }
        Logger.info('BookDetailPage', '从网络获取章节...');
        Logger.info('BookDetailPage', `书源: ${this.bookSource.name}, URL: ${this.book.bookUrl}`);
        this.chapters = await chapterViewModel.fetchAndSaveChapters(
          this.bookId,
          this.bookSource,
          this.book.bookUrl
        );
        Logger.info('BookDetailPage', `网络获取章节数: ${this.chapters.length}`);
      }
    } catch (error) {
      Logger.error('BookDetailPage', `加载章节失败: ${error}`);
    } finally {
      if (this.isComponentActive) {
        this.isLoadingChapters = false;
      }
    }
  }

  async addBook(): Promise<void> {
    if (!this.book || !this.isComponentActive) {
      return;
    }

    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      await bookViewModel.addBook(this.book);
      this.isAdded = true;
      this.dialogController.open();
    } catch (error) {
      Logger.error('BookDetailPage', `添加书籍失败: ${error}`);
    }
  }

  async startRead(): Promise<void> {
    if (this.chapters.length === 0) {
      Logger.info('BookDetailPage', '开始加载章节...');
      await this.loadChapters();
      if (this.chapters.length === 0) {
        Logger.error('BookDetailPage', '章节加载失败');
        return;
      }
    }

    try {
      const chapterIndex = this.book?.lastReadChapterIndex ? this.book.lastReadChapterIndex : 0;
      // TODO: navigate to ReadPage
      Logger.info('BookDetailPage', 'push page success');
    } catch (err) {
      Logger.error('BookDetailPage', `pushPage failed: ${err}`);
    }
  }

  build() {
    Column() {
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
                      // TODO: navigate to ReadPage
                      Logger.info('BookDetailPage', 'push page success');
                    } catch (err) {
                      Logger.error('BookDetailPage', `pushPage failed: ${err}`);
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

export { BookDetailPage };