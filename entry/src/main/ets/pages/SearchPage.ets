import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { BookViewModel } from '../viewmodel/BookViewModel';
import { BookSourceViewModel } from '../viewmodel/BookSourceViewModel';
import { debounce } from '../utils/PerformanceOptimizer';
import { IdGenerator } from '../utils/IdGenerator';
import { ThemeManager } from '../styles/ThemeManager';
import { AppTheme } from '../styles/Theme';
import { 
  primaryButton, 
  secondaryButton, 
  textButton, 
  cardStyle, 
  surfaceCard,
  titleText,
  subtitleText,
  bodyText,
  captionText,
  responsiveRow,
  inputField
} from '../styles/ComponentStyles';
import { ResponsiveUtils } from '../styles/ResponsiveUtils';

/**
 * 搜索页面 - 重构版本
 * 集成主题系统，使用统一的样式组件
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
      return;
    }

    this.isSearching = true;
    try {
      // 确保书源已加载
      if (this.bookSources.length === 0) {
        await this.loadBookSources();
      }
      
      this.searchResults = await this.bookViewModel.searchBooks(keyword, this.bookSources);
    } catch (error) {
      console.error('Search error:', error);
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
            radius: this.currentTheme.shadows.MD.radius,
            color: this.currentTheme.shadows.MD.color,
            offsetX: this.currentTheme.shadows.MD.offsetX,
            offsetY: this.currentTheme.shadows.MD.offsetY
          })
          .onChange((value: string) => {
            this.searchKeyword = value;
            if (value.trim() !== '') {
              this.performSearch();
            } else {
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
          .backgroundColor(this.currentTheme.colors.PRIMARY)
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
      .responsiveRow()
      .padding(20)
      .backgroundColor(this.currentTheme.surfaceColor)
      .shadow({
        radius: this.currentTheme.shadows.SM.radius,
        color: this.currentTheme.shadows.SM.color,
        offsetX: this.currentTheme.shadows.SM.offsetX,
        offsetY: this.currentTheme.shadows.SM.offsetY
      })

      // 搜索结果
      if (this.isSearching) {
        Column() {
          LoadingProgress()
            .width(56)
            .height(56)
            .color(this.currentTheme.colors.PRIMARY)
          Text('搜索中...')
            .margin({ top: 24 })
            .bodyText()
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.searchResults.length === 0 && this.searchKeyword !== '') {
        Column() {
          Image('https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=search%20not%20found%20illustration%2C%20minimal%20style%2C%20modern%20design&image_size=square')
            .width(160)
            .height(160)
            .margin({ bottom: 24 })
            .animation({
              duration: 500,
              curve: Curve.EaseOut
            })
          Text('未找到相关书籍')
            .subtitleText()
            .fontWeight(FontWeight.Bold)
            .animation({
              duration: 300,
              curve: Curve.EaseOut,
              delay: 100
            })
          Text('请尝试其他关键词')
            .margin({ top: 12 })
            .captionText()
            .animation({
              duration: 300,
              curve: Curve.EaseOut,
              delay: 200
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.searchResults.length > 0) {
        Grid() {
          ForEach(this.searchResults, (book: Book) => {
            GridItem() {
              Stack() {
                Column() {
                  // 封面
                  Image(book.cover)
                    .width('100%')
                    .height(180)
                    .borderRadius(12)
                    .objectFit(ImageFit.Cover)
                    .backgroundColor(this.currentTheme.surfaceColor)
                    .shadow({
                      radius: this.currentTheme.shadows.LG.radius,
                      color: this.currentTheme.shadows.LG.color,
                      offsetX: this.currentTheme.shadows.LG.offsetX,
                      offsetY: this.currentTheme.shadows.LG.offsetY
                    })

                  // 书名
                  Text(book.name)
                    .width('100%')
                    .margin({ top: 16 })
                    .bodyText()
                    .fontWeight(FontWeight.Medium)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  // 作者
                  Text(book.author || '未知作者')
                    .width('100%')
                    .margin({ top: 6 })
                    .captionText()
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  // 简介（如果有）
                  if (book.intro) {
                    Text(book.intro)
                      .width('100%')
                      .margin({ top: 8 })
                      .fontSize(12)
                      .fontColor(this.currentTheme.textTertiary)
                      .lineHeight(16)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }

                  // 加入书架按钮
                  Button('加入书架')
                    .primaryButton()
                    .margin({ top: 12 })
                    .onClick(() => {
                      this.addBookToShelf(book);
                    })
                }
                .width('100%')
                .padding(16)
                .cardStyle()
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
      } else {
        // 初始状态
        Column() {
          Image('https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=book%20search%20illustration%2C%20minimal%20style%2C%20modern%20design&image_size=square')
            .width(200)
            .height(200)
            .margin({ bottom: 32 })
            .animation({
              duration: 500,
              curve: Curve.EaseOut
            })
          Text('搜索书籍')
            .titleText()
            .fontWeight(FontWeight.Bold)
            .animation({
              duration: 300,
              curve: Curve.EaseOut,
              delay: 100
            })
          Text('输入书名或作者开始搜索')
            .margin({ top: 12 })
            .bodyText()
            .animation({
              duration: 300,
              curve: Curve.EaseOut,
              delay: 200
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentTheme.backgroundColor)
  }
}