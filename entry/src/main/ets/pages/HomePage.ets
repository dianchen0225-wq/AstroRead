import { Book } from '../models/Book';
import { BookViewModel } from '../viewmodel/BookViewModel';
import { CategoryViewModel } from '../viewmodel/CategoryViewModel';
import { BookCategory } from '../models/BookCategory';
import { ThemeManager } from '../styles/ThemeManager';
import { AppTheme } from '../styles/Theme';
import { ResponsiveUtils } from '../styles/ResponsiveUtils';

/**
 * 主页 - 书架页面
 * 重构版本：集成主题系统，优化样式和性能
 */
@Component
export struct HomePage {
  private bookViewModel: BookViewModel = new BookViewModel();
  private categoryViewModel: CategoryViewModel = new CategoryViewModel();
  private themeManager: ThemeManager = ThemeManager.getInstance();
  
  @State books: Book[] = [];
  @State filteredBooks: Book[] = [];
  @State categories: BookCategory[] = [];
  @State selectedCategory: string = 'all';
  @State selectedBooks: Set<string> = new Set();
  @State isLoading: boolean = true;
  @State viewMode: 'list' | 'grid' = 'grid';
  @State sortType: 'name' | 'author' | 'progress' | 'time' = 'time';
  @State isEditMode: boolean = false;
  @State showCategoryDialog: boolean = false;
  @State currentTheme: AppTheme = this.themeManager.currentTheme;

  aboutToAppear(): void {
    // 注册主题变更监听
    this.themeManager.onThemeChange((theme: AppTheme) => {
      this.currentTheme = theme;
    });
    this.loadData();
  }

  aboutToDisappear(): void {
    // 清理主题监听
    this.themeManager.offThemeChange(() => {});
  }

  /**
   * 加载数据
   */
  async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      await Promise.all([
        this.loadBooks(),
        this.loadCategories()
      ]);
    } catch (error) {
      console.error('Failed to load data:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 加载书籍列表 - 使用 ViewModel
   */
  async loadBooks(): Promise<void> {
    try {
      this.books = await this.bookViewModel.loadAllBooks();
      this.applyFilters();
    } catch (error) {
      console.error('Failed to load books:', error);
    }
  }

  /**
   * 加载分类列表
   */
  async loadCategories(): Promise<void> {
    try {
      this.categories = await this.categoryViewModel.getAllCategories();
    } catch (error) {
      console.error('Failed to load categories:', error);
    }
  }

  /**
   * 应用筛选和排序
   */
  async applyFilters(): Promise<void> {
    let filtered = [...this.books];
    
    // 按分类筛选
    if (this.selectedCategory !== 'all') {
      const categoryBooks = await this.bookViewModel.getBooksByCategory(this.selectedCategory);
      filtered = categoryBooks;
    }
    
    // 排序
    filtered = await this.bookViewModel.sortBooks(filtered, this.sortType);
    
    this.filteredBooks = filtered;
  }

  /**
   * 切换选择状态
   */
  toggleSelect(bookId: string): void {
    if (this.selectedBooks.has(bookId)) {
      this.selectedBooks.delete(bookId);
    } else {
      this.selectedBooks.add(bookId);
    }
  }

  /**
   * 全选/取消全选
   */
  toggleSelectAll(): void {
    if (this.selectedBooks.size === this.filteredBooks.length) {
      this.selectedBooks.clear();
    } else {
      this.selectedBooks = new Set(this.filteredBooks.map((b: Book) => b.id));
    }
  }

  /**
   * 批量删除
   */
  async batchDelete(): Promise<void> {
    if (this.selectedBooks.size === 0) {
      return;
    }

    try {
      await this.bookViewModel.batchDeleteBooks(Array.from(this.selectedBooks));
      this.selectedBooks.clear();
      this.isEditMode = false;
      await this.loadBooks();
    } catch (error) {
      console.error('Failed to delete books:', error);
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        if (this.isEditMode) {
          Text(`${this.selectedBooks.size} 已选择`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.currentTheme.textSecondary)
          
          Button('取消')
            .backgroundColor('transparent')
            .fontColor(this.currentTheme.colors.PRIMARY)
            .fontSize(14)
            .margin({ left: 16 })
            .onClick(() => {
              this.isEditMode = false;
              this.selectedBooks.clear();
            })
        } else {
          Text('我的书架')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.currentTheme.textPrimary)

          Blank()

          Row() {
            // 视图切换
            Button(this.viewMode === 'grid' ? '☰' : '⊞')
              .backgroundColor('transparent')
              .fontColor(this.currentTheme.colors.PRIMARY)
              .fontSize(20)
              .margin({ right: 20 })
              .onClick(() => {
                this.viewMode = this.viewMode === 'grid' ? 'list' : 'grid';
              })

            // 编辑按钮
            Button('编辑')
              .backgroundColor('transparent')
              .fontColor(this.currentTheme.colors.PRIMARY)
              .fontSize(14)
              .onClick(() => {
                this.isEditMode = true;
              })
          }
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .height(64)
      .backgroundColor(this.currentTheme.surfaceColor)
      .shadow({
        radius: this.currentTheme.shadows.SM.radius,
        color: this.currentTheme.shadows.SM.color,
        offsetX: this.currentTheme.shadows.SM.offsetX,
        offsetY: this.currentTheme.shadows.SM.offsetY
      })

      // 筛选和排序栏
      Row() {
        // 分类筛选
        Button() {
          Row() {
            Text(this.selectedCategory === 'all' ? '全部' : 
                 this.categories.find(c => c.id === this.selectedCategory)?.name || '全部')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.currentTheme.textPrimary)
            Text('▼')
              .fontSize(10)
              .fontColor(this.currentTheme.textTertiary)
              .margin({ left: 6 })
          }
          .alignItems(VerticalAlign.Center)
          .padding({ left: 16, right: 16 })
        }
        .width(110)
        .height(36)
        .backgroundColor(this.currentTheme.surfaceColor)
        .borderRadius(18)
        .onClick(() => {
          // TODO: 显示分类选择对话框
        })

        Blank()

        // 排序
        Button() {
          Row() {
            Text(this.getSortTypeText())
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.currentTheme.textPrimary)
            Text('▼')
              .fontSize(10)
              .fontColor(this.currentTheme.textTertiary)
              .margin({ left: 6 })
          }
          .alignItems(VerticalAlign.Center)
          .padding({ left: 16, right: 16 })
        }
        .width(110)
        .height(36)
        .backgroundColor(this.currentTheme.surfaceColor)
        .borderRadius(18)
        .onClick(() => {
          // TODO: 显示排序选择对话框
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .padding({ top: 12, bottom: 12 })
      .backgroundColor(this.currentTheme.surfaceColor)
      .shadow({
        radius: 2,
        color: 'rgba(0, 0, 0, 0.05)',
        offsetX: 0,
        offsetY: 1
      })

      // 书籍列表
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(this.currentTheme.colors.PRIMARY)
          Text('加载中...')
            .margin({ top: 20 })
            .fontSize(14)
            .fontColor(this.currentTheme.textTertiary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.books.length === 0) {
        Column() {
          Image('https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=empty%20bookshelf%20illustration%2C%20minimal%20style%2C%20modern%20design&image_size=square')
            .width(160)
            .height(160)
            .margin({ bottom: 24 })
          Text('暂无书籍')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.currentTheme.textSecondary)
          Text('点击搜索添加书籍')
            .margin({ top: 12 })
            .fontSize(14)
            .fontColor(this.currentTheme.textTertiary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        if (this.viewMode === 'grid') {
          Grid() {
            ForEach(this.filteredBooks, (book: Book) => {
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
                        radius: 6,
                        color: this.currentTheme.shadows.LG.color,
                        offsetX: 0,
                        offsetY: 4
                      })

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

                    // 阅读进度
                    if (book.readProgress > 0) {
                      Row() {
                        Progress({ value: book.readProgress, total: 100 })
                          .width('100%')
                          .height(6)
                          .margin({ top: 10 })
                          .color(this.currentTheme.colors.PRIMARY)
                          .backgroundColor(this.currentTheme.surfaceColor)
                          .borderRadius(3)
                        Text(`${book.readProgress}%`)
                          .fontSize(12)
                          .fontColor(this.currentTheme.textTertiary)
                          .margin({ left: 8, top: 10 })
                      }
                    }
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
                  .onClick(() => {
                    if (this.isEditMode) {
                      this.toggleSelect(book.id);
                    } else {
                      // TODO: 跳转到阅读页面
                    }
                  })

                  // 选择标记
                  if (this.isEditMode) {
                    Stack() {
                      Circle()
                        .width(28)
                        .height(28)
                        .fill(this.selectedBooks.has(book.id) ? this.currentTheme.colors.PRIMARY : 'transparent')
                        .stroke(this.currentTheme.colors.PRIMARY)
                        .strokeWidth(2)
                      if (this.selectedBooks.has(book.id)) {
                        Text('✓')
                          .fontSize(14)
                          .fontColor('#FFFFFF')
                          .fontWeight(FontWeight.Bold)
                      }
                    }
                    .position({ x: 16, y: 16 })
                  }
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
          List() {
            ForEach(this.filteredBooks, (book: Book) => {
              ListItem() {
                Row() {
                  // 封面
                  Image(book.cover)
                    .width(96)
                    .height(144)
                    .borderRadius(8)
                    .objectFit(ImageFit.Cover)
                    .backgroundColor(this.currentTheme.surfaceColor)
                    .shadow({
                      radius: 4,
                      color: this.currentTheme.shadows.MD.color,
                      offsetX: 0,
                      offsetY: 2
                    })

                  Column() {
                    Text(book.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.currentTheme.textSecondary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')

                    Text(book.author || '未知作者')
                      .margin({ top: 8 })
                      .fontSize(14)
                      .fontColor(this.currentTheme.textTertiary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')

                    if (book.readProgress > 0) {
                      Row() {
                        Progress({ value: book.readProgress, total: 100 })
                          .width(160)
                          .height(6)
                          .color(this.currentTheme.colors.PRIMARY)
                          .backgroundColor(this.currentTheme.surfaceColor)
                          .borderRadius(3)
                        Text(`${book.readProgress}%`)
                          .fontSize(12)
                          .fontColor(this.currentTheme.textTertiary)
                          .margin({ left: 12 })
                      }
                      .margin({ top: 12 })
                      .width('100%')
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  .margin({ left: 20 })

                  // 选择标记
                  if (this.isEditMode) {
                    Stack() {
                      Circle()
                        .width(28)
                        .height(28)
                        .fill(this.selectedBooks.has(book.id) ? this.currentTheme.colors.PRIMARY : 'transparent')
                        .stroke(this.currentTheme.colors.PRIMARY)
                        .strokeWidth(2)
                      if (this.selectedBooks.has(book.id)) {
                        Text('✓')
                          .fontSize(14)
                          .fontColor('#FFFFFF')
                          .fontWeight(FontWeight.Bold)
                      }
                    }
                    .margin({ left: 20 })
                  }
                }
                .width('100%')
                .padding(20)
                .backgroundColor(this.currentTheme.cardColor)
                .borderRadius(12)
                .shadow({ 
                  radius: 4, 
                  color: 'rgba(0, 0, 0, 0.1)',
                  offsetX: 0,
                  offsetY: 2
                })
                .margin({ bottom: 12 })
                .onClick(() => {
                  if (this.isEditMode) {
                    this.toggleSelect(book.id);
                  } else {
                    // TODO: 跳转到阅读页面
                  }
                })
              }
            }, (book: Book) => book.id)
          }
          .width('100%')
          .height('100%')
          .layoutWeight(1)
          .padding(20)
          .divider({ strokeWidth: 0, color: this.currentTheme.backgroundColor, startMargin: 0, endMargin: 0 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentTheme.backgroundColor)
  }

  /**
   * 获取排序类型文本
   */
  getSortTypeText(): string {
    const texts: Record<string, string> = {
      'name': '按书名',
      'author': '按作者',
      'progress': '按进度',
      'time': '按时间'
    };
    return texts[this.sortType] || '按时间';
  }
}