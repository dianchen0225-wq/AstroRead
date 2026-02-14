import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { BookViewModel } from '../viewmodel/BookViewModel';
import { ChapterViewModel } from '../viewmodel/ChapterViewModel';
import { BookSourceViewModel } from '../viewmodel/BookSourceViewModel';
import { ReadConfigViewModel } from '../viewmodel/ReadConfigViewModel';
import { Book } from '../models/Book';
import { Chapter } from '../models/Book';
import { ChapterContent } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { ReadConfig } from '../models/ReadConfig';
import { Logger } from '../utils/Logger';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';

interface RouterParams {
  bookId?: string;
  chapterIndex?: number;
  chapterUrl?: string;
}
@Entry
@ComponentV2
export struct ReadPage {
  @Local isLightMode: boolean = true;
  @Local book: Book | null = null;
  @Local chapters: Chapter[] = [];
  @Local currentChapterIndex: number = 0;
  @Local chapterContent: ChapterContent | null = null;
  @Local isLoading: boolean = false;
  @Local showChapterList: boolean = false;
  @Local showMenu: boolean = false;
  @Local readConfig: ReadConfig = ReadConfigViewModel.DEFAULT_READ_CONFIG;

  private bookId: string = '';
  private chapterIndex: number = 0;
  private chapterUrl: string = '';
  private bookViewModel: BookViewModel = new BookViewModel();
  private chapterViewModel: ChapterViewModel = new ChapterViewModel();
  private bookSourceViewModel: BookSourceViewModel = new BookSourceViewModel();
  private readConfigViewModel: ReadConfigViewModel = new ReadConfigViewModel();
  private bookSource: BookSource | null = null;

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener((isDark: boolean) => {
      this.isLightMode = !isDark;
    });
    this.loadReadConfig();
    this.loadBookDetail();
  }

  async loadReadConfig() {
    try {
      this.readConfig = await this.readConfigViewModel.getReadConfig();
    } catch (error) {
      Logger.error('ReadPage', `加载阅读配置失败: ${error}`);
    }
  }
  async loadBookDetail() {
    const params = router.getParams() as RouterParams;
    this.bookId = params?.bookId || '';
    this.chapterIndex = params?.chapterIndex || 0;
    this.chapterUrl = params?.chapterUrl || '';
    Logger.info('ReadPage', `bookId: ${this.bookId}, chapterIndex: ${this.chapterIndex}, chapterUrl: ${this.chapterUrl}`);
    if (this.bookId) {
        this.book = await this.bookViewModel.getBookById(this.bookId);
      if (this.book) {
        this.bookSource = this.bookSourceViewModel.getBookSourceById(this.book.bookSourceId) || null;
      }
    }
    await this.loadChapters();
    await this.loadChapterContent();
  }

  async loadChapters() {
    if (!this.book) {
      return;
    }
    try {
      this.chapters = await this.chapterViewModel.getChapters(this.bookId);
      if (this.chapters.length === 0 && this.bookSource) {
        this.chapters = await this.chapterViewModel.fetchAndSaveChapters(this.bookId, this.bookSource, this.book.bookUrl);
      }
    } catch (error) {
      Logger.error('ReadPage', `加载章节失败: ${error}`);
    }
  }

  async loadChapterContent() {
    if (!this.book || !this.bookSource) {
      return;
    }
    this.isLoading = true;
    try {
      const chapterId = this.chapters[this.chapterIndex].id;
      this.chapterContent = await this.chapterViewModel.getChapterContent(chapterId, this.chapterUrl, this.bookSource);
    } catch (error) {
      Logger.error('ReadPage', `加载章节内容失败: ${error}`);
      promptAction.showToast({
        message: '加载失败',
        duration: 2000
      });
    } finally {
      this.isLoading = false;
    }
  }

  async nextChapter() {
    if (this.chapterIndex < this.chapters.length - 1) {
      this.chapterIndex++;
      this.chapterUrl = this.chapters[this.chapterIndex].url;
      await this.loadChapterContent();
    } else {
      promptAction.showToast({
        message: '已经是最后一章了',
        duration: 2000
      });
    }
  }

  async prevChapter() {
    if (this.chapterIndex > 0) {
      this.chapterIndex--;
      this.chapterUrl = this.chapters[this.chapterIndex].url;
      await this.loadChapterContent();
    } else {
      promptAction.showToast({
        message: '已经是第一章了',
        duration: 2000
      });
    }
  }

  async updateReadProgress() {
    if (!this.book) {
      return;
    }
    try {
      await this.bookViewModel.updateReadProgress(this.book.id, this.chapterIndex, this.chapters[this.chapterIndex].title);
    } catch (error) {
      Logger.error('ReadPage', `更新阅读进度失败: ${error}`);
    }
  }

  build() {
    Stack() {
      Column() {
        if (this.isLoading) {
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
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.chapterContent) {
          Column() {
            if (this.book && this.chapters.length > 0) {
              Text(this.chapters[this.chapterIndex].title)
                .fontSize(18)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .fontWeight(600)
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ top: 20, bottom: 20 })
            }
            Text(this.chapterContent.content)
              .fontSize(this.readConfig.fontSize)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .lineHeight(this.readConfig.lineSpacing)
              .width('100%')
              .padding({
                left: this.readConfig.margins.left,
                right: this.readConfig.margins.right,
                top: this.readConfig.margins.top,
                bottom: this.readConfig.margins.bottom
              })
              .letterSpacing(this.readConfig.letterSpacing)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
      .onClick(() => {
        this.showMenu = !this.showMenu;
      })

      if (this.showMenu) {
        Column() {
          Row() {
            Button() {
              Text('‹')
                .fontSize(20)
                .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
            }
            .width(32)
            .height(32)
            .borderRadius(16)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .margin({ right: 15 })
            .onClick(() => {
              router.back();
            })

            if (this.book) {
              Text(this.book.name)
                .fontSize(18)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .fontWeight(600)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
          .padding({ left: 15, right: 20, top: 15, bottom: 15 })
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .border({
            width: { bottom: 1 },
            color: DesignSystem.getBorderColor(this.isLightMode)
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      if (this.showMenu) {
        Column() {
          Row() {
            Text('A+')
              .fontSize(14)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(8)
              .margin({ right: 10 })
              .onClick(() => {
                this.readConfig.fontSize = Math.min(this.readConfig.fontSize + 2, 32);
                this.readConfigViewModel.updateReadConfig(this.readConfig);
              })

            Text('A-')
              .fontSize(14)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(8)
              .margin({ right: 10 })
              .onClick(() => {
                this.readConfig.fontSize = Math.max(this.readConfig.fontSize - 2, 12);
                this.readConfigViewModel.updateReadConfig(this.readConfig);
              })

            Text('目录')
              .fontSize(14)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(8)
              .margin({ right: 10 })
              .onClick(() => {
                this.showChapterList = true;
                this.showMenu = false;
              })

            Text('上一章')
              .fontSize(14)
              .fontColor(this.chapterIndex > 0 ? DesignSystem.getPrimaryTextColor(this.isLightMode) : '#999')
              .backgroundColor(this.chapterIndex > 0 ? DesignSystem.getSecondaryBackgroundColor(this.isLightMode) : 'transparent')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(8)
              .margin({ right: 10 })
              .onClick(() => {
                if (this.chapterIndex > 0) {
                  this.prevChapter();
                }
              })

            Text('下一章')
              .fontSize(14)
              .fontColor(this.chapterIndex < this.chapters.length - 1 ? DesignSystem.getPrimaryTextColor(this.isLightMode) : '#999')
              .backgroundColor(this.chapterIndex < this.chapters.length - 1 ? DesignSystem.getSecondaryBackgroundColor(this.isLightMode) : 'transparent')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(8)
              .onClick(() => {
                if (this.chapterIndex < this.chapters.length - 1) {
                  this.nextChapter();
                }
              })
          }
          .width('100%')
          .padding(15)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .border({
            width: { top: 1 },
            color: DesignSystem.getBorderColor(this.isLightMode)
          })
        }
        .width('100%')
        .position({ x: 0, y: '100%' })
        .translate({ y: '-100%' })
      }

      if (this.showChapterList) {
        Column() {
          Row() {
            Text('目录')
              .fontSize(18)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .fontWeight(600)
              .layoutWeight(1)

            Button() {
              Text('✕')
                .fontSize(20)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            }
            .width(32)
            .height(32)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .onClick(() => {
              this.showChapterList = false;
            })
          }
          .width('100%')
          .padding(15)
          .alignItems(VerticalAlign.Center)

          Scroll() {
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
                .backgroundColor(index === this.chapterIndex ? DesignSystem.getSecondaryBackgroundColor(this.isLightMode) : Color.Transparent)
                .margin({ bottom: 8 })
                .onClick(() => {
                  this.chapterIndex = index;
                  this.chapterUrl = chapter.url;
                  this.showChapterList = false;
                  this.loadChapterContent();
                })
              })
            }
            .width('100%')
            .padding(15)
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.Top)
          .scrollBar(BarState.Auto)
        }
        .width(360)
        .height('100%')
        .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }
}
