import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { Book } from '../models/Book';
import { Chapter, ChapterContent } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { ReadConfig } from '../models/ReadConfig';
import { ReadConfigViewModel } from '../viewmodel/ReadConfigViewModel';
import { Logger } from '../utils/performance/Logger';
import { ChapterLoadOptimizer } from '../utils/performance/ChapterLoadOptimizer';
import { PageTurnAnimationOptimizer } from '../utils/performance/PageTurnAnimationOptimizer';
import { MemoryManager } from '../utils/performance/MemoryManager';
import { NavigationManager } from '../common/NavigationManager';
import { showToast } from '../utils/content/ToastUtils';
import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { ReadToolbarOverlay } from '../components/ReadToolbar';
import { BackButton } from '../components/BackButton';
import { immersiveUI, UIVisibility } from '../utils/ui/ImmersiveUIManager';
import { gestureController, GestureEvent } from '../utils/ui/GestureController';
import { LiquidGlassCard } from '../components/LiquidGlassEffect';

type PageTurnDirection = 'prev' | 'next' | 'none';
type BackgroundTheme = 'light' | 'dark' | 'eye-care' | 'paper';

interface ThemeConfig {
  name: string;
  backgroundColor: string;
  textColor: string;
}

interface ContentSegment {
  type: 'text' | 'image';
  value: string;
}

@Entry
@ComponentV2
struct ReadPage {
  @Param bookId: string = '';
  @Param initialChapterIndex: number = 0;
  @Param initialChapterUrl: string = '';
  @Local chapterIndex: number = 0;
  @Local chapterUrl: string = '';
  @Local isLightMode: boolean = true;
  @Local book: Book | null = null;
  @Local chapters: Chapter[] = [];
  @Local currentChapterIndex: number = 0;
  @Local chapterContent: ChapterContent | null = null;
  @Local isLoading: boolean = false;
  @Local showChapterList: boolean = false;
  @Local showMenu: boolean = false;
  @Local showSettings: boolean = false;
  @Local menuOpacity: number = 0;
  @Local menuTranslateY: number = 30;
  @Local readConfig: ReadConfig = ReadConfigViewModel.DEFAULT_READ_CONFIG;
  @Local loadError: string = '';
  @Local showRetryCount: number = 0;
  @Local scrollOffset: number = 0;
  @Local maxScrollOffset: number = 0;
  @Local isProgrammaticScroll: boolean = false;

  private lastScrollY: number = 0;
  private lastScrollTime: number = 0;
  private scrollThrottleMs: number = 100;
  @Local pageTurnDirection: PageTurnDirection = 'none';
  @Local pageTurnProgress: number = 0;
  @Local menuShowStartTime: number = 0;
  @Local searchKeyword: string = '';
  @Local isBookmarked: boolean = false;
  @Local isCaching: boolean = false;
  @Local cachedChapterCount: number = 0;
  @Local contentSegments: ContentSegment[] = [];

  private bookSource: BookSource | null = null;
  private readonly themeConfigs: Record<BackgroundTheme, ThemeConfig> = {
    'light': { name: '白天', backgroundColor: '#FAF7F2', textColor: '#1A1A1A' },
    'dark': { name: '夜间', backgroundColor: '#121212', textColor: '#FAF8F5' },
    'eye-care': { name: '护眼', backgroundColor: '#C7EDCC', textColor: '#2F4F4F' },
    'paper': { name: '纸质', backgroundColor: '#F5F5DC', textColor: '#2F4F4F' }
  };
  private isComponentActive: boolean = false;
  private readonly MAX_RETRY_COUNT: number = 3;
  private screenWidth: number = 0;
  private scroller: Scroller = new Scroller();
  private lastVolumeUpTime: number = 0;
  private lastVolumeDownTime: number = 0;
  private readonly VOLUME_KEY_DEBOUNCE: number = 300;
  private chapterLoadOptimizer: ChapterLoadOptimizer = ChapterLoadOptimizer.getInstance();
  private animationOptimizer: PageTurnAnimationOptimizer = PageTurnAnimationOptimizer.getInstance();
  private memoryManager: MemoryManager = MemoryManager.getInstance();
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };
  private immersiveHandler: (visibility: UIVisibility) => void = (visibility: UIVisibility) => {
    if (!visibility.dockVisible && this.showMenu) {
      this.hideMenu();
    }
  };
  private gestureHandler: (event: GestureEvent) => void = (event: GestureEvent) => {
    if (event.type === 'swipe_up_hold' && event.isComplete) {
      if (this.showMenu) {
        this.hideMenu();
      } else {
        this.showMenuAnimated();
      }
    }
  };

  aboutToAppear(): void {
    this.isComponentActive = true;
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);

    immersiveUI.addCallback(this.immersiveHandler);
    gestureController.addCallback(this.gestureHandler);
    gestureController.setKioskMode(false);

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    viewModelManager.setContext(context);

    try {
      const displayInfo = display.getDefaultDisplaySync();
      this.screenWidth = displayInfo.width;
    } catch (error) {
      Logger.error('ReadPage', `获取屏幕尺寸失败: ${error instanceof Error ? error.message : String(error)}`);
      this.screenWidth = 360;
    }

    this.chapterIndex = this.initialChapterIndex;
    this.chapterUrl = this.initialChapterUrl;

    this.memoryManager.startMonitoring();

    this.loadReadConfig();
    this.loadBookDetail();
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    immersiveUI.removeCallback(this.immersiveHandler);
    gestureController.removeCallback(this.gestureHandler);

    this.chapterContent = null;
    this.chapters = [];
    this.book = null;
    this.bookSource = null;

    this.chapterLoadOptimizer.clearCache();
    this.animationOptimizer.clearPreRenderCache();
    this.memoryManager.stopMonitoring();
  }

  private hideMenu(): void {
    this.showMenu = false;
    this.menuOpacity = 0;
  }

  private showMenuAnimated(): void {
    this.showMenu = true;
    this.menuOpacity = 1;
  }

  async loadReadConfig(): Promise<void> {
    if (!this.isComponentActive) return;
    
    try {
      const readConfigViewModel = viewModelManager.getReadConfigViewModel();
      this.readConfig = await readConfigViewModel.getReadConfig();
    } catch (error) {
      Logger.error('ReadPage', `加载阅读配置失败: ${error}`);
    }
  }

  async loadBookDetail(): Promise<void> {
    if (!this.isComponentActive) return;
    
    Logger.info('ReadPage', `bookId: ${this.bookId}, chapterIndex: ${this.chapterIndex}`);
    
    if (this.bookId) {
      const bookViewModel = viewModelManager.getBookViewModel();
      this.book = await bookViewModel.getBookById(this.bookId);
      
      if (this.book && this.isComponentActive) {
        const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
        this.bookSource = await bookSourceViewModel.getBookSourceById(this.book.bookSourceId);
      }
    }
    
    await this.loadChapters();
    await this.loadChapterContent();
  }

  async loadChapters(): Promise<void> {
    if (!this.book || !this.isComponentActive) return;
    
    try {
      const chapterViewModel = viewModelManager.getChapterViewModel();
      this.chapters = await chapterViewModel.getChapters(this.bookId);
      
      if (this.chapters.length === 0 && this.bookSource) {
        this.chapters = await chapterViewModel.fetchAndSaveChapters(
          this.bookId, 
          this.bookSource, 
          this.book.bookUrl
        );
      }
    } catch (error) {
      Logger.error('ReadPage', `加载章节失败: ${error}`);
    }
  }

  async loadChapterContent(): Promise<void> {
    if (!this.book || !this.bookSource || !this.isComponentActive) return;

    this.isLoading = true;
    this.loadError = '';
    try {
      if (this.chapters.length > this.chapterIndex) {
        const chapterId = this.chapters[this.chapterIndex].id;
        const chapterViewModel = viewModelManager.getChapterViewModel();
        this.chapterContent = await chapterViewModel.getChapterContent(
          chapterId,
          this.chapterUrl,
          this.bookSource
        );
        this.contentSegments = this.parseContentSegments(this.chapterContent.content);
        this.showRetryCount = 0;
        this.scroller.scrollToIndex(0);
        this.scrollOffset = 0;
        await this.loadBookmarkStatus();
      }
    } catch (error) {
      Logger.error('ReadPage', `加载章节内容失败: ${error}`);
      const errorMsg = error instanceof Error ? error.message : String(error);
      this.loadError = errorMsg;
      this.showRetryCount++;
      if (this.isComponentActive) {
        showToast({
          message: '加载失败，请点击重试'
        });
      }
    } finally {
      if (this.isComponentActive) {
        this.isLoading = false;
      }
    }
  }

  async loadBookmarkStatus(): Promise<void> {
    if (!this.book) return;
    try {
      const bookmarkViewModel = viewModelManager.getBookmarkViewModel();
      const bookmarks = await bookmarkViewModel.getBookmarksByBookId(this.book.id);
      if (this.chapterContent) {
        this.isBookmarked = bookmarks.some(bookmark => bookmark.chapterId === this.chapterContent!.chapterId);
      }
    } catch (error) {
      Logger.error('ReadPage', `加载书签状态失败: ${error}`);
    }
  }

  private parseContentSegments(content: string): ContentSegment[] {
    const segments: ContentSegment[] = [];
    if (!content) {
      return segments;
    }

    const imgRegex = /<img\s+[^>]*\/?>/gi;
    let lastIndex = 0;
    let match: RegExpExecArray | null;

    while ((match = imgRegex.exec(content)) !== null) {
      const matchIndex = match.index;
      const imgTag = match[0];

      if (matchIndex > lastIndex) {
        const textContent = content.substring(lastIndex, matchIndex);
        if (textContent.trim().length > 0) {
          segments.push({ type: 'text', value: textContent.trim() });
        }
      }

      segments.push({ type: 'image', value: imgTag });

      lastIndex = matchIndex + imgTag.length;
    }

    if (lastIndex < content.length) {
      const remaining = content.substring(lastIndex);
      if (remaining.trim().length > 0) {
        segments.push({ type: 'text', value: remaining.trim() });
      }
    }

    if (segments.length === 0 && content.trim().length > 0) {
      segments.push({ type: 'text', value: content.trim() });
    }

    return segments;
  }

  private extractImageSrc(imgTag: string): string {
    const srcMatch = imgTag.match(/src=["']([^"']+)["']/i);
    return srcMatch ? srcMatch[1] : '';
  }

  async toggleBookmark(): Promise<void> {
    if (!this.book || !this.chapterContent) return;

    try {
      const bookmarkViewModel = viewModelManager.getBookmarkViewModel();

      if (this.isBookmarked) {
        const bookmarks = await bookmarkViewModel.getBookmarksByBookId(this.book.id);
        const bookmark = bookmarks.find(b => b.chapterId === this.chapterContent!.chapterId);
        if (bookmark) {
          await bookmarkViewModel.deleteBookmark(bookmark.id);
          this.isBookmarked = false;
          showToast({ message: '已取消书签' });
        }
      } else {
        const chapterTitle = this.chapters.length > this.chapterIndex ? this.chapters[this.chapterIndex].title : '';
        const content = this.chapterContent.content.substring(0, 100);
        await bookmarkViewModel.addBookmark(this.book.id, this.chapterContent.chapterId, chapterTitle, content);
        this.isBookmarked = true;
        showToast({ message: '已添加书签' });
      }
    } catch (error) {
      Logger.error('ReadPage', `书签操作失败: ${error}`);
      showToast({ message: '书签操作失败' });
    }
  }

  async cacheChapters(): Promise<void> {
    if (!this.book || !this.bookSource || this.isCaching) return;

    this.isCaching = true;
    this.cachedChapterCount = 0;

    try {
      const chapterViewModel = viewModelManager.getChapterViewModel();
      const cacheCount = Math.min(10, this.chapters.length - this.chapterIndex - 1);
      const concurrency = 3;

      const chaptersToCache = this.chapters.slice(this.chapterIndex + 1, this.chapterIndex + 1 + cacheCount);

      for (let i = 0; i < chaptersToCache.length; i += concurrency) {
        const batch = chaptersToCache.slice(i, i + concurrency);
        await Promise.all(batch.map(async (chapter) => {
          try {
            if (this.bookSource) {
              await chapterViewModel.getChapterContent(chapter.id, chapter.url, this.bookSource);
              this.cachedChapterCount++;
            }
          } catch (error) {
            Logger.error('ReadPage', `缓存章节失败: ${chapter.title}, ${error}`);
          }
        }));

        if (this.cachedChapterCount > 0) {
          showToast({ message: `已缓存${this.cachedChapterCount}/${cacheCount}章` });
        }
      }

      if (this.cachedChapterCount > 0) {
        showToast({ message: `缓存完成，共${this.cachedChapterCount}章` });
      } else {
        showToast({ message: '缓存失败' });
      }
    } catch (error) {
      Logger.error('ReadPage', `缓存章节失败: ${error}`);
      showToast({ message: '缓存失败' });
    } finally {
      this.isCaching = false;
    }
  }

  async retryLoadChapter(): Promise<void> {
    if (this.showRetryCount < this.MAX_RETRY_COUNT) {
      await this.loadChapterContent();
    } else {
      showToast({
        message: '重试次数过多，请检查网络后重试'
      });
    }
  }

  goBackToBookshelf(): void {
    this.updateReadProgress();
    NavigationManager.getInstance().navigateBack();
  }

  async nextChapter(): Promise<void> {
    if (this.chapterIndex < this.chapters.length - 1) {
      this.animatePageTurn('next');
      this.chapterIndex++;
      this.chapterUrl = this.chapters[this.chapterIndex].url;
      await this.loadChapterContent();
    } else {
      showToast({
        message: '已经是最后一章了'
      });
    }
  }

  async prevChapter(): Promise<void> {
    if (this.chapterIndex > 0) {
      this.animatePageTurn('prev');
      this.chapterIndex--;
      this.chapterUrl = this.chapters[this.chapterIndex].url;
      await this.loadChapterContent();
    } else {
      showToast({
        message: '已经是第一章了'
      });
    }
  }

  animatePageTurn(direction: PageTurnDirection): void {
    if (this.readConfig.pageTurnMode === 'scroll') {
      return;
    }

    const turnDirection = direction === 'next' ? 'next' : 'prev';
    this.animationOptimizer.animatePageTurn(turnDirection, () => {
      this.pageTurnDirection = direction;
      this.pageTurnProgress = 0;
    }, () => {
      this.pageTurnDirection = 'none';
      this.pageTurnProgress = 0;
    });
  }

  handleScreenClick(x: number): void {
    if (this.showMenu || this.showChapterList || this.showSettings) {
      this.showMenu = false;
      this.showChapterList = false;
      this.showSettings = false;
      return;
    }

    if (!this.readConfig.clickPageTurn) {
      this.menuShowStartTime = Date.now();
      this.showMenu = true;
      return;
    }

    const thirdWidth = this.screenWidth / 3;

    if (x < thirdWidth) {
      this.prevChapter();
    } else if (x > thirdWidth * 2) {
      this.nextChapter();
    } else {
      this.menuShowStartTime = Date.now();
      this.showMenu = true;
    }
  }

  handleVolumeKeyUp(): void {
    const currentTime = Date.now();
    if (currentTime - this.lastVolumeUpTime < this.VOLUME_KEY_DEBOUNCE) {
      return;
    }
    this.lastVolumeUpTime = currentTime;
    this.prevChapter();
  }

  handleVolumeKeyDown(): void {
    const currentTime = Date.now();
    if (currentTime - this.lastVolumeDownTime < this.VOLUME_KEY_DEBOUNCE) {
      return;
    }
    this.lastVolumeDownTime = currentTime;
    this.nextChapter();
  }

  async updateReadProgress(): Promise<void> {
    if (!this.book || !this.isComponentActive) return;
    
    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      if (this.chapters.length > this.chapterIndex) {
        await bookViewModel.updateReadProgress(
          this.book.id, 
          this.chapterIndex, 
          this.chapters[this.chapterIndex].title
        );
      }
    } catch (error) {
      Logger.error('ReadPage', `更新阅读进度失败: ${error}`);
    }
  }

  getChapterProgress(): number {
    if (this.chapters.length === 0) return 0;
    return ((this.chapterIndex + 1) / this.chapters.length) * 100;
  }

  get filteredChapters(): Chapter[] {
    if (!this.searchKeyword) {
      return this.chapters;
    }
    return this.chapters.filter(chapter => chapter.title.includes(this.searchKeyword));
  }

  jumpToChapter(index: number): void {
    if (index >= 0 && index < this.chapters.length && index !== this.chapterIndex) {
      this.updateReadProgress();
      this.chapterIndex = index;
      this.chapterUrl = this.chapters[index].url;
      this.showChapterList = false;
      this.showMenu = false;
      this.loadChapterContent();
    }
  }

  getCurrentTheme(): BackgroundTheme {
    const backgroundColor = this.readConfig.backgroundColor;
    const textColor = this.readConfig.textColor;
    if (backgroundColor === '#FAF7F2' && textColor === '#1A1A1A') return 'light';
    if (backgroundColor === '#121212' && textColor === '#FAF8F5') return 'dark';
    if (backgroundColor === '#C7EDCC' && textColor === '#2F4F4F') return 'eye-care';
    if (backgroundColor === '#F5F5DC' && textColor === '#2F4F4F') return 'paper';
    return 'light';
  }

  changeTheme(theme: BackgroundTheme): void {
    const themeConfig = this.themeConfigs[theme];
    this.readConfig.backgroundColor = themeConfig.backgroundColor;
    this.readConfig.textColor = themeConfig.textColor;
    this.readConfig.isNightMode = theme === 'dark';
    viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
  }

  @Builder
  buildPageTurnAnimation(): void {
    if (this.pageTurnDirection !== 'none') {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.pageTurnDirection === 'next' ? 
          'rgba(0, 0, 0, 0.1)' : 'rgba(255, 255, 255, 0.1)')
        .opacity(this.pageTurnProgress > 0.5 ? 1 - this.pageTurnProgress : this.pageTurnProgress)
    }
  }

  @Builder
  buildTopMenu(): void {
    Column() {
      Row() {
        BackButton({
          buttonSize: 'medium',
          style: 'circle',
          onBack: () => {
            this.updateReadProgress();
            NavigationManager.getInstance().navigateBack();
          }
        })

        if (this.book) {
          Column() {
            Text(this.book.name)
              .fontSize(16)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .fontWeight(600)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            
            if (this.chapters.length > this.chapterIndex) {
              Text(this.chapters[this.chapterIndex].title)
                .fontSize(12)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 4 })
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: DesignSystem.Spacing.sm })
        }
      }
      .width('100%')
      .padding({ left: DesignSystem.Spacing.md, right: DesignSystem.Spacing.lg, top: 15, bottom: 15 })
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .border({
        width: { bottom: 1 },
        color: DesignSystem.getBorderColor(this.isLightMode)
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildBottomMenu(): void {
    Column() {
      Row() {
        Text('A-')
          .fontSize(16)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .borderRadius(8)
          .margin({ right: 8 })
          .onClick(() => {
            this.readConfig.fontSize = Math.max(this.readConfig.fontSize - 2, 12);
            viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
          })

        Text('A+')
          .fontSize(16)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .borderRadius(8)
          .margin({ right: 16 })
          .onClick(() => {
            this.readConfig.fontSize = Math.min(this.readConfig.fontSize + 2, 32);
            viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
          })

        Blank()

        Text('目录')
          .fontSize(14)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius(8)
          .margin({ right: 8 })
          .onClick(() => {
            this.showChapterList = true;
            this.showMenu = false;
          })

        Text(this.isBookmarked ? '书签' : '书签')
          .fontSize(14)
          .fontColor(this.isBookmarked ? DesignSystem.getPrimaryColor(this.isLightMode) : DesignSystem.getPrimaryTextColor(this.isLightMode))
          .backgroundColor(this.isBookmarked ? DesignSystem.getTertiaryBackgroundColor(this.isLightMode) : DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius(8)
          .margin({ right: 8 })
          .onClick(() => {
            this.toggleBookmark();
          })

        Text(this.isCaching ? `缓存中${this.cachedChapterCount}` : '缓存')
          .fontSize(14)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius(8)
          .margin({ right: 8 })
          .onClick(() => {
            this.cacheChapters();
          })

        Text('设置')
          .fontSize(14)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius(8)
          .onClick(() => {
            this.showSettings = true;
            this.showMenu = false;
          })
      }
      .width('100%')
      .padding({ left: 15, right: 15, top: 12, bottom: 12 })

      Row() {
        Text('上一章')
          .fontSize(14)
          .fontColor(this.chapterIndex > 0 ? DesignSystem.getPrimaryTextColor(this.isLightMode) : '#999')
          .backgroundColor(this.chapterIndex > 0 ? DesignSystem.getSecondaryBackgroundColor(this.isLightMode) : 'transparent')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(8)
          .onClick(() => {
            if (this.chapterIndex > 0) {
              this.prevChapter();
            }
          })

        Column() {
          Text(`${this.getChapterProgress().toFixed(0)}%`)
            .fontSize(12)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))

          Slider({
            value: this.getChapterProgress(),
            min: 0,
            max: 100,
            step: 1,
            style: SliderStyle.OutSet
          })
            .width('100%')
            .height(4)
            .margin({ top: 4 })
            .blockColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .trackColor(DesignSystem.getBorderColor(this.isLightMode))
            .trackThickness(4)
            .blockSize({ width: 16, height: 16 })
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((value: number) => {
              const targetChapterIndex = Math.floor((value / 100) * this.chapters.length);
              if (targetChapterIndex >= 0 && targetChapterIndex < this.chapters.length && targetChapterIndex !== this.chapterIndex) {
                this.jumpToChapter(targetChapterIndex);
              }
            })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Text('下一章')
          .fontSize(14)
          .fontColor(this.chapterIndex < this.chapters.length - 1 ? DesignSystem.getPrimaryTextColor(this.isLightMode) : '#999')
          .backgroundColor(this.chapterIndex < this.chapters.length - 1 ? DesignSystem.getSecondaryBackgroundColor(this.isLightMode) : 'transparent')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(8)
          .onClick(() => {
            if (this.chapterIndex < this.chapters.length - 1) {
              this.nextChapter();
            }
          })
      }
      .width('100%')
      .padding({ left: 15, right: 15, top: 8, bottom: 12 })
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
        Text('翻页模式:')
          .fontSize(12)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        
        ForEach(['cover', 'slide', 'scroll'], (mode: string) => {
          Text(this.getPageTurnModeText(mode))
            .fontSize(12)
            .fontColor(this.readConfig.pageTurnMode === mode ? Color.White : DesignSystem.getPrimaryTextColor(this.isLightMode))
            .backgroundColor(this.readConfig.pageTurnMode === mode ? DesignSystem.getPrimaryColor(this.isLightMode) : DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(6)
            .margin({ left: 8 })
            .onClick(() => {
              this.readConfig.pageTurnMode = mode as 'cover' | 'slide' | 'scroll' | 'simulation';
              viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
            })
        })
      }
      .width('100%')
      .padding({ left: 15, right: 15, bottom: 15 })
    }
    .width('100%')
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: { top: 1 },
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
  }

  getPageTurnModeText(mode: string): string {
    switch (mode) {
      case 'cover': return '覆盖';
      case 'slide': return '滑动';
      case 'scroll': return '滚动';
      case 'simulation': return '仿真';
      default: return mode;
    }
  }

  @Builder
  buildChapterList(): void {
    Column() {
      Row() {
        Text('目录')
          .fontSize(18)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(600)
          .layoutWeight(1)

        Button() {
          Text('✕')
            .fontSize(20)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        }
        .width(32)
        .height(32)
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .onClick(() => {
          this.showChapterList = false;
        })
      }
      .width('100%')
      .padding(15)
      .alignItems(VerticalAlign.Center)

      TextInput({ placeholder: '搜索章节', text: this.searchKeyword })
        .width('100%')
        .height(40)
        .margin({ left: 15, right: 15, bottom: 10 })
        .backgroundColor(DesignSystem.getTertiaryBackgroundColor(this.isLightMode))
        .onChange((value: string) => {
          this.searchKeyword = value;
        })

      List() {
        ForEach(this.filteredChapters, (chapter: Chapter, index: number) => {
          ListItem() {
            Row() {
              Text(chapter.title)
                .fontSize(14)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)

              if (chapter.isVip) {
                Text('VIP')
                  .fontSize(10)
                  .fontColor(DesignSystem.Colors.text.primary.light)
                  .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                  .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                  .borderRadius(4)
                  .margin({ left: 8 })
              }
            }
            .width('100%')
            .padding(12)
            .borderRadius(8)
            .backgroundColor(index === this.chapterIndex ? DesignSystem.getSecondaryBackgroundColor(this.isLightMode) : Color.Transparent)
            .onClick(() => {
              this.jumpToChapter(index);
            })
          }
        }, (chapter: Chapter) => chapter.id)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 15, right: 15 })
      .scrollBar(BarState.Auto)
      .cachedCount(10)
    }
    .width(320)
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildSettingsPanel(): void {
    Column() {
      Row() {
        Text('阅读设置')
          .fontSize(18)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(600)
          .layoutWeight(1)

        Button() {
          Text('✕')
            .fontSize(20)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        }
        .width(32)
        .height(32)
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .onClick(() => {
          this.showSettings = false;
        })
      }
      .width('100%')
      .padding(15)
      .alignItems(VerticalAlign.Center)

      Column() {
        Row() {
          Text('字体大小')
            .fontSize(14)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .width(80)
          
          Slider({
            value: this.readConfig.fontSize,
            min: 12,
            max: 32,
            step: 2,
            style: SliderStyle.OutSet
          })
            .width('60%')
            .blockColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .trackColor(DesignSystem.getBorderColor(this.isLightMode))
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((value: number) => {
              this.readConfig.fontSize = Math.round(value);
              viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
            })
          
          Text(`${this.readConfig.fontSize}`)
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .width(40)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ left: 15, right: 15, top: 10, bottom: 10 })

        Row() {
          Text('行间距')
            .fontSize(14)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .width(80)
          
          Slider({
            value: this.readConfig.lineSpacing,
            min: 1.0,
            max: 3.0,
            step: 0.1,
            style: SliderStyle.OutSet
          })
            .width('60%')
            .blockColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .trackColor(DesignSystem.getBorderColor(this.isLightMode))
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((value: number) => {
              this.readConfig.lineSpacing = Math.round(value * 10) / 10;
              viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
            })
          
          Text(`${this.readConfig.lineSpacing.toFixed(1)}`)
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .width(40)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ left: 15, right: 15, top: 10, bottom: 10 })

        Row() {
          Text('翻页模式')
            .fontSize(14)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .width(80)
          
          Row() {
            ForEach(['cover', 'slide', 'scroll', 'simulation'], (mode: string) => {
              Text(this.getPageTurnModeText(mode))
                .fontSize(12)
                .fontColor(this.readConfig.pageTurnMode === mode ? Color.White : DesignSystem.getPrimaryTextColor(this.isLightMode))
                .backgroundColor(this.readConfig.pageTurnMode === mode ? DesignSystem.getPrimaryColor(this.isLightMode) : DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .borderRadius(6)
                .margin({ right: 8 })
                .onClick(() => {
                  this.readConfig.pageTurnMode = mode as 'cover' | 'slide' | 'scroll' | 'simulation';
                  viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
                })
            })
          }
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 15, right: 15, top: 10, bottom: 10 })

        Row() {
          Text('背景主题')
            .fontSize(14)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .width(80)

          Row() {
            ForEach(['light', 'dark', 'eye-care', 'paper'] as BackgroundTheme[], (theme: BackgroundTheme) => {
              Text(this.themeConfigs[theme].name)
                .fontSize(12)
                .fontColor(this.getCurrentTheme() === theme ? Color.White : DesignSystem.getPrimaryTextColor(this.isLightMode))
                .backgroundColor(this.getCurrentTheme() === theme ? DesignSystem.getPrimaryColor(this.isLightMode) : DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .borderRadius(6)
                .margin({ right: 8 })
                .onClick(() => {
                  this.changeTheme(theme);
                })
            })
          }
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 15, right: 15, top: 10, bottom: 10 })

        Row() {
          Text('夜间模式')
            .fontSize(14)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .width(80)

          Toggle({ type: ToggleType.Switch, isOn: this.readConfig.isNightMode })
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((isOn: boolean) => {
              this.readConfig.isNightMode = isOn;
              viewModelManager.getReadConfigViewModel().toggleNightMode(isOn);
            })
        }
        .width('100%')
        .padding({ left: 15, right: 15, top: 10, bottom: 10 })

        Row() {
          Text('点击翻页')
            .fontSize(14)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .width(80)
          
          Toggle({ type: ToggleType.Switch, isOn: this.readConfig.clickPageTurn })
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((isOn: boolean) => {
              this.readConfig.clickPageTurn = isOn;
              viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
            })
        }
        .width('100%')
        .padding({ left: 15, right: 15, top: 10, bottom: 10 })

        Row() {
          Text('亮度')
            .fontSize(14)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .width(80)

          Slider({
            value: this.readConfig.brightness,
            min: 0,
            max: 1,
            step: 0.05,
            style: SliderStyle.OutSet
          })
            .width('60%')
            .blockColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .trackColor(DesignSystem.getBorderColor(this.isLightMode))
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((value: number) => {
              this.readConfig.brightness = Math.round(value * 100) / 100;
              viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
            })

          Text(`${Math.round(this.readConfig.brightness * 100)}%`)
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .width(40)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ left: 15, right: 15, top: 10, bottom: 10 })

        Row() {
          Text('音量键翻页')
            .fontSize(14)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .width(80)

          Toggle({ type: ToggleType.Switch, isOn: this.readConfig.volumeKeyPageTurn })
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((isOn: boolean) => {
              this.readConfig.volumeKeyPageTurn = isOn;
              viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
            })
        }
        .width('100%')
        .padding({ left: 15, right: 15, top: 10, bottom: 10 })
      }
    }
    .width('100%')
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: { top: 1 },
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
  }

  build() {
    Stack() {
      Column() {
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
        } else if (this.loadError) {
          Column() {
            Text('章节加载失败')
              .fontSize(20)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .fontWeight(600)
              .margin({ bottom: 16 })

            Text(`错误详情: ${this.loadError}`)
              .fontSize(14)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .textAlign(TextAlign.Center)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('80%')
              .margin({ bottom: 8 })

            Text(`重试次数: ${this.showRetryCount}/${this.MAX_RETRY_COUNT}`)
              .fontSize(12)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .margin({ bottom: 24 })

            Row() {
              Button('重试')
                .fontSize(16)
                .fontColor(Color.White)
                .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                .borderRadius(8)
                .width(100)
                .height(40)
                .margin({ right: 16 })
                .enabled(this.showRetryCount < this.MAX_RETRY_COUNT)
                .opacity(this.showRetryCount >= this.MAX_RETRY_COUNT ? 0.5 : 1)
                .onClick(() => {
                  this.retryLoadChapter();
                })

              Button('返回书架')
                .fontSize(16)
                .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .borderRadius(8)
                .width(100)
                .height(40)
                .onClick(() => {
                  this.goBackToBookshelf();
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            
            if (this.showRetryCount >= this.MAX_RETRY_COUNT) {
              Text('已达到最大重试次数，请检查网络连接或书源配置')
                .fontSize(12)
                .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
                .margin({ top: 16 })
                .textAlign(TextAlign.Center)
                .width('80%')
            }
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .padding(20)
        } else if (this.chapterContent) {
          Column() {
            if (this.book && this.chapters.length > 0) {
              Text(this.chapters[this.chapterIndex].title)
                .fontSize(18)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .fontWeight(600)
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ top: 20, bottom: 20 })
            }
            Scroll(this.scroller) {
              Column() {
                ForEach(this.contentSegments, (segment: ContentSegment, index: number) => {
                  if (segment.type === 'text') {
                    Text(segment.value)
                      .fontSize(this.readConfig.fontSize)
                      .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                      .lineHeight(this.readConfig.fontSize * this.readConfig.lineSpacing)
                      .width('100%')
                      .letterSpacing(this.readConfig.letterSpacing)
                  } else {
                    Image(this.extractImageSrc(segment.value))
                      .objectFit(ImageFit.Contain)
                      .width('100%')
                      .constraintSize({ maxHeight: 600 })
                      .margin({ top: 12, bottom: 12 })
                  }
                }, (segment: ContentSegment, index: number) => `${segment.type}_${index}`)
              }
              .width('100%')
              .padding({
                left: this.readConfig.margins.left,
                right: this.readConfig.margins.right,
                top: this.readConfig.margins.top,
                bottom: this.readConfig.margins.bottom
              })
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Auto)
            .scrollable(ScrollDirection.Vertical)
            .edgeEffect(EdgeEffect.Spring)
            .onScroll(() => {
              const now = Date.now();
              if (now - this.lastScrollTime < this.scrollThrottleMs) {
                return;
              }
              this.lastScrollTime = now;

              const currentY = this.scroller.currentOffset().yOffset;
              this.scrollOffset = currentY;

              // 通知沉浸式UI管理器
              const scrollDelta = currentY - this.lastScrollY;
              this.lastScrollY = currentY;

              if (Math.abs(scrollDelta) > 10) {
                immersiveUI.onScroll(currentY);
              }
            })
            .onScrollEnd(() => {
              this.maxScrollOffset = Math.max(this.maxScrollOffset, this.scrollOffset);
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
      .onClick((event: ClickEvent) => {
        this.handleScreenClick(event.x);
      })
      .onKeyEvent((event: KeyEvent) => {
        if (event.type === KeyType.Down && this.readConfig.volumeKeyPageTurn) {
          if (event.keyCode === 16) {
            this.handleVolumeKeyUp();
          } else if (event.keyCode === 17) {
            this.handleVolumeKeyDown();
          }
        }
      })

      if (this.showMenu) {
        ReadToolbarOverlay({
          isVisible: this.showMenu,
          isLightMode: this.isLightMode,
          config: {
            bookName: this.book?.name || '',
            chapterTitle: this.chapters.length > this.chapterIndex ? this.chapters[this.chapterIndex].title : '',
            chapterIndex: this.chapterIndex,
            totalChapters: this.chapters.length,
            readConfig: this.readConfig
          },
          callbacks: {
            onBack: () => {
              this.showMenu = false;
            },
            onShowChapterList: () => {
              this.showMenu = false;
              this.showChapterList = true;
            },
            onShowSettings: () => {
              this.showMenu = false;
              this.showSettings = true;
            },
            onPrevChapter: () => {
              this.prevChapter();
              this.showMenu = false;
            },
            onNextChapter: () => {
              this.nextChapter();
              this.showMenu = false;
            },
            onFontSizeChange: (size: number) => {
              this.readConfig.fontSize = size;
              viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
            },
            onPageTurnModeChange: (mode: string) => {
              this.readConfig.pageTurnMode = mode as 'cover' | 'slide' | 'scroll' | 'simulation';
              viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
            },
            onNightModeChange: (isNight: boolean) => {
              this.readConfig.isNightMode = isNight;
              viewModelManager.getReadConfigViewModel().toggleNightMode(isNight);
            },
            onMenuShowComplete: () => {
              const endTime = Date.now();
              const elapsed = endTime - this.menuShowStartTime;
              Logger.info('ReadPage', `菜单呼出耗时: ${elapsed}ms`);
              if (elapsed > 100) {
                Logger.warn('ReadPage', `菜单呼出超时: ${elapsed}ms`);
              }
            }
          }
        })
      }

      if (this.showChapterList) {
        Row() {
          Blank()
          this.buildChapterList()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          this.showMenu = false;
          this.showChapterList = false;
          this.showSettings = false;
        })
      }

      if (this.showSettings) {
        Column() {
          Blank()
          this.buildSettingsPanel()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          this.showMenu = false;
          this.showChapterList = false;
          this.showSettings = false;
        })
      }

      this.buildPageTurnAnimation()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }
}

export { ReadPage };
