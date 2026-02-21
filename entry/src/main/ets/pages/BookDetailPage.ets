import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { Book } from '../models/Book';
import { Chapter } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { Logger } from '../utils/Logger';
import { NavigationManager } from '../common/NavigationManager';
import { CommonNavBar } from '../components/CommonNavBar';
import { AppButton, AppLoading, AppEmpty } from '../components/UIComponents';
import common from '@ohos.app.ability.common';

@Entry
@ComponentV2
struct BookDetailPage {
  @Param bookId: string = '';
  @Local isLightMode: boolean = true;
  @Local book: Book | null = null;
  @Local chapters: Chapter[] = [];
  @Local isLoadingChapters: boolean = false;
  @Local bookSource: BookSource | null = null;
  @Local currentChapterIndex: number = 0;
  @Local isAdded: boolean = false;
  @Local showChapterSheet: boolean = false;
  @Local isAdding: boolean = false;
  
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

    this.isAdding = true;
    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      await bookViewModel.addBook(this.book);
      this.isAdded = true;
    } catch (error) {
      Logger.error('BookDetailPage', `添加书籍失败: ${error}`);
    } finally {
      this.isAdding = false;
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
      NavigationManager.getInstance().navigateTo('ReadPage', {
        bookId: this.bookId,
        initialChapterIndex: chapterIndex,
        initialChapterUrl: this.chapters[chapterIndex].url
      });
      Logger.info('BookDetailPage', 'push page success');
    } catch (err) {
      Logger.error('BookDetailPage', `pushPage failed: ${err}`);
    }
  }

  async openChapter(index: number): Promise<void> {
    this.showChapterSheet = false;
    
    try {
      NavigationManager.getInstance().navigateTo('ReadPage', {
        bookId: this.bookId,
        initialChapterIndex: index,
        initialChapterUrl: this.chapters[index].url
      });
    } catch (err) {
      Logger.error('BookDetailPage', `pushPage failed: ${err}`);
    }
  }

  build() {
    Column() {
      CommonNavBar({
        title: '书籍详情',
        showBack: true,
        rightActions: [
          {
            icon: '📚',
            text: this.isAdded ? '已添加' : '添加',
            onClick: () => {
              if (!this.isAdded) {
                this.addBook();
              }
            }
          }
        ]
      })

      if (this.book) {
        Scroll() {
          Column() {
            this.buildBookInfo()
            
            if (this.book.intro) {
              this.buildIntro()
            }

            this.buildActionButtons()

            if (this.isLoadingChapters) {
              AppLoading({ loadingText: '加载章节中...' })
                .margin({ top: DesignSystem.Spacing.xl })
            } else if (this.chapters.length > 0) {
              this.buildChapterList()
            }
          }
          .width('100%')
          .padding(DesignSystem.Spacing.lg)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      } else {
        AppEmpty({
          emptyIcon: '📖',
          emptyTitle: '未找到书籍',
          emptyDescription: '该书籍可能已被删除'
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    .bindSheet($$this.showChapterSheet, this.buildChapterSheet(), {
      height: '70%',
      backgroundColor: Color.Transparent,
      dragBar: true
    })
  }

  @Builder
  buildBookInfo() {
    Row() {
      if (this.book?.cover) {
        Image(this.book.cover)
          .width(100)
          .height(140)
          .borderRadius(DesignSystem.BorderRadius.md)
          .objectFit(ImageFit.Cover)
      } else {
        Column() {
          Text('📖')
            .fontSize(40)
        }
        .width(100)
        .height(140)
        .borderRadius(DesignSystem.BorderRadius.md)
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .justifyContent(FlexAlign.Center)
      }

      Column() {
        Text(this.book?.name || '')
          .fontSize(DesignSystem.Typography.size.xl)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.book?.author) {
          Text(this.book.author)
            .fontSize(DesignSystem.Typography.size.sm)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ top: DesignSystem.Spacing.sm })
        }

        if (this.book?.bookSourceName) {
          Row() {
            Text('来源: ')
              .fontSize(DesignSystem.Typography.size.xs)
              .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
            Text(this.book.bookSourceName)
              .fontSize(DesignSystem.Typography.size.xs)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          }
          .margin({ top: DesignSystem.Spacing.sm })
        }

        if (this.book?.kind) {
          Text(this.book.kind)
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .padding({
              left: DesignSystem.Spacing.sm,
              right: DesignSystem.Spacing.sm,
              top: DesignSystem.Spacing.xs,
              bottom: DesignSystem.Spacing.xs
            })
            .borderRadius(DesignSystem.BorderRadius.sm)
            .backgroundColor(DesignSystem.getHoverColor(this.isLightMode))
            .margin({ top: DesignSystem.Spacing.sm })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: DesignSystem.Spacing.md })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  buildIntro() {
    Column() {
      Text('简介')
        .fontSize(DesignSystem.Typography.size.base)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.semibold)
        .width('100%')
        .margin({ bottom: DesignSystem.Spacing.sm })

      Text(this.book?.intro || '')
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .lineHeight(22)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: DesignSystem.Spacing.lg })
    .padding(DesignSystem.Spacing.md)
    .borderRadius(DesignSystem.BorderRadius.lg)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }

  @Builder
  buildActionButtons() {
    Row({ space: DesignSystem.Spacing.md }) {
      AppButton({
        buttonText: this.chapters.length > 0 ? '开始阅读' : '加载章节',
        variant: 'primary',
        fullWidth: true,
        loading: this.isLoadingChapters
      })
        .setOnClick(() => {
          this.startRead();
        })

      if (this.chapters.length > 0) {
        AppButton({
          buttonText: '目录',
          variant: 'secondary',
          fullWidth: true
        })
          .setOnClick(() => {
            this.showChapterSheet = true;
          })
      }
    }
    .width('100%')
    .margin({ top: DesignSystem.Spacing.lg })
  }

  @Builder
  buildChapterList() {
    Column() {
      Row() {
        Text(`目录`)
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)

        Blank()

        Text(`${this.chapters.length} 章`)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))

        Text('查看全部')
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .margin({ left: DesignSystem.Spacing.md })
          .onClick(() => {
            this.showChapterSheet = true;
          })
      }
      .width('100%')
      .margin({ bottom: DesignSystem.Spacing.md })

      Column() {
        ForEach(this.chapters.slice(0, 5), (chapter: Chapter, index: number) => {
          Row() {
            Text(chapter.title)
              .fontSize(DesignSystem.Typography.size.sm)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            if (chapter.isVip) {
              Text('VIP')
                .fontSize(DesignSystem.Typography.size.xs)
                .fontColor('#FFFFFF')
                .padding({
                  left: DesignSystem.Spacing.xs,
                  right: DesignSystem.Spacing.xs,
                  top: 2,
                  bottom: 2
                })
                .borderRadius(DesignSystem.BorderRadius.sm)
                .backgroundColor(DesignSystem.getWarningColor(this.isLightMode))
            }
          }
          .width('100%')
          .padding(DesignSystem.Spacing.sm)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(this.currentChapterIndex === index ?
            DesignSystem.getHoverColor(this.isLightMode) :
            Color.Transparent)
          .onClick(() => {
            this.openChapter(index);
          })
        })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: DesignSystem.Spacing.lg })
    .padding(DesignSystem.Spacing.md)
    .borderRadius(DesignSystem.BorderRadius.lg)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }

  @Builder
  buildChapterSheet() {
    Column() {
      Row() {
        Text('目录')
          .fontSize(DesignSystem.Typography.size.lg)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)
          .layoutWeight(1)

        Text(`${this.chapters.length} 章`)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
      }
      .width('100%')
      .padding(DesignSystem.Spacing.lg)

      List() {
        ForEach(this.chapters, (chapter: Chapter, index: number) => {
          ListItem() {
            Row() {
              Text(chapter.title)
                .fontSize(DesignSystem.Typography.size.sm)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)

              if (chapter.isVip) {
                Text('VIP')
                  .fontSize(DesignSystem.Typography.size.xs)
                  .fontColor('#FFFFFF')
                  .padding({
                    left: DesignSystem.Spacing.xs,
                    right: DesignSystem.Spacing.xs,
                    top: 2,
                    bottom: 2
                  })
                  .borderRadius(DesignSystem.BorderRadius.sm)
                  .backgroundColor(DesignSystem.getWarningColor(this.isLightMode))
              }
            }
            .width('100%')
            .padding(DesignSystem.Spacing.md)
            .borderRadius(DesignSystem.BorderRadius.md)
            .backgroundColor(this.currentChapterIndex === index ?
              DesignSystem.getHoverColor(this.isLightMode) :
              Color.Transparent)
          }
          .onClick(() => {
            this.openChapter(index);
          })
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({
        left: DesignSystem.Spacing.lg,
        right: DesignSystem.Spacing.lg
      })
      .cachedCount(10)
    }
    .width('100%')
    .height('100%')
    .borderRadius({
      topLeft: DesignSystem.BorderRadius.xl,
      topRight: DesignSystem.BorderRadius.xl
    })
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }
}

export default BookDetailPage;
