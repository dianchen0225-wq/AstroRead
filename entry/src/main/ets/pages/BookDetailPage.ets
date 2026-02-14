import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { BookViewModel } from '../viewmodel/BookViewModel';
import { ChapterViewModel } from '../viewmodel/ChapterViewModel';
import { BookSourceViewModel } from '../viewmodel/BookSourceViewModel';
import { Book } from '../models/Book';
import { Chapter } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { Logger } from '../utils/Logger';
import { promptAction } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import common from '@ohos.app.ability.common';

interface RouterParams {
  bookId?: string;
}
@Entry
@ComponentV2
export struct BookDetailPage {
  @Local isLightMode: boolean = true;
  @Local book: Book | null = null;
  @Local chapters: Chapter[] = [];
  @Local isLoadingChapters: boolean = false;
  @Local bookSource: BookSource | null = null;
  @Local showChapterList: boolean = false;
  @Local currentChapterIndex: number = 0;
  @Local isAdded: boolean = false;

  private bookId: string = '';
  private bookViewModel: BookViewModel = new BookViewModel();
  private chapterViewModel: ChapterViewModel = new ChapterViewModel();
  private bookSourceViewModel: BookSourceViewModel = new BookSourceViewModel();
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    this.bookViewModel.setContext(getContext(this) as common.UIAbilityContext);
    this.chapterViewModel.setContext(getContext(this) as common.UIAbilityContext);
    this.bookSourceViewModel.setContext(getContext(this) as common.UIAbilityContext);
    this.loadBookDetail();
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }
  async loadBookDetail() {
    const params = router.getParams() as RouterParams;
    this.bookId = params?.bookId || '';
    Logger.info('BookDetailPage', `bookId: ${this.bookId}`);
    if (this.bookId) {
      this.book = await this.bookViewModel.getBookById(this.bookId);
      if (this.book) {
        this.bookSource = this.bookSourceViewModel.getBookSourceById(this.book.bookSourceId) || null;
      }
    }
    await this.loadChapters();
    this.isAdded = await this.bookViewModel.isBookAdded(this.bookId);
  }

  async loadChapters() {
    if (!this.book) {
      return;
    }
    this.isLoadingChapters = true;
    try {
      this.chapters = await this.chapterViewModel.getChapters(this.bookId);
      if (this.chapters.length === 0 && this.bookSource) {
        this.chapters = await this.chapterViewModel.fetchAndSaveChapters(this.bookId, this.bookSource, this.book.bookUrl);
      }
    } catch (error) {
      Logger.error('BookDetailPage', `加载章节失败: ${error}`);
    } finally {
      this.isLoadingChapters = false;
    }
  }

  async addBook() {
    if (!this.book) {
      return;
    }
    try {
      await this.bookViewModel.addBook(this.book);
      this.isAdded = true;
      promptAction.showToast({
        message: '添加成功',
        duration: 2000
      });
    } catch (error) {
      promptAction.showToast({
        message: '添加失败',
        duration: 2000
      });
    }
  }

  async startRead() {
    if (this.chapters.length === 0) {
      promptAction.showToast({
        message: '暂无章节',
        duration: 2000
      });
      return;
    }
    const chapterIndex = this.book?.lastReadChapterIndex ? this.book.lastReadChapterIndex : 0;
    router.pushUrl({
      url: 'pages/ReadPage',
      params: {
        bookId: this.bookId,
        chapterIndex: chapterIndex,
        chapterUrl: this.chapters[chapterIndex].url
      }
    }).then(() => {
      hilog.info(0, 'testTag', 'push page success');
    }).catch((err: Error) => {
      hilog.error(0, 'testTag', `pushPage failed: ${err}`);
    });
  }

  build() {
    Column() {
      // 顶部导航栏
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
          .fontColor(this.isAdded ? DesignSystem.getSecondaryTextColor(this.isLightMode) : DesignSystem.Colors.text.primary.light)
          .backgroundColor(this.isAdded ? DesignSystem.getSecondaryBackgroundColor(this.isLightMode) : DesignSystem.getPrimaryColor(this.isLightMode))
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

              Column() {
                ForEach(this.chapters, (chapter: Chapter, index: number) => {
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
                  .margin({ bottom: 8 })
                  .onClick(() => {
                    this.currentChapterIndex = index;
                    router.pushUrl({
                      url: 'pages/ReadPage',
                      params: {
                        bookId: this.bookId,
                        chapterIndex: index,
                        chapterUrl: chapter.url
                      }
                    }).then(() => {
                      hilog.info(0, 'testTag', 'push page success');
                    }).catch((err: Error) => {
                      hilog.error(0, 'testTag', `pushPage failed: ${err}`);
                    });
                  })
                })
              }
              .width('100%')
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
