import { Book } from '../models/Book';
import { Chapter } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { ReadConfig } from '../models/ReadConfig';
import { ReadConfigViewModel } from '../viewmodel/ReadConfigViewModel';
import { ChapterViewModel } from '../viewmodel/ChapterViewModel';
import { BookViewModel } from '../viewmodel/BookViewModel';
import { ThemeManager } from '../styles/ThemeManager';
import { AppTheme, AppColors, AppTypography } from '../styles/Theme';

/**
 * 阅读器页面 - 重构版本
 * 集成主题系统，协调阅读配置与主题系统
 */
@Entry
@Component
export struct ReaderPage {
  private readConfigViewModel: ReadConfigViewModel = new ReadConfigViewModel();
  private chapterViewModel: ChapterViewModel = new ChapterViewModel();
  private bookViewModel: BookViewModel = new BookViewModel();
  private themeManager: ThemeManager = ThemeManager.getInstance();

  @State book: Book | null = null;
  @State bookSource: BookSource | null = null;
  @State chapters: Chapter[] = [];
  @State currentChapterIndex: number = 0;
  @State chapterContent: string = '';
  @State isLoading: boolean = true;
  @State readConfig: ReadConfig | null = null;
  @State showMenu: boolean = false;
  @State showSettings: boolean = false;
  @State pageOffset: number = 0; // 用于翻页动画
  @State currentTheme: AppTheme = this.themeManager.currentTheme;

  aboutToAppear(): void {
    // 注册主题变更监听
    this.themeManager.onThemeChange((theme: AppTheme) => {
      this.currentTheme = theme;
      // 当主题变化时，更新阅读配置的配色
      this.updateReadConfigTheme();
    });
    // TODO: 从路由参数获取书籍信息
    this.initReader();
  }

  aboutToDisappear(): void {
    // 清理主题监听
    this.themeManager.offThemeChange(() => {});
  }

  /**
   * 根据主题更新阅读配置的配色
   */
  private updateReadConfigTheme(): void {
    if (this.readConfig) {
      // 根据当前主题更新阅读配置的配色
      this.readConfig.backgroundColor = this.currentTheme.backgroundColor;
      this.readConfig.textColor = this.currentTheme.textPrimary;
      
      // 如果是夜间模式，使用更柔和的配色
      if (this.readConfig.isNightMode) {
        this.readConfig.backgroundColor = this.currentTheme.type === 'dark' 
          ? '#0A0A0A' 
          : '#F5F5F5';
        this.readConfig.textColor = this.currentTheme.type === 'dark' 
          ? '#CCCCCC' 
          : '#666666';
      }
    }
  }

  /**
   * 初始化阅读器
   */
  async initReader(): Promise<void> {
    this.isLoading = true;
    try {
      // 加载阅读配置
      this.readConfig = await this.readConfigViewModel.loadReadConfig();
      
      // 应用当前主题到阅读配置
      this.updateReadConfigTheme();
      
      // TODO: 从路由参数获取书籍ID
      // const bookId = router.getParams()?.bookId;
      // if (bookId) {
      //   this.book = await this.bookViewModel.getBookById(bookId);
      //   if (this.book) {
      //     await this.loadChapterList();
      //   }
      // }
    } catch (error) {
      console.error('Failed to init reader:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 加载章节列表
   */
  async loadChapterList(): Promise<void> {
    if (this.book === null) {
      return;
    }

    try {
      // 先从数据库加载
      this.chapters = await this.chapterViewModel.getChapters(this.book.id);
      
      // 如果没有章节，从网络获取
      if (this.chapters.length === 0 && this.bookSource) {
        this.chapters = await this.chapterViewModel.fetchAndSaveChapters(
          this.book.id,
          this.bookSource,
          this.book.bookUrl
        );
      }
      
      // 如果有章节，加载第一章
      if (this.chapters.length > 0) {
        await this.loadChapterContent(0);
      }
    } catch (error) {
      console.error('Failed to load chapter list:', error);
    }
  }

  /**
   * 加载章节内容
   */
  async loadChapterContent(chapterIndex: number): Promise<void> {
    if (this.chapters.length === 0 || this.book === null || !this.bookSource) {
      return;
    }

    this.isLoading = true;
    try {
      const chapter = this.chapters[chapterIndex];
      const content = await this.chapterViewModel.getChapterContent(
        chapter.id,
        chapter.url,
        this.bookSource
      );
      
      this.chapterContent = content.content;
      this.currentChapterIndex = chapterIndex;
      
      // 更新阅读进度
      const progress = Math.round(((chapterIndex + 1) / this.chapters.length) * 100);
      await this.bookViewModel.updateReadProgress(
        this.book.id,
        progress,
        chapter.title
      );
    } catch (error) {
      console.error('Failed to load chapter content:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 上一章
   */
  goToPrevChapter(): void {
    if (this.currentChapterIndex > 0) {
      this.loadChapterContent(this.currentChapterIndex - 1);
    }
  }

  /**
   * 下一章
   */
  goToNextChapter(): void {
    if (this.currentChapterIndex < this.chapters.length - 1) {
      this.loadChapterContent(this.currentChapterIndex + 1);
    }
  }

  build() {
    Stack() {
      if (this.readConfig && this.chapterContent) {
        // 阅读内容区域 - 支持手势翻页
        Stack() {
          Scroll() {
            Column() {
              Text(this.chapters[this.currentChapterIndex]?.title || '')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.readConfig.textColor)
                .margin({ bottom: 16 })
                .width('100%')

              Text(this.chapterContent)
                .fontSize(this.readConfig.fontSize)
                .lineHeight(this.readConfig.fontSize * this.readConfig.lineSpacing)
                .fontColor(this.readConfig.textColor)
                .fontFamily(this.readConfig.fontFamily)
                .width('100%')
            }
            .width('100%')
            .padding({
              top: this.readConfig.margins.top,
              bottom: this.readConfig.margins.bottom,
              left: this.readConfig.margins.left,
              right: this.readConfig.margins.right
            })
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .backgroundColor(this.readConfig.backgroundColor)
          .gesture(
            GestureGroup(GestureMode.Parallel,
              // 点击显示/隐藏菜单
              TapGesture()
                .onAction(() => {
                  this.showMenu = !this.showMenu;
                }),
              // 左右滑动翻页
              PanGesture({ direction: PanDirection.Horizontal, distance: 30 })
                .onActionEnd((event: GestureEvent) => {
                  if (event.offsetX < -50) {
                    // 左滑 - 下一章
                    this.goToNextChapter();
                  } else if (event.offsetX > 50) {
                    // 右滑 - 上一章
                    this.goToPrevChapter();
                  }
                })
            )
          )
          .opacity(this.showMenu ? 0.95 : 1)
          .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        }

        // 菜单栏
        if (this.showMenu) {
          Column() {
            // 顶部菜单
            Row() {
              Text('←')
                .fontSize(24)
                .fontColor(this.currentTheme.textPrimary)
                .onClick(() => {
                  // TODO: 返回上一页
                })

              Text(this.book?.name || '')
                .layoutWeight(1)
                .fontSize(16)
                .fontColor(this.currentTheme.textPrimary)
                .margin({ left: 16 })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text('⚙')
                .fontSize(20)
                .fontColor(this.currentTheme.textPrimary)
                .onClick(() => {
                  // TODO: 显示设置菜单
                })
            }
            .width('100%')
            .height(56)
            .padding(16)
            .justifyContent(FlexAlign.SpaceBetween)
            .backgroundColor(this.currentTheme.surfaceColor)

            // 底部菜单
            Row() {
              Button('上一章')
                .type(ButtonType.Normal)
                .enabled(this.currentChapterIndex > 0)
                .backgroundColor(AppColors.PRIMARY)
                .fontColor('#FFFFFF')
                .onClick(() => {
                  this.goToPrevChapter();
                })

              Text(`${this.currentChapterIndex + 1}/${this.chapters.length}`)
                .fontSize(14)
                .fontColor(this.currentTheme.textPrimary)
                .margin({ left: 16, right: 16 })

              Button('下一章')
                .type(ButtonType.Normal)
                .enabled(this.currentChapterIndex < this.chapters.length - 1)
                .backgroundColor(AppColors.PRIMARY)
                .fontColor('#FFFFFF')
                .onClick(() => {
                  this.goToNextChapter();
                })
            }
            .width('100%')
            .height(56)
            .padding(16)
            .justifyContent(FlexAlign.SpaceBetween)
            .backgroundColor(this.currentTheme.surfaceColor)
          }
          .width('100%')
          .backgroundColor('rgba(0, 0, 0, 0.7)')
          .position({ x: 0, y: 0 })
        }
      } else if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(AppColors.PRIMARY)
          Text('加载中...')
            .margin({ top: 16 })
            .fontSize(AppTypography.CAPTION.size)
            .fontWeight(AppTypography.CAPTION.weight)
            .fontColor(this.currentTheme.textTertiary)
            .lineHeight(AppTypography.CAPTION.lineHeight)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.currentTheme.backgroundColor)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentTheme.backgroundColor)
  }
}