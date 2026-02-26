import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { Book } from '../models/Book';
import { Chapter, ChapterContent } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { ReadConfig } from '../models/ReadConfig';
import { ReadConfigViewModel } from '../viewmodel/ReadConfigViewModel';
import { Logger } from '../utils/performance/Logger';
import { NavigationManager } from '../common/NavigationManager';
import { showToast } from '../utils/content/ToastUtils';
import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { ReadToolbarOverlay, ToolbarConfig, ToolbarCallbacks } from '../components/ReadToolbar';
import { BackButton } from '../components/BackButton';

type PageTurnDirection = 'prev' | 'next' | 'none';

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
  @Local readConfig: ReadConfig = ReadConfigViewModel.DEFAULT_READ_CONFIG;
  @Local loadError: string = '';
  @Local showRetryCount: number = 0;
  @Local scrollOffset: number = 0;
  @Local maxScrollOffset: number = 0;
  @Local pageTurnDirection: PageTurnDirection = 'none';
  @Local pageTurnProgress: number = 0;

  private bookSource: BookSource | null = null;
  private isComponentActive: boolean = false;
  private readonly MAX_RETRY_COUNT: number = 3;
  private screenWidth: number = 0;
  private scroller: Scroller = new Scroller();
  private lastVolumeUpTime: number = 0;
  private lastVolumeDownTime: number = 0;
  private readonly VOLUME_KEY_DEBOUNCE: number = 300;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isComponentActive = true;
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    
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
    
    this.loadReadConfig();
    this.loadBookDetail();
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    
    this.chapterContent = null;
    this.chapters = [];
    this.book = null;
    this.bookSource = null;
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
        this.showRetryCount = 0;
        this.scroller.scrollToIndex(0);
        this.scrollOffset = 0;
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
    
    this.pageTurnDirection = direction;
    this.pageTurnProgress = 0;
    
    animateTo({
      duration: 200,
      curve: Curve.EaseOut,
      onFinish: () => {
        this.pageTurnDirection = 'none';
        this.pageTurnProgress = 0;
      }
    }, () => {
      this.pageTurnProgress = 1;
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
      this.chapterIndex = index;
      this.chapterUrl = this.chapters[index].url;
      this.showChapterList = false;
      this.showMenu = false;
      this.loadChapterContent();
    }
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
          Text(`${this.chapterIndex + 1}/${this.chapters.length}`)
            .fontSize(12)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          
          Progress({ 
            value: this.chapterIndex + 1, 
            total: this.chapters.length > 0 ? this.chapters.length : 1,
            type: ProgressType.Linear
          })
            .width(120)
            .height(4)
            .margin({ top: 4 })
            .color(DesignSystem.getPrimaryColor(this.isLightMode))
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

      List() {
        ForEach(this.chapters, (chapter: Chapter, index: number) => {
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
                Text(this.chapterContent.content)
                  .fontSize(this.readConfig.fontSize)
                  .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                  .lineHeight(this.readConfig.fontSize * this.readConfig.lineSpacing)
                  .width('100%')
                  .padding({
                    left: this.readConfig.margins.left,
                    right: this.readConfig.margins.right,
                    top: this.readConfig.margins.top,
                    bottom: this.readConfig.margins.bottom
                  })
                  .letterSpacing(this.readConfig.letterSpacing)
              }
              .width('100%')
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Auto)
            .scrollable(ScrollDirection.Vertical)
            .edgeEffect(EdgeEffect.Spring)
            .onScroll(() => {
              this.scrollOffset = this.scroller.currentOffset().yOffset;
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
          this.showChapterList = false;
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
