import { Book } from '../models/Book';
import { BookViewModel } from '../viewmodel/BookViewModel';
import { CategoryViewModel } from '../viewmodel/CategoryViewModel';
import { BookCategory } from '../models/BookCategory';
import { ThemeManager } from '../styles/ThemeManager';
import { AppTheme, AppColors, AppShadows } from '../styles/Theme';
import { ResponsiveUtils } from '../styles/ResponsiveUtils';

/**
 * 主页 - 书架页面（优化版本）
 * 使用本地图标资源，改进状态提示系统
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
  @State pageState: 'loading' | 'empty' | 'hasBooks' = 'loading';

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
    this.pageState = 'loading';
    try {
      await Promise.all([
        this.loadBooks(),
        this.loadCategories()
      ]);
    } catch (error) {
      console.error('Failed to load data:', error);
      this.pageState = 'empty';
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
      
      // 更新页面状态
      if (this.books.length > 0) {
        this.pageState = 'hasBooks';
      } else {
        this.pageState = 'empty';
      }
    } catch (error) {
      console.error('Failed to load books:', error);
      this.pageState = 'empty';
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

  /**
   * 构建状态指示器
   */
  @Builder
  buildStateIndicator() {
    Column() {
      if (this.pageState === 'loading') {
        this.buildLoadingState();
      } else if (this.pageState === 'empty') {
        this.buildEmptyState();
      }
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
   * 构建加载状态
   */
  @Builder
  buildLoadingState() {
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

      Text('加载中...')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTheme.textPrimary)

      Text('正在加载您的书架')
        .margin({ top: 8 })
        .fontSize(14)
        .fontColor(this.currentTheme.textTertiary)
    }
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 构建空状态
   */
  @Builder
  buildEmptyState() {
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
        
        Image($r('app.media.ic_bookshelf'))
          .width(48)
          .height(48)
          .fillColor(this.currentTheme.textTertiary)
      }
      .margin({ bottom: 32 })

      Text('暂无书籍')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTheme.textPrimary)

      Text('点击搜索添加书籍')
        .margin({ top: 8 })
        .fontSize(14)
        .fontColor(this.currentTheme.textTertiary)

      Button('去搜索')
        .margin({ top: 24 })
        .height(40)
        .padding({ left: 24, right: 24 })
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(AppColors.PRIMARY)
        .borderRadius(20)
        .onClick(() => {
          // TODO: 跳转到搜索页面
        })
    }
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 构建书籍网格视图
   */
  @Builder
  buildGridView() {
    Grid() {
      ForEach(this.filteredBooks, (book: Book) => {
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

              // 阅读进度
              if (book.readProgress > 0) {
                Row() {
                  Progress({ value: book.readProgress, total: 100 })
                    .width('100%')
                    .height(6)
                    .margin({ top: 10 })
                    .color(AppColors.PRIMARY)
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
                  .fill(this.selectedBooks.has(book.id) ? AppColors.PRIMARY : 'transparent')
                  .stroke(AppColors.PRIMARY)
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
  }

  /**
   * 构建书籍列表视图
   */
  @Builder
  buildListView() {
    List() {
      ForEach(this.filteredBooks, (book: Book) => {
        ListItem() {
          Row() {
            // 封面
            Stack() {
              if (book.cover) {
                Image(book.cover)
                  .width(96)
                  .height(144)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)
              } else {
                // 默认封面
                Column() {
                  Text(book.name.charAt(0))
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                }
                .width(96)
                .height(144)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .backgroundColor(AppColors.PRIMARY)
                .borderRadius(8)
              }
            }

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
                    .color(AppColors.PRIMARY)
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
                  .fill(this.selectedBooks.has(book.id) ? AppColors.PRIMARY : 'transparent')
                  .stroke(AppColors.PRIMARY)
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
            .fontColor(AppColors.PRIMARY)
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
              .fontColor(AppColors.PRIMARY)
              .fontSize(20)
              .margin({ right: 20 })
              .onClick(() => {
                this.viewMode = this.viewMode === 'grid' ? 'list' : 'grid';
              })

            // 编辑按钮
            Button('编辑')
              .backgroundColor('transparent')
              .fontColor(AppColors.PRIMARY)
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
        radius: AppShadows.SM.radius,
        color: AppShadows.SM.color,
        offsetX: AppShadows.SM.offsetX,
        offsetY: AppShadows.SM.offsetY
      })

      // 筛选和排序栏
      if (this.pageState === 'hasBooks') {
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
      }

      // 内容区域
      if (this.pageState === 'hasBooks') {
        if (this.viewMode === 'grid') {
          this.buildGridView()
        } else {
          this.buildListView()
        }
      } else {
        this.buildStateIndicator()
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