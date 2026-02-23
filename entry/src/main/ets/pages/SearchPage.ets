import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { BookSource } from '../models/BookSource';
import { Book, SourceStatus } from '../models/Book';
import { PagedSearchResult, SearchProgress } from '../models/SearchResult';
import { Logger } from '../utils/Logger';
import { NavigationManager } from '../common/NavigationManager';
import { common } from '@kit.AbilityKit';
import { NetworkManager } from '../utils/NetworkManager';
import { purifyIntro } from '../utils/ContentPurifier';
import { sourceValidatorService, BatchValidationProgress } from '../utils/SourceValidatorService';

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
  @Local foundBooksCount: number = 0;
  @Local completedSources: number = 0;
  @Local totalSources: number = 0;
  @Local isValidating: boolean = false;
  @Local validationProgress: string = '';
  @Local showInvalidBooks: boolean = true;
  @Local validBooksCount: number = 0;
  @Local invalidBooksCount: number = 0;
  @Local pressedBookId: string = '';
  @Param safeAreaTop: number = 0;

  private bookSources: BookSource[] = [];
  private isComponentActive: boolean = false;
  private allSearchResults: Book[] = [];
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
    } catch (error) {
      Logger.error('SearchPage', `加载书源失败: ${error}`);
      this.hasEnabledSources = false;
    }
  }

  private addBookToArray(arr: Book[], book: Book): Book[] {
    const newArr: Book[] = [];
    for (let i = 0; i < arr.length; i++) {
      newArr.push(arr[i]);
    }
    newArr.push(book);
    return newArr;
  }

  private mergeBookArrays(arr1: Book[], arr2: Book[]): Book[] {
    const result: Book[] = [];
    for (let i = 0; i < arr1.length; i++) {
      result.push(arr1[i]);
    }
    for (let i = 0; i < arr2.length; i++) {
      result.push(arr2[i]);
    }
    return result;
  }

  private updateBookStatus(book: Book, status: SourceStatus): Book {
    return {
      id: book.id,
      name: book.name,
      author: book.author,
      cover: book.cover,
      intro: book.intro,
      kind: book.kind,
      wordCount: book.wordCount,
      latestChapter: book.latestChapter,
      bookSourceId: book.bookSourceId,
      bookSourceName: book.bookSourceName,
      bookUrl: book.bookUrl,
      lastUpdateTime: book.lastUpdateTime,
      addTime: book.addTime,
      readProgress: book.readProgress,
      lastReadChapter: book.lastReadChapter,
      lastReadChapterIndex: book.lastReadChapterIndex,
      lastReadTime: book.lastReadTime,
      totalChapters: book.totalChapters,
      currentChapterIndex: book.currentChapterIndex,
      currentChapterTitle: book.currentChapterTitle,
      isInShelf: book.isInShelf,
      sourceStatus: status
    } as Book;
  }

  private cloneBookArray(arr: Book[]): Book[] {
    const result: Book[] = [];
    for (let i = 0; i < arr.length; i++) {
      result.push(arr[i]);
    }
    return result;
  }

  private async performSearch(page: number = 1): Promise<void> {
    if (!this.searchText.trim()) return;

    this.isSearching = true;
    this.hasSearched = true;
    this.errorMessage = '';
    this.searchProgress = '正在初始化搜索...';
    this.foundBooksCount = 0;
    this.completedSources = 0;

    if (page === 1) {
      this.searchResults = [];
      this.currentPage = 1;
    }

    try {
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
      this.totalSources = sourcesToUse.length;

      const bookViewModel = viewModelManager.getBookViewModel();
      
      const progressCallback = (progress: SearchProgress): void => {
        if (this.isComponentActive) {
          this.completedSources = progress.completedSources;
          this.foundBooksCount = progress.foundBooks;
          this.searchProgress = `正在搜索 ${progress.currentSource}...`;
        }
      };

      const bookFoundCallback = (newBooks: Book[], _progress: SearchProgress): void => {
        if (this.isComponentActive && page === 1) {
          for (const book of newBooks) {
            const exists = this.searchResults.some(b => {
              if (b.bookSourceId && book.bookSourceId) {
                return b.name === book.name && 
                       (b.author || '') === (book.author || '') && 
                       b.bookSourceId === book.bookSourceId;
              }
              if (b.bookUrl && book.bookUrl) {
                return b.bookUrl === book.bookUrl;
              }
              return b.name === book.name && (b.author || '') === (book.author || '');
            });
            if (!exists) {
              this.searchResults = this.addBookToArray(this.searchResults, book);
            }
          }
          this.foundBooksCount = this.searchResults.length;
        }
      };

      const result: PagedSearchResult = await bookViewModel.searchBooksWithPaging(
        this.searchText.trim(),
        sourcesToUse,
        page,
        progressCallback,
        bookFoundCallback
      );

      if (this.isComponentActive) {
        if (page === 1) {
          this.searchResults = result.books;
        } else {
          this.searchResults = this.mergeBookArrays(this.searchResults, result.books);
        }
        this.currentPage = result.currentPage;
        this.totalPages = result.totalPages;
        this.totalCount = result.totalCount;
        this.hasMore = result.hasMore;

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
        
        if (this.searchResults.length >= 50) {
          this.validateBooksSources();
        }
      }
    }
  }

  private async validateBooksSources(): Promise<void> {
    if (this.isValidating || this.searchResults.length === 0) return;

    this.isValidating = true;
    this.validationProgress = '正在验证书源...';

    try {
      await sourceValidatorService.loadSourceCache();

      const progressCallback = (progress: BatchValidationProgress): void => {
        if (this.isComponentActive) {
          this.validationProgress = `验证中 ${progress.completed}/${progress.total} (${progress.validCount} 有效)`;
        }
      };

      const statusUpdateCallback = (bookId: string, status: SourceStatus): void => {
        if (this.isComponentActive) {
          const index = this.searchResults.findIndex(b => b.id === bookId);
          if (index >= 0) {
            this.searchResults[index] = this.updateBookStatus(this.searchResults[index], status);
          }
        }
      };

      await sourceValidatorService.validateBooksBatch(
        this.searchResults,
        progressCallback,
        statusUpdateCallback
      );

      this.allSearchResults = this.cloneBookArray(this.searchResults);
      
      const grouped = sourceValidatorService.getBooksGroupedByStatus(this.searchResults);
      this.validBooksCount = grouped.valid.length;
      this.invalidBooksCount = grouped.invalid.length;

      this.applyFilter();

    } catch (error) {
      Logger.error('SearchPage', `书源验证失败: ${error}`);
    } finally {
      this.isValidating = false;
      this.validationProgress = '';
    }
  }

  private applyFilter(): void {
    if (this.showInvalidBooks) {
      this.searchResults = [...this.allSearchResults];
    } else {
      this.searchResults = this.allSearchResults.filter(
        book => book.sourceStatus !== SourceStatus.INVALID
      );
    }
  }

  private toggleFilter(): void {
    this.showInvalidBooks = !this.showInvalidBooks;
    this.applyFilter();
  }

  private async loadNextPage(): Promise<void> {
    if (!this.hasMore || this.isSearching) return;
    await this.performSearch(this.currentPage + 1);
  }

  private async loadPreviousPage(): Promise<void> {
    if (this.currentPage <= 1 || this.isSearching) return;
    await this.performSearch(this.currentPage - 1);
  }

  private async addToBookshelf(book: Book): Promise<void> {
    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      
      if (!book.id) {
        book.id = `book_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      }
      if (!book.addTime) book.addTime = Date.now();
      if (!book.lastUpdateTime) book.lastUpdateTime = Date.now();
      if (!book.readProgress) book.readProgress = 0;
      
      const bookId = await bookViewModel.addBook(book);
      Logger.info('SearchPage', `已添加到书架，ID: ${bookId}`);
    } catch (error) {
      Logger.error('SearchPage', `添加到书架失败: ${error}`);
    }
  }

  private async openBook(book: Book): Promise<void> {
    try {
      await this.addToBookshelf(book);
      NavigationManager.getInstance().navigateTo('BookDetailPage', { bookId: book.id });
    } catch (error) {
      Logger.error('SearchPage', `打开书籍失败: ${error}`);
    }
  }

  private navigateToSourcePage(): void {
    NavigationManager.getInstance().navigateTo('MainPage', { tabIndex: 3 });
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
      this.buildHeader()
      
      Scroll() {
        Column() {
          this.buildSearchBar()
          
          if (this.isSearching) {
            this.buildSearchingState()
          }
          
          if (this.isValidating) {
            this.buildValidationState()
          }
          
          if (this.hasSearched && !this.isSearching && !this.isValidating) {
            if (this.errorMessage) {
              this.buildErrorState()
            } else if (this.searchResults.length > 0) {
              this.buildResultsSection()
            }
          }
          
          if (!this.hasSearched) {
            this.buildInitialContent()
          }
        }
        .width('100%')
        .padding(DesignSystem.Spacing.lg)
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

  @Builder
  buildHeader() {
    Row() {
      Row() {
        Text('‹')
          .fontSize(DesignSystem.Typography.size.xl)
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
        NavigationManager.getInstance().navigateBack();
      })

      Text($r('app.string.search_books'))
        .fontSize(DesignSystem.Typography.size.xl)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.bold)
        .layoutWeight(1)
        .margin({ left: DesignSystem.Spacing.md })
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
  buildSearchBar() {
    Row() {
      Text('🔍')
        .fontSize(DesignSystem.IconSize.md)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ right: DesignSystem.Spacing.sm })

      TextInput({ placeholder: $r('app.string.search_placeholder'), text: this.searchText })
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontSize(DesignSystem.Typography.size.sm)
        .placeholderColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
        .onChange((value: string) => {
          this.searchText = value;
        })
        .onSubmit(() => {
          this.performSearch();
        })

      Row() {
        Text($r('app.string.search_button'))
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor('#FFFFFF')
          .fontWeight(DesignSystem.Typography.weight.medium)
      }
      .padding({
        left: DesignSystem.Spacing.md,
        right: DesignSystem.Spacing.md,
        top: DesignSystem.Spacing.sm,
        bottom: DesignSystem.Spacing.sm
      })
      .borderRadius(DesignSystem.BorderRadius.md)
      .backgroundColor(this.isSearching ? 
        DesignSystem.getBorderColor(this.isLightMode) : 
        DesignSystem.getPrimaryColor(this.isLightMode))
      .opacity(this.isSearching ? 0.6 : 1)
      .onClick(() => {
        if (!this.isSearching) {
          this.performSearch(1);
        }
      })
    }
    .width('100%')
    .padding(DesignSystem.Spacing.md)
    .borderRadius(DesignSystem.BorderRadius.lg)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .shadow({
      radius: 4,
      color: this.isLightMode ? 'rgba(0,0,0,0.03)' : 'rgba(0,0,0,0.15)',
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  buildSearchingState() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color(DesignSystem.getPrimaryColor(this.isLightMode))
      
      Text(this.searchProgress || '正在搜索...')
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ top: DesignSystem.Spacing.md })
      
      if (this.totalSources > 0) {
        Column() {
          Row() {
            Text(`书源进度: ${this.completedSources}/${this.totalSources}`)
              .fontSize(DesignSystem.Typography.size.xs)
              .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
            
            Blank()
            
            Text(`${Math.round(this.completedSources / this.totalSources * 100)}%`)
              .fontSize(DesignSystem.Typography.size.xs)
              .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
          }
          .width('100%')
          .margin({ top: DesignSystem.Spacing.sm })
          
          Progress({
            value: this.completedSources,
            total: this.totalSources,
            type: ProgressType.Linear
          })
            .width('100%')
            .height(4)
            .color(DesignSystem.getPrimaryColor(this.isLightMode))
            .backgroundColor(DesignSystem.getBorderColor(this.isLightMode))
        }
        .width('100%')
        .margin({ top: DesignSystem.Spacing.sm })
      }
      
      if (this.foundBooksCount > 0) {
        Row() {
          Text('📚')
            .fontSize(DesignSystem.Typography.size.sm)
          Text(` 已找到 ${this.foundBooksCount} 本书籍`)
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
        }
        .margin({ top: DesignSystem.Spacing.sm })
        .padding({
          left: DesignSystem.Spacing.md,
          right: DesignSystem.Spacing.md,
          top: DesignSystem.Spacing.xs,
          bottom: DesignSystem.Spacing.xs
        })
        .borderRadius(DesignSystem.BorderRadius.md)
        .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode) + '15')
      }
    }
    .width('100%')
    .padding(DesignSystem.Spacing.xl)
    .margin({ top: DesignSystem.Spacing.lg })
    .borderRadius(DesignSystem.BorderRadius.lg)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }

  @Builder
  buildValidationState() {
    Row() {
      LoadingProgress()
        .width(20)
        .height(20)
        .color(DesignSystem.getPrimaryColor(this.isLightMode))
      
      Text(this.validationProgress || '正在验证书源...')
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ left: DesignSystem.Spacing.sm })
    }
    .width('100%')
    .padding(DesignSystem.Spacing.md)
    .margin({ top: DesignSystem.Spacing.md })
    .borderRadius(DesignSystem.BorderRadius.md)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }

  @Builder
  buildErrorState() {
    Column() {
      Text('😔')
        .fontSize(48)
        .margin({ bottom: DesignSystem.Spacing.md })
      
      Text(this.errorMessage)
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .textAlign(TextAlign.Center)
      
      if (!this.hasEnabledSources) {
        Text('请先导入书源后再进行搜索')
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
          .margin({ top: DesignSystem.Spacing.sm })
      }
      
      Row() {
        Row() {
          Text('网络导入书源')
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor('#FFFFFF')
        }
        .padding({
          left: DesignSystem.Spacing.md,
          right: DesignSystem.Spacing.md,
          top: DesignSystem.Spacing.sm,
          bottom: DesignSystem.Spacing.sm
        })
        .borderRadius(DesignSystem.BorderRadius.md)
        .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
        .margin({ top: DesignSystem.Spacing.lg, right: DesignSystem.Spacing.sm })
        .onClick(() => {
          this.navigateToSourcePage();
        })
        
        if (this.hasEnabledSources) {
          Row() {
            Text('验证书源')
              .fontSize(DesignSystem.Typography.size.xs)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          }
          .padding({
            left: DesignSystem.Spacing.md,
            right: DesignSystem.Spacing.md,
            top: DesignSystem.Spacing.sm,
            bottom: DesignSystem.Spacing.sm
          })
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .border({
            width: 1,
            color: DesignSystem.getBorderColor(this.isLightMode)
          })
          .margin({ top: DesignSystem.Spacing.lg })
          .onClick(() => {
            this.navigateToSourcePage();
          })
        }
      }
    }
    .width('100%')
    .padding(DesignSystem.Spacing.xxl)
    .margin({ top: DesignSystem.Spacing.lg })
    .borderRadius(DesignSystem.BorderRadius.xl)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }

  @Builder
  buildResultsSection() {
    Column() {
      Row() {
        Text(`共 ${this.totalCount} 本书籍`)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        
        Blank()
        
        Text(`第 ${this.currentPage}/${this.totalPages} 页`)
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
      }
      .width('100%')
      .margin({ top: DesignSystem.Spacing.lg, bottom: DesignSystem.Spacing.sm })

      if (this.validBooksCount > 0 || this.invalidBooksCount > 0) {
        this.buildFilterBar()
      }

      this.buildResultsList()

      if (this.totalPages > 1) {
        this.buildPagination()
      }
    }
    .width('100%')
  }

  @Builder
  buildFilterBar() {
    Row() {
      Row() {
        Text('✓')
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getSuccessColor(this.isLightMode))
        Text(` ${this.validBooksCount} 有效`)
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getSuccessColor(this.isLightMode))
      }
      
      Row() {
        Text('✗')
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getErrorColor(this.isLightMode))
        Text(` ${this.invalidBooksCount} 无书源`)
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getErrorColor(this.isLightMode))
      }
      .margin({ left: DesignSystem.Spacing.md })
      
      Blank()
      
      Row() {
        Text(this.showInvalidBooks ? '显示全部' : '仅有效')
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
        Text(' ▼')
          .fontSize(8)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
      }
      .padding({
        left: DesignSystem.Spacing.sm,
        right: DesignSystem.Spacing.sm,
        top: DesignSystem.Spacing.xs,
        bottom: DesignSystem.Spacing.xs
      })
      .borderRadius(DesignSystem.BorderRadius.sm)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .onClick(() => {
        this.toggleFilter();
      })
    }
    .width('100%')
    .margin({ bottom: DesignSystem.Spacing.md })
  }

  @Builder
  buildResultsList() {
    List({ space: DesignSystem.Spacing.sm }) {
      ForEach(this.searchResults, (book: Book) => {
        ListItem() {
          this.buildBookItem(book)
        }
      }, (book: Book, index: number) => `book_${index}_${book.name}_${book.bookSourceId}_${book.sourceStatus}`)
    }
    .width('100%')
    .height(this.searchResults.length * 120 + 20)
    .cachedCount(5)
    .nestedScroll({
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
  }

  @Builder
  buildBookItem(book: Book) {
    Row() {
      Stack() {
        if (book.cover) {
          Image(book.cover)
            .width(60)
            .height(80)
            .borderRadius(DesignSystem.BorderRadius.md)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            Text('📖')
              .fontSize(24)
          }
          .width(60)
          .height(80)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .justifyContent(FlexAlign.Center)
        }
        
        if (book.sourceStatus === SourceStatus.INVALID) {
          Column() {
            Text('无书源')
              .fontSize(8)
              .fontColor('#FFFFFF')
              .fontWeight(DesignSystem.Typography.weight.medium)
          }
          .width(60)
          .height(80)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor('rgba(244, 67, 54, 0.75)')
          .justifyContent(FlexAlign.Center)
        } else if (book.sourceStatus === SourceStatus.CHECKING) {
          Column() {
            LoadingProgress()
              .width(16)
              .height(16)
              .color('#FFFFFF')
          }
          .width(60)
          .height(80)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor('rgba(158, 158, 158, 0.75)')
          .justifyContent(FlexAlign.Center)
        }
      }

      Column() {
        Row() {
          Text(book.name)
            .fontSize(DesignSystem.Typography.size.base)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .fontWeight(DesignSystem.Typography.weight.medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          
          if (book.sourceStatus === SourceStatus.VALID) {
            Text('✓')
              .fontSize(DesignSystem.Typography.size.xs)
              .fontColor(DesignSystem.getSuccessColor(this.isLightMode))
              .margin({ left: DesignSystem.Spacing.xs })
          } else if (book.sourceStatus === SourceStatus.INVALID) {
            Text('✗')
              .fontSize(DesignSystem.Typography.size.xs)
              .fontColor(DesignSystem.getErrorColor(this.isLightMode))
              .margin({ left: DesignSystem.Spacing.xs })
          }
        }
        .width('100%')

        if (book.author) {
          Text(book.author)
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ top: DesignSystem.Spacing.xs })
        }

        if (book.intro) {
          Text(purifyIntro(book.intro))
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
            .margin({ top: DesignSystem.Spacing.xs })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Row() {
          if (book.bookSourceName) {
            Text(`来源: ${book.bookSourceName}`)
              .fontSize(10)
              .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
          }
          
          if (book.sourceStatus === SourceStatus.INVALID) {
            Text(' (书源不存在)')
              .fontSize(10)
              .fontColor(DesignSystem.getErrorColor(this.isLightMode))
          }
        }
        .margin({ top: DesignSystem.Spacing.xs })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: DesignSystem.Spacing.md })

      Row() {
        Text(book.sourceStatus === SourceStatus.INVALID ? '不可用' : '加入书架')
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(book.sourceStatus === SourceStatus.INVALID ? 
            DesignSystem.getTertiaryTextColor(this.isLightMode) : '#FFFFFF')
      }
      .padding({
        left: DesignSystem.Spacing.sm,
        right: DesignSystem.Spacing.sm,
        top: DesignSystem.Spacing.xs,
        bottom: DesignSystem.Spacing.xs
      })
      .borderRadius(DesignSystem.BorderRadius.md)
      .backgroundColor(book.sourceStatus === SourceStatus.INVALID ? 
        DesignSystem.getBorderColor(this.isLightMode) : 
        DesignSystem.getPrimaryColor(this.isLightMode))
      .opacity(book.sourceStatus === SourceStatus.INVALID ? 0.6 : 1)
      .onClick(() => {
        if (book.sourceStatus !== SourceStatus.INVALID) {
          this.addToBookshelf(book);
        }
      })
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
    .opacity(book.sourceStatus === SourceStatus.INVALID ? 0.7 : 1)
    .scale({
      x: this.pressedBookId === book.id ? 0.98 : 1,
      y: this.pressedBookId === book.id ? 0.98 : 1
    })
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      if (book.sourceStatus !== SourceStatus.INVALID) {
        this.openBook(book);
      }
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedBookId = book.id || '';
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedBookId = '';
      }
    })
  }

  @Builder
  buildPagination() {
    Row() {
      Row() {
        Text('上一页')
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(this.currentPage > 1 ? '#FFFFFF' : DesignSystem.getTertiaryTextColor(this.isLightMode))
      }
      .padding({
        left: DesignSystem.Spacing.md,
        right: DesignSystem.Spacing.md,
        top: DesignSystem.Spacing.sm,
        bottom: DesignSystem.Spacing.sm
      })
      .borderRadius(DesignSystem.BorderRadius.md)
      .backgroundColor(this.currentPage > 1 ? 
        DesignSystem.getPrimaryColor(this.isLightMode) : 
        DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .opacity(this.currentPage > 1 ? 1 : 0.5)
      .onClick(() => {
        this.loadPreviousPage();
      })

      Text(`${this.currentPage} / ${this.totalPages}`)
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .margin({ left: DesignSystem.Spacing.lg, right: DesignSystem.Spacing.lg })

      Row() {
        Text('下一页')
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(this.hasMore ? '#FFFFFF' : DesignSystem.getTertiaryTextColor(this.isLightMode))
      }
      .padding({
        left: DesignSystem.Spacing.md,
        right: DesignSystem.Spacing.md,
        top: DesignSystem.Spacing.sm,
        bottom: DesignSystem.Spacing.sm
      })
      .borderRadius(DesignSystem.BorderRadius.md)
      .backgroundColor(this.hasMore ? 
        DesignSystem.getPrimaryColor(this.isLightMode) : 
        DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .opacity(this.hasMore ? 1 : 0.5)
      .onClick(() => {
        this.loadNextPage();
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: DesignSystem.Spacing.lg, bottom: DesignSystem.Spacing.lg })
  }

  @Builder
  buildInitialContent() {
    Column() {
      if (!this.hasEnabledSources) {
        this.buildNoSourceState()
      }

      if (this.searchHistory.length > 0) {
        this.buildSearchHistory()
      }

      this.buildHotSearch()
    }
    .width('100%')
    .margin({ top: DesignSystem.Spacing.lg })
  }

  @Builder
  buildNoSourceState() {
    Column() {
      Text('📚')
        .fontSize(48)
        .margin({ bottom: DesignSystem.Spacing.md })
      
      Text('暂无可用书源')
        .fontSize(DesignSystem.Typography.size.base)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.medium)
        .margin({ bottom: DesignSystem.Spacing.xs })
      
      Text('请先导入书源后再进行搜索')
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ bottom: DesignSystem.Spacing.md })
      
      Row() {
        Text('去导入书源')
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor('#FFFFFF')
      }
      .padding({
        left: DesignSystem.Spacing.lg,
        right: DesignSystem.Spacing.lg,
        top: DesignSystem.Spacing.sm,
        bottom: DesignSystem.Spacing.sm
      })
      .borderRadius(DesignSystem.BorderRadius.md)
      .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
      .onClick(() => {
        this.navigateToSourcePage();
      })
    }
    .width('100%')
    .padding(DesignSystem.Spacing.xxl)
    .borderRadius(DesignSystem.BorderRadius.xl)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .margin({ bottom: DesignSystem.Spacing.lg })
  }

  @Builder
  buildSearchHistory() {
    Column() {
      Row() {
        Text($r('app.string.search_history'))
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.medium)

        Blank()

        Text($r('app.string.clear_history'))
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
          .onClick(() => {
            this.clearSearchHistory();
          })
      }
      .width('100%')
      .margin({ bottom: DesignSystem.Spacing.sm })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.searchHistory, (item: string) => {
          Row() {
            Text(item)
              .fontSize(DesignSystem.Typography.size.xs)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          }
          .padding({
            left: DesignSystem.Spacing.md,
            right: DesignSystem.Spacing.md,
            top: DesignSystem.Spacing.xs,
            bottom: DesignSystem.Spacing.xs
          })
          .borderRadius(DesignSystem.BorderRadius.lg)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .border({
            width: 1,
            color: DesignSystem.getBorderColor(this.isLightMode)
          })
          .margin({ right: DesignSystem.Spacing.sm, bottom: DesignSystem.Spacing.sm })
          .onClick(() => {
            this.searchText = item;
            this.performSearch(1);
          })
        })
      }
    }
    .width('100%')
    .margin({ bottom: DesignSystem.Spacing.xl })
  }

  @Builder
  buildHotSearch() {
    Column() {
      Text($r('app.string.hot_search'))
        .width('100%')
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.medium)
        .margin({ bottom: DesignSystem.Spacing.sm })

      Column({ space: DesignSystem.Spacing.sm }) {
        ForEach(this.hotSearchList, (item: string, index: number) => {
          Row() {
            Row() {
              Text((index + 1).toString())
                .fontSize(DesignSystem.Typography.size.xs)
                .fontColor('#FFFFFF')
                .fontWeight(DesignSystem.Typography.weight.bold)
            }
            .width(24)
            .height(24)
            .borderRadius(DesignSystem.BorderRadius.md)
            .backgroundColor(this.getRankColor(index))
            .justifyContent(FlexAlign.Center)
            .margin({ right: DesignSystem.Spacing.md })

            Text(item)
              .fontSize(DesignSystem.Typography.size.sm)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            
            Blank()
            
            Text('›')
              .fontSize(DesignSystem.Typography.size.lg)
              .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
          }
          .width('100%')
          .padding(DesignSystem.Spacing.sm)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .onClick(() => {
            this.searchText = item;
            this.performSearch(1);
          })
        })
      }
    }
    .width('100%')
  }

  private getRankColor(index: number): string {
    const rankColors: RankColor[] = [
      { light: '#8B6914', dark: '#d4b483' },
      { light: '#a68b2d', dark: '#c4a35a' },
      { light: '#c4a35a', dark: '#b5a070' }
    ];
    const color = rankColors[index] || rankColors[2];
    return this.isLightMode ? color.light : color.dark;
  }
}
