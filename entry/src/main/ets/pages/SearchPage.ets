import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { BookSourceViewModel } from '../viewmodel/BookSourceViewModel';
import { BookViewModel } from '../viewmodel/BookViewModel';
import { BookSource } from '../models/BookSource';
import { Book } from '../models/Book';
import { Logger } from '../utils/Logger';
import { promptAction } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { NetworkManager } from '../utils/NetworkManager';

interface RankColor {
  light: string;
  dark: string;
}

@ComponentV2
export struct SearchPage {
  @Local isLightMode: boolean = true;
  @Local searchText: string = '';
  @Local searchHistory: string[] = ['斗破苍穹', '凡人修仙传', '三体', '活着'];
  @Local hotSearchList: string[] = ['完美世界', '雪中悍刀行', '诡秘之主', '庆余年', '赘婿'];
  @Local searchResults: Book[] = [];
  @Local isSearching: boolean = false;
  @Local hasSearched: boolean = false;
  @Local errorMessage: string = '';
  @Local hasEnabledSources: boolean = true;

  private bookSourceViewModel: BookSourceViewModel = new BookSourceViewModel();
  private bookViewModel: BookViewModel = new BookViewModel();
  private bookSources: BookSource[] = [];
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    const context = getContext(this) as common.UIAbilityContext;
    this.bookSourceViewModel.setContext(context);
    NetworkManager.getInstance().setContext(context);
    this.loadBookSources();
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  private async loadBookSources(): Promise<void> {
    try {
      this.bookSources = await this.bookSourceViewModel.loadEnabledBookSources();
      this.hasEnabledSources = this.bookSources.length > 0;
      Logger.info('SearchPage', `加载了${this.bookSources.length}个书源`);
    } catch (error) {
      Logger.error('SearchPage', `加载书源失败: ${error}`);
      this.hasEnabledSources = false;
    }
  }

  private async performSearch(): Promise<void> {
    if (!this.searchText.trim()) {
      promptAction.showToast({
        message: '请输入搜索关键词',
        duration: 2000
      });
      return;
    }

    this.isSearching = true;
    this.hasSearched = true;
    this.errorMessage = '';
    this.searchResults = [];

    try {
      Logger.info('SearchPage', `开始搜索: ${this.searchText}`);

      if (this.bookSources.length === 0) {
        await this.loadBookSources();
      }

      if (this.bookSources.length === 0) {
        this.errorMessage = '没有可用的书源';
        this.hasEnabledSources = false;
        this.isSearching = false;
        return;
      }

      const sourcesToUse = this.bookSources.slice(0, 5);
      Logger.info('SearchPage', `使用${sourcesToUse.length}个书源进行搜索`);

      const results = await this.bookViewModel.searchBooks(this.searchText.trim(), sourcesToUse);

      this.searchResults = results;
      Logger.info('SearchPage', `搜索完成，找到${results.length}本书`);

      if (results.length === 0) {
        this.errorMessage = '当前启用的书源无匹配结果';
      }

      this.addToSearchHistory(this.searchText.trim());

    } catch (error) {
      Logger.error('SearchPage', `搜索失败: ${error}`);
      const errorMsg = error instanceof Error ? error.message : '未知错误';
      
      if (errorMsg.includes('network') || errorMsg.includes('网络')) {
        this.errorMessage = '网络连接失败，请检查网络设置';
      } else if (errorMsg.includes('timeout') || errorMsg.includes('超时')) {
        this.errorMessage = '搜索超时，请稍后重试';
      } else {
        this.errorMessage = `搜索失败: ${errorMsg}`;
      }
    } finally {
      this.isSearching = false;
    }
  }

  private addToSearchHistory(keyword: string): void {
    const trimmedKeyword = keyword.trim();
    if (!trimmedKeyword) {
      return;
    }

    this.searchHistory = this.searchHistory.filter(item => item !== trimmedKeyword);
    this.searchHistory.unshift(trimmedKeyword);

    if (this.searchHistory.length > 10) {
      this.searchHistory = this.searchHistory.slice(0, 10);
    }
  }

  private async addToBookshelf(book: Book): Promise<void> {
    try {
      await this.bookViewModel.addBook(book);
      promptAction.showToast({
        message: '已添加到书架',
        duration: 2000
      });
    } catch (error) {
      Logger.error('SearchPage', `添加到书架失败: ${error}`);
      promptAction.showToast({
        message: '添加失败',
        duration: 2000
      });
    }
  }

  private navigateToSourcePage(): void {
    router.pushUrl({
      url: 'pages/MainPage',
      params: { tabIndex: 3 }
    }).catch((err: Error) => {
      Logger.error('SearchPage', `跳转失败: ${err}`);
    });
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
                this.performSearch();
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
              Text('正在搜索...')
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
                Text(`找到 ${this.searchResults.length} 本书籍`)
                  .fontSize(14)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  .width('100%')
                  .margin({ bottom: 12 })

                ForEach(this.searchResults, (book: Book) => {
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
                        Text(book.intro)
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
                  .margin({ bottom: 8 })
                  .borderRadius(8)
                  .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                })
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
                    this.searchHistory = [];
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
                      this.performSearch();
                    })
                })
              }
            }
            .width('100%')
            .margin({ bottom: 25 })

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
                    this.performSearch();
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
