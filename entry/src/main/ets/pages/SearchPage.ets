import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { BookViewModel } from '../viewmodel/BookViewModel';
import { BookSourceViewModel } from '../viewmodel/BookSourceViewModel';
import { debounce } from '../utils/PerformanceOptimizer';
import { IdGenerator } from '../utils/IdGenerator';
import { ThemeManager } from '../styles/ThemeManager';
import { AppTheme, AppColors, AppShadows } from '../styles/Theme';
import { ResponsiveUtils } from '../styles/ResponsiveUtils';

/**
 * 搜索页面 - 优化版本
 * 改进状态提示区域，使用本地资源替代外部图片生成服务
 */
@Component
export struct SearchPage {
  private bookViewModel: BookViewModel = new BookViewModel();
  private bookSourceViewModel: BookSourceViewModel = new BookSourceViewModel();
  private themeManager: ThemeManager = ThemeManager.getInstance();
  
  @State searchKeyword: string = '';
  @State searchResults: Book[] = [];
  @State isSearching: boolean = false;
  @State bookSources: BookSource[] = [];
  @State currentTheme: AppTheme = this.themeManager.currentTheme;
  @State searchState: 'initial' | 'searching' | 'noResults' | 'hasResults' = 'initial';

  // 防抖搜索函数
  private debouncedSearch: (keyword: string) => void = debounce(async (...args: Array<string | number | boolean | object | null | undefined>) => {
    const keyword = args[0] as string;
    await this.performSearchInternal(keyword);
  }, 500);

  aboutToAppear(): void {
    // 注册主题变更监听
    this.themeManager.onThemeChange((theme: AppTheme) => {
      this.currentTheme = theme;
    });
    this.loadBookSources();
  }

  aboutToDisappear(): void {
    // 清理主题监听
    this.themeManager.offThemeChange(() => {});
  }

  /**
   * 加载书源列表 - 使用 ViewModel
   */
  async loadBookSources(): Promise<void> {
    try {
      this.bookSources = await this.bookSourceViewModel.loadEnabledBookSources();
    } catch (error) {
      console.error('Failed to load book sources:', error);
    }
  }

  /**
   * 执行搜索（内部方法）
   */
  private async performSearchInternal(keyword: string): Promise<void> {
    if (keyword.trim() === '') {
      this.searchState = 'initial';
      this.searchResults = [];
      return;
    }

    this.searchState = 'searching';
    this.isSearching = true;
    
    try {
      // 确保书源已加载
      if (this.bookSources.length === 0) {
        await this.loadBookSources();
      }
      
      this.searchResults = await this.bookViewModel.searchBooks(keyword, this.bookSources);
      
      // 根据搜索结果更新状态
      if (this.searchResults.length > 0) {
        this.searchState = 'hasResults';
      } else {
        this.searchState = 'noResults';
      }
    } catch (error) {
      console.error('Search error:', error);
      this.searchState = 'noResults';
    } finally {
      this.isSearching = false;
    }
  }

  /**
   * 添加书籍到书架
   */
  async addBookToShelf(book: Book): Promise<void> {
    try {
      // 确保book有正确的ID和时间戳
      if (!book.id || book.id.startsWith('book_')) {
        book.id = IdGenerator.generateUUID();
      }
      book.addTime = Date.now();
      book.lastUpdateTime = Date.now();
      
      await this.bookViewModel.addBook(book);
      // TODO: 显示成功提示
    } catch (error) {
      console.error('Failed to add book:', error);
      // TODO: 显示错误提示
    }
  }

  /**
   * 执行搜索 - 使用防抖优化
   */
  async performSearch(): Promise<void> {
    this.debouncedSearch(this.searchKeyword);
  }

  /**
   * 构建状态提示区域
   */
  @Builder
  buildStateIndicator() {
    Column() {
      if (this.searchState === 'initial') {
        this.buildInitialState();
      } else if (this.searchState === 'searching') {
        this.buildSearchingState();
      } else if (this.searchState === 'noResults') {
        this.buildNoResultsState();
      }
      // hasResults 状态不显示状态指示器
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .animation({
      duration: 300,
      curve: Curve.EaseOut
    })
  }

  /**
   * 构建初始状态
   */
  @Builder
  buildInitialState() {
    Column() {
      // 搜索图标
      Stack() {
        Circle({ width: 120, height: 120 })
          .fill(this.currentTheme.surfaceColor)
          .shadow({
            radius: AppShadows.MD.radius,
            color: AppShadows.MD.color,
            offsetX: AppShadows.MD.offsetX,
            offsetY: AppShadows.MD.offsetY
          })
        
        Image($r('app.media.ic_search'))
          .width(48)
          .height(48)
          .fillColor(AppColors.PRIMARY)
      }
      .margin({ bottom: 32 })

      Text('搜索书籍')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentTheme.textPrimary)

      Text('输入书名或作者开始搜索')
        .margin({ top: 12 })
        .fontSize(16)
        .fontColor(this.currentTheme.textTertiary)
    }
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 构建搜索中状态
   */
  @Builder
  buildSearchingState() {
    Column() {
      Stack() {
        Circle({ width: 120, height: 120 })
          .fill(this.currentTheme.surfaceColor)
          .shadow({
            radius: AppShadows.MD.radius,
            color: AppShadows.MD.color,
            offsetX: AppShadows.MD.offsetX,
            offsetY: AppShadows.MD.offsetY
          })
        
        LoadingProgress()
          .width(48)
          .height(48)
          .color(AppColors.PRIMARY)
      }
      .margin({ bottom: 32 })

      Text('搜索中...')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTheme.textPrimary)

      Text('正在为您查找相关书籍')
        .margin({ top: 8 })
        .fontSize(14)
        .fontColor(this.currentTheme.textTertiary)
    }
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 构建无结果状态
   */
  @Builder
  buildNoResultsState() {
    Column() {
      Stack() {
        Circle({ width: 120, height: 120 })
          .fill(this.currentTheme.surfaceColor)
          .shadow({
            radius: AppShadows.MD.radius,
            color: AppShadows.MD.color,
            offsetX: AppShadows.MD.offsetX,
            offsetY: AppShadows.MD.offsetY
          })
        
        Image($r('app.media.ic_no_results'))
          .width(48)
          .height(48)
          .fillColor(this.currentTheme.textTertiary)
      }
      .margin({ bottom: 32 })

      Text('未找到相关书籍')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTheme.textPrimary)

      Text('请尝试其他关键词或检查书源')
        .margin({ top: 8 })
        .fontSize(14)
        .fontColor(this.currentTheme.textTertiary)

      Button('重新搜索')
        .margin({ top: 24 })
        .height(40)
        .padding({ left: 24, right: 24 })
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(AppColors.PRIMARY)
        .borderRadius(20)
        .onClick(() => {
          this.performSearch();
        })
    }
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 构建搜索结果网格
   */
  @Builder
  buildSearchResults() {
    Grid() {
      ForEach(this.searchResults, (book: Book) => {
        GridItem() {
          Stack() {
            Column() {
              // 封面
              Stack() {
                if (book.cover) {
                  Image(book.cover)
                    .width('100%')
                    .height(180)
                    .borderRadius(12)
                    .objectFit(ImageFit.Cover)
                } else {
                  // 默认封面
                  Column() {
                    Text(book.name.charAt(0))
                      .fontSize(32)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#FFFFFF')
                  }
                  .width('100%')
                  .height(180)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                  .backgroundColor(AppColors.PRIMARY)
                  .borderRadius(12)
                }
              }

              // 书名
              Text(book.name)
                .width('100%')
                .margin({ top: 16 })
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.currentTheme.textPrimary)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              // 作者
              Text(book.author || '未知作者')
                .width('100%')
                .margin({ top: 6 })
                .fontSize(14)
                .fontColor(this.currentTheme.textTertiary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              // 书源
              Text(book.bookSourceName || '')
                .width('100%')
                .margin({ top: 4 })
                .fontSize(12)
                .fontColor(this.currentTheme.textTertiary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              // 加入书架按钮
              Button('加入书架')
                .height(36)
                .padding({ left: 16, right: 16 })
                .fontSize(14)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .backgroundColor(AppColors.PRIMARY)
                .borderRadius(18)
                .margin({ top: 12 })
                .onClick(() => {
                  this.addBookToShelf(book);
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.currentTheme.cardColor)
            .borderRadius(12)
            .shadow({
              radius: 4,
              color: 'rgba(0, 0, 0, 0.1)',
              offsetX: 0,
              offsetY: 2
            })
          }
          .width('100%')
        }
      }, (book: Book) => book.id)
    }
    .columnsTemplate(ResponsiveUtils.isTabletOrLarger() ? '1fr 1fr 1fr' : '1fr 1fr')
    .rowsGap(24)
    .columnsGap(20)
    .width('100%')
    .height('100%')
    .padding(20)
  }

  build() {
    Column() {
      // 搜索栏
      Row() {
        TextInput({ placeholder: '请输入书名或作者', text: this.searchKeyword })
          .layoutWeight(1)
          .height(48)
          .borderRadius(24)
          .backgroundColor(this.currentTheme.surfaceColor)
          .padding({ left: 20, right: 20 })
          .fontSize(16)
          .fontColor(this.currentTheme.textPrimary)
          .placeholderColor(this.currentTheme.textTertiary)
          .shadow({
            radius: AppShadows.MD.radius,
            color: AppShadows.MD.color,
            offsetX: AppShadows.MD.offsetX,
            offsetY: AppShadows.MD.offsetY
          })
          .onChange((value: string) => {
            this.searchKeyword = value;
            if (value.trim() !== '') {
              this.performSearch();
            } else {
              this.searchState = 'initial';
              this.searchResults = [];
            }
          })
          .onSubmit(() => {
            this.performSearch();
          })
          .animation({
            duration: 300,
            curve: Curve.EaseOut
          })

        Button('搜索')
          .height(48)
          .margin({ left: 12 })
          .padding({ left: 24, right: 24 })
          .fontSize(16)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
          .backgroundColor(AppColors.PRIMARY)
          .borderRadius(24)
          .enabled(!this.isSearching)
          .onClick(() => {
            this.performSearch();
          })
          .animation({
            duration: 200,
            curve: Curve.EaseOut
          })
      }
      .width('100%')
      .padding(20)
      .backgroundColor(this.currentTheme.surfaceColor)
      .shadow({
        radius: AppShadows.SM.radius,
        color: AppShadows.SM.color,
        offsetX: AppShadows.SM.offsetX,
        offsetY: AppShadows.SM.offsetY
      })

      // 内容区域
      if (this.searchState === 'hasResults') {
        this.buildSearchResults()
      } else {
        this.buildStateIndicator()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentTheme.backgroundColor)
  }
}