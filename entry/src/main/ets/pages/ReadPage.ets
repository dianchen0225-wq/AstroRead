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
import { ParseTaskQueue, ParseTaskType, ParseTaskPriority } from '../utils/performance/ParseTaskQueue';
import { DebounceThrottleUtil, ThrottleHandle, DebounceWithArgHandle } from '../utils/performance/DebounceThrottleUtil';
import { showToast } from '../utils/content/ToastUtils';
import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { gestureController, GestureEvent } from '../utils/ui/GestureController';
import { ChapterContentComponent } from '../components/read/ChapterContentComponent';
import { ChapterListComponent } from '../components/read/ChapterListComponent';
import { ChapterListDataSource } from '../components/read/ChapterListDataSource';
import { MenuComponent } from '../components/read/MenuComponent';
import { SettingsComponent } from '../components/read/SettingsComponent';
import { PageTurnAnimationComponent } from '../components/read/PageTurnAnimationComponent';

type PageTurnDirection = 'prev' | 'next' | 'none';
type BackgroundTheme = 'light' | 'dark' | 'eye-care' | 'paper';

interface ThemeConfig {
  name: string;
  backgroundColor: string;
  textColor: string;
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
  @Local chapterContent: ChapterContent | null = null;
  @Local isLoading: boolean = false;
  @Local showChapterList: boolean = false;
  @Local showMenu: boolean = false;
  @Local showSettings: boolean = false;
  @Local menuOpacity: number = 0;
  @Local readConfig: ReadConfig = ReadConfigViewModel.DEFAULT_READ_CONFIG;
  @Local loadError: string = '';
  @Local showRetryCount: number = 0;
  @Local scrollOffset: number = 0;
  @Local maxScrollOffset: number = 0;
  @Local pageTurnDirection: PageTurnDirection = 'none';
  @Local pageTurnProgress: number = 0;
  @Local searchKeyword: string = '';
  @Local isBookmarked: boolean = false;
  @Local isCaching: boolean = false;
  @Local cachedChapterCount: number = 0;

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
  private parseTaskQueue: ParseTaskQueue = ParseTaskQueue.getInstance();
  private lastScrollY: number = 0;
  private lastScrollTime: number = 0;
  private scrollThrottleMs: number = 100;
  private scrollThrottler: ThrottleHandle | null = null;
  private searchDebouncer: DebounceWithArgHandle<string> | null = null;
  private chapterDataSource: ChapterListDataSource = new ChapterListDataSource();
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
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

    gestureController.addCallback(this.gestureHandler);
    gestureController.setKioskMode(false);

    this.scrollThrottler = DebounceThrottleUtil.throttle(() => {
      const currentY = this.scroller.currentOffset().yOffset;
      this.scrollOffset = currentY;
      const scrollDelta = currentY - this.lastScrollY;
      this.lastScrollY = currentY;
      if (Math.abs(scrollDelta) > 10) {
        // scroll event
      }
    }, this.scrollThrottleMs);

    this.searchDebouncer = DebounceThrottleUtil.debounceWithArg((keyword: string) => {
      this.searchKeyword = keyword;
    }, 300);

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
    gestureController.removeCallback(this.gestureHandler);

    this.scrollThrottler?.cancel();
    this.scrollThrottler = null;
    this.searchDebouncer?.cancel();
    this.searchDebouncer = null;

    this.parseTaskQueue.cancelTasksByBookId(this.bookId);

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
      this.chapterDataSource.updateData(this.chapters);
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
    if (!this.book || !this.isComponentActive) return;
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
    this.parseTaskQueue.pauseQueue();
    this.animationOptimizer.animatePageTurn(turnDirection, () => {
      this.pageTurnDirection = direction;
      this.pageTurnProgress = 0;
    }, () => {
      this.pageTurnDirection = 'none';
      this.pageTurnProgress = 0;
      this.parseTaskQueue.resumeQueue();
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
      this.showMenu = true;
      return;
    }

    const thirdWidth = this.screenWidth / 3;

    if (x < thirdWidth) {
      this.prevChapter();
    } else if (x > thirdWidth * 2) {
      this.nextChapter();
    } else {
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

  private handleScroll(): void {
    const now = Date.now();
    if (now - this.lastScrollTime < this.scrollThrottleMs) {
      return;
    }
    this.lastScrollTime = now;
    this.scrollThrottler?.call();
  }

  private handleScrollEnd(): void {
    this.maxScrollOffset = Math.max(this.maxScrollOffset, this.scrollOffset);
  }

  private getChapterTitle(): string {
    if (this.book && this.chapters.length > 0 && this.chapters.length > this.chapterIndex) {
      return this.chapters[this.chapterIndex].title;
    }
    return '';
  }

  private dismissAllOverlays(): void {
    this.showMenu = false;
    this.showChapterList = false;
    this.showSettings = false;
  }

  build() {
    Stack() {
      Column() {
        ChapterContentComponent({
          chapterContent: this.chapterContent,
          isLoading: this.isLoading,
          loadError: this.loadError,
          showRetryCount: this.showRetryCount,
          maxRetryCount: this.MAX_RETRY_COUNT,
          isLightMode: this.isLightMode,
          readConfig: this.readConfig,
          chapterTitle: this.getChapterTitle(),
          scroller: this.scroller,
          onRetry: () => { this.retryLoadChapter(); },
          onGoBack: () => { this.goBackToBookshelf(); },
          onScroll: () => { this.handleScroll(); },
          onScrollEnd: () => { this.handleScrollEnd(); }
        })
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

      if (this.showChapterList) {
        Row() {
          Blank()
          ChapterListComponent({
            chapterIndex: this.chapterIndex,
            isLightMode: this.isLightMode,
            searchKeyword: this.searchKeyword,
            chapterDataSource: this.chapterDataSource,
            onJumpToChapter: (index: number) => { this.jumpToChapter(index); },
            onSearchKeywordChange: (keyword: string) => { this.searchDebouncer?.call(keyword); },
            onClose: () => { this.showChapterList = false; }
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          this.dismissAllOverlays();
        })
      }

      if (this.showSettings) {
        Column() {
          Blank()
          SettingsComponent({
            isLightMode: this.isLightMode,
            readConfig: this.readConfig,
            onClose: () => { this.showSettings = false; },
            onChangeTheme: (theme: BackgroundTheme) => { this.changeTheme(theme); },
            onReadConfigChange: () => {}
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          this.dismissAllOverlays();
        })
      }

      if (this.showMenu) {
        Column() {
          Blank()
          MenuComponent({
            book: this.book,
            chapters: this.chapters,
            chapterIndex: this.chapterIndex,
            isLightMode: this.isLightMode,
            showMenu: this.showMenu,
            menuOpacity: this.menuOpacity,
            isBookmarked: this.isBookmarked,
            isCaching: this.isCaching,
            cachedChapterCount: this.cachedChapterCount,
            readConfig: this.readConfig,
            onShowChapterList: () => { this.showChapterList = true; this.showMenu = false; },
            onToggleBookmark: () => { this.toggleBookmark(); },
            onCacheChapters: () => { this.cacheChapters(); },
            onShowSettings: () => { this.showSettings = true; this.showMenu = false; },
            onPrevChapter: () => { this.prevChapter(); },
            onNextChapter: () => { this.nextChapter(); },
            onJumpToChapter: (index: number) => { this.jumpToChapter(index); },
            onReadConfigChange: () => {}
          })
        }
        .width('100%')
        .height('100%')
      }

      PageTurnAnimationComponent({
        pageTurnDirection: this.pageTurnDirection,
        pageTurnProgress: this.pageTurnProgress
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }
}

export { ReadPage };
