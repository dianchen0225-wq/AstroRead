import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { Book } from '../models/Book';
import { Logger } from '../utils/Logger';
import { NavigationManager } from '../common/NavigationManager';
import common from '@ohos.app.ability.common';
import { BookCoverImage } from '../components/BookCoverImage';

type ViewMode = 'list' | 'grid';

@ComponentV2
export struct BookshelfPage {
  @Local isLightMode: boolean = true;
  @Local activeTabIndex: number = 0;
  @Local bookList: Book[] = [];
  @Local isLoading: boolean = false;
  @Local viewMode: ViewMode = 'list';
  @Local pressedBookId: string = '';
  @Param safeAreaTop: number = 0;
  
  private isComponentActive: boolean = false;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isComponentActive = true;
    this.isLightMode = themeManager.isLightTheme();
    this.activeTabIndex = 0;
    themeManager.addListener(this.themeListener);
    
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    viewModelManager.setContext(context);
    
    this.loadBooks();
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    this.bookList = [];
  }

  async loadBooks(): Promise<void> {
    if (!this.isComponentActive) return;
    
    this.isLoading = true;
    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      this.bookList = await bookViewModel.loadAllBooks();
    } catch (error) {
      Logger.error('BookshelfPage', `加载书籍失败: ${error}`);
    } finally {
      if (this.isComponentActive) {
        this.isLoading = false;
      }
    }
  }

  private toggleViewMode(): void {
    this.viewMode = this.viewMode === 'list' ? 'grid' : 'list';
  }

  build() {
    Column() {
      this.buildHeader()
      
      this.buildTabBar()
      
      this.buildContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }

  @Builder
  buildHeader() {
    Row() {
      Column() {
        Text($r('app.string.bookshelf'))
          .fontSize(DesignSystem.Typography.size.xl)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.bold)
        
        if (this.bookList.length > 0) {
          Text(`${this.bookList.length} 本书`)
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
            .margin({ top: DesignSystem.Spacing.xs })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      
      Row() {
        Row() {
          Text(this.viewMode === 'list' ? '▦' : '☰')
            .fontSize(DesignSystem.Typography.size.base)
            .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
        }
        .width(40)
        .height(40)
        .borderRadius(DesignSystem.BorderRadius.md)
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .justifyContent(FlexAlign.Center)
        .border({
          width: 1,
          color: DesignSystem.getBorderColor(this.isLightMode)
        })
        .onClick(() => {
          this.toggleViewMode();
        })
      }
    }
    .width('100%')
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: this.safeAreaTop + DesignSystem.Spacing.md,
      bottom: DesignSystem.Spacing.md
    })
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }

  @Builder
  buildTabBar() {
    Row() {
      this.buildTabItem($r('app.string.recent_read'), 0)
      this.buildTabItem($r('app.string.favorites'), 1)
    }
    .width('100%')
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: { bottom: 1 },
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
  }

  @Builder
  buildTabItem(title: ResourceStr, index: number) {
    Column() {
      Text(title)
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(this.activeTabIndex === index ?
          DesignSystem.getPrimaryColor(this.isLightMode) :
          DesignSystem.getSecondaryTextColor(this.isLightMode))
        .fontWeight(this.activeTabIndex === index ?
          DesignSystem.Typography.weight.semibold :
          DesignSystem.Typography.weight.regular)
        .padding({
          top: DesignSystem.Spacing.md,
          bottom: DesignSystem.Spacing.sm
        })
        .onClick(() => {
          this.activeTabIndex = index;
        })
      
      Row()
        .width(24)
        .height(3)
        .borderRadius(2)
        .backgroundColor(this.activeTabIndex === index ?
          DesignSystem.getPrimaryColor(this.isLightMode) :
          Color.Transparent)
        .animation({
          duration: DesignSystem.AnimationDuration.fast,
          curve: DesignSystem.AnimationCurve.easeOut
        })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildContent() {
    if (this.isLoading) {
      this.buildLoadingState()
    } else if (this.bookList.length === 0) {
      this.buildEmptyState()
    } else {
      if (this.viewMode === 'list') {
        this.buildListView()
      } else {
        this.buildGridView()
      }
    }
  }

  @Builder
  buildLoadingState() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(DesignSystem.getPrimaryColor(this.isLightMode))
      
      Text('加载中...')
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ top: DesignSystem.Spacing.md })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildEmptyState() {
    Column() {
      Column() {
        Text('📚')
          .fontSize(64)
          .margin({ bottom: DesignSystem.Spacing.lg })
        
        Text('书架空空如也')
          .fontSize(DesignSystem.Typography.size.lg)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.medium)
          .margin({ bottom: DesignSystem.Spacing.sm })
        
        Text('去搜索页面添加书籍吧')
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
      }
      .padding(DesignSystem.Spacing.xxl)
      .borderRadius(DesignSystem.BorderRadius.xl)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .border({
        width: 1,
        color: DesignSystem.getBorderColor(this.isLightMode)
      })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(DesignSystem.Spacing.xxl)
  }

  @Builder
  buildListView() {
    List({ space: DesignSystem.Spacing.md }) {
      ForEach(this.bookList, (book: Book) => {
        ListItem() {
          this.buildBookListItem(book)
        }
      }, (book: Book) => book.id)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: DesignSystem.Spacing.md,
      bottom: DesignSystem.Spacing.md
    })
    .cachedCount(5)
  }

  @Builder
  buildBookListItem(book: Book) {
    Row() {
      Stack() {
        BookCoverImage({
          src: book.cover || $r('app.media.startIcon'),
          bookWidth: 60,
          bookHeight: 80,
          radius: DesignSystem.BorderRadius.md
        })
        
        if (book.readProgress > 0) {
          Column() {
            Row() {
              Text(`${book.readProgress}%`)
                .fontSize(8)
                .fontColor('#FFFFFF')
                .fontWeight(DesignSystem.Typography.weight.bold)
            }
            .padding({
              left: DesignSystem.Spacing.xs,
              right: DesignSystem.Spacing.xs,
              top: 2,
              bottom: 2
            })
            .borderRadius(DesignSystem.BorderRadius.sm)
            .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          }
          .alignItems(HorizontalAlign.End)
          .width('100%')
        }
      }
      .alignContent(Alignment.TopEnd)

      Column() {
        Text(book.name)
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (book.author) {
          Text(book.author)
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ top: DesignSystem.Spacing.xs })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Blank()

        Row() {
          Column() {
            Progress({
              value: book.readProgress,
              total: 100,
              type: ProgressType.Linear
            })
              .width('100%')
              .height(4)
              .color(DesignSystem.getPrimaryColor(this.isLightMode))
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          }
          .layoutWeight(1)
          
          Text('›')
            .fontSize(DesignSystem.Typography.size.xl)
            .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
            .margin({ left: DesignSystem.Spacing.sm })
        }
      }
      .layoutWeight(1)
      .height(80)
      .justifyContent(FlexAlign.Start)
      .margin({ left: DesignSystem.Spacing.md })
    }
    .width('100%')
    .padding(DesignSystem.Spacing.md)
    .borderRadius(DesignSystem.BorderRadius.lg)
    .backgroundColor(this.pressedBookId === book.id ?
      DesignSystem.getActiveColor(this.isLightMode) :
      DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .shadow({
      radius: 2,
      color: this.isLightMode ? 'rgba(0,0,0,0.03)' : 'rgba(0,0,0,0.15)',
      offsetX: 0,
      offsetY: 1
    })
    .scale({
      x: this.pressedBookId === book.id ? 0.98 : 1,
      y: this.pressedBookId === book.id ? 0.98 : 1
    })
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      NavigationManager.getInstance().navigateToBookDetail({ bookId: book.id });
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedBookId = book.id;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedBookId = '';
      }
    })
  }

  @Builder
  buildGridView() {
    Grid() {
      ForEach(this.bookList, (book: Book) => {
        GridItem() {
          this.buildBookGridItem(book)
        }
      }, (book: Book) => book.id)
    }
    .columnsTemplate('1fr 1fr 1fr')
    .rowsGap(DesignSystem.Spacing.md)
    .columnsGap(DesignSystem.Spacing.md)
    .width('100%')
    .layoutWeight(1)
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: DesignSystem.Spacing.md,
      bottom: DesignSystem.Spacing.md
    })
  }

  @Builder
  buildBookGridItem(book: Book) {
    Column() {
      Stack() {
        BookCoverImage({
          src: book.cover || $r('app.media.startIcon'),
          bookWidth: 100,
          bookHeight: 140,
          radius: DesignSystem.BorderRadius.md
        })
        
        if (book.readProgress > 0) {
          Column() {
            Row() {
              Text(`${book.readProgress}%`)
                .fontSize(8)
                .fontColor('#FFFFFF')
                .fontWeight(DesignSystem.Typography.weight.bold)
            }
            .padding({
              left: DesignSystem.Spacing.xs,
              right: DesignSystem.Spacing.xs,
              top: 2,
              bottom: 2
            })
            .borderRadius(DesignSystem.BorderRadius.sm)
            .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          }
          .alignItems(HorizontalAlign.End)
          .width('100%')
        }
      }
      .alignContent(Alignment.TopEnd)

      Text(book.name)
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.medium)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: DesignSystem.Spacing.sm })
        .textAlign(TextAlign.Start)

      if (book.author) {
        Text(book.author)
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
      }
    }
    .width('100%')
    .padding(DesignSystem.Spacing.sm)
    .borderRadius(DesignSystem.BorderRadius.lg)
    .backgroundColor(this.pressedBookId === book.id ?
      DesignSystem.getActiveColor(this.isLightMode) :
      DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .scale({
      x: this.pressedBookId === book.id ? 0.95 : 1,
      y: this.pressedBookId === book.id ? 0.95 : 1
    })
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      NavigationManager.getInstance().navigateToBookDetail({ bookId: book.id });
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedBookId = book.id;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedBookId = '';
      }
    })
  }
}
