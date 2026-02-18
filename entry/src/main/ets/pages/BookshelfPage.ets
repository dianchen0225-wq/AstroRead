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

  @Builder
  listViewBuilder() {
    List({ space: 12 }) {
      ForEach(this.bookList, (book: Book) => {
        ListItem() {
          Row() {
            BookCoverImage({
              src: book.cover || $r('app.media.startIcon'),
              bookWidth: 60,
              bookHeight: 80,
              radius: 6
            })

            Column() {
              Text(book.name)
                .fontSize(16)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .fontWeight(600)
                .margin({ bottom: 4 })

              if (book.author) {
                Text(book.author)
                  .fontSize(12)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  .margin({ bottom: 8 })
              }

              Row() {
                Progress({
                  value: book.readProgress,
                  total: 100,
                  type: ProgressType.Linear
                })
                  .width('100%')
                  .height(4)
                  .color(DesignSystem.getPrimaryColor(this.isLightMode))
                  .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                  .margin({ right: 10 })

                Text(`${book.readProgress}%`)
                  .fontSize(11)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  .width(35)
                  .textAlign(TextAlign.End)
              }
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.SpaceBetween)
          }
          .width('100%')
          .padding(15)
          .borderRadius(12)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .onClick(() => {
            try {
              NavigationManager.getInstance().navigateTo('BookDetailPage', {
                bookId: book.id
              });
              Logger.info('BookshelfPage', 'push page success');
            } catch (err) {
              Logger.error('BookshelfPage', `pushPage failed: ${err}`);
            }
          })
        }
      }, (book: Book) => book.id)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20 })
    .cachedCount(5)
  }

  @Builder
  gridViewBuilder() {
    Grid() {
      ForEach(this.bookList, (book: Book) => {
        GridItem() {
          Column() {
            BookCoverImage({
              src: book.cover || $r('app.media.startIcon'),
              bookWidth: 100,
              bookHeight: 140,
              radius: 8
            })

            Text(book.name)
              .fontSize(14)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .fontWeight(500)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .margin({ top: 8 })
              .textAlign(TextAlign.Center)

            if (book.author) {
              Text(book.author)
                .fontSize(11)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .padding(8)
          .onClick(() => {
            try {
              NavigationManager.getInstance().navigateTo('BookDetailPage', {
                bookId: book.id
              });
              Logger.info('BookshelfPage', 'push page success');
            } catch (err) {
              Logger.error('BookshelfPage', `pushPage failed: ${err}`);
            }
          })
        }
      }, (book: Book) => book.id)
    }
    .columnsTemplate('1fr 1fr 1fr')
    .rowsGap(12)
    .columnsGap(12)
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.bookshelf'))
          .fontSize(18)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(600)
          .layoutWeight(1)

        Row() {
          Text(this.viewMode === 'list' ? '☰' : '▦')
            .fontSize(18)
            .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.toggleViewMode();
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 15, bottom: 15 })
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .border({
        width: { bottom: 1 },
        color: DesignSystem.getBorderColor(this.isLightMode)
      })

      Row() {
        Column() {
          Text($r('app.string.recent_read'))
            .fontSize(14)
            .fontColor(this.activeTabIndex === 0 ?
              DesignSystem.getPrimaryColor(this.isLightMode) :
              DesignSystem.getSecondaryTextColor(this.isLightMode))
            .padding({ top: 12, bottom: 10 })
            .onClick(() => {
              this.activeTabIndex = 0;
            })

          Row()
            .width(24)
            .height(2)
            .borderRadius(1)
            .backgroundColor(this.activeTabIndex === 0 ?
              DesignSystem.getPrimaryColor(this.isLightMode) :
              Color.Transparent)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text($r('app.string.favorites'))
            .fontSize(14)
            .fontColor(this.activeTabIndex === 1 ?
              DesignSystem.getPrimaryColor(this.isLightMode) :
              DesignSystem.getSecondaryTextColor(this.isLightMode))
            .padding({ top: 12, bottom: 10 })
            .onClick(() => {
              this.activeTabIndex = 1;
            })

          Row()
            .width(24)
            .height(2)
            .borderRadius(1)
            .backgroundColor(this.activeTabIndex === 1 ?
              DesignSystem.getPrimaryColor(this.isLightMode) :
              Color.Transparent)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .border({
        width: { bottom: 1 },
        color: DesignSystem.getBorderColor(this.isLightMode)
      })

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
      } else if (this.bookList.length === 0) {
        Column() {
          Text('📚')
            .fontSize(48)
            .margin({ bottom: 16 })
          Text('书架空空如也')
            .fontSize(16)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ bottom: 8 })
          Text('去搜索页面添加书籍吧')
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        }
        .width('100%')
        .height(300)
        .justifyContent(FlexAlign.Center)
      } else {
        if (this.viewMode === 'list') {
          this.listViewBuilder()
        } else {
          this.gridViewBuilder()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }
}
