import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { Book } from '../models/Book';
import { Chapter } from '../models/Book';
import { Logger } from '../utils/Logger';
import { NavigationManager } from '../common/NavigationManager';
import { AppLoading, AppEmpty } from '../components/index';
import { AppButton } from '../components/AppButton';
import common from '@ohos.app.ability.common';

interface ReadSettings {
  fontSize: number;
  lineHeight: number;
  backgroundColor: string;
  textColor: string;
}

const READ_SETTINGS_KEY = 'read_settings';

@Entry
@ComponentV2
struct ReadPage {
  @Param bookId: string = '';
  @Param initialChapterIndex: number = 0;
  @Param initialChapterUrl: string = '';
  
  @Local isLightMode: boolean = true;
  @Local book: Book | null = null;
  @Local chapters: Chapter[] = [];
  @Local currentChapterIndex: number = 0;
  @Local currentChapterUrl: string = '';
  @Local chapterContent: string = '';
  @Local isLoading: boolean = false;
  @Local showMenu: boolean = false;
  @Local showSettings: boolean = false;
  @Local showChapterSheet: boolean = false;
  
  @Local readSettings: ReadSettings = {
    fontSize: 18,
    lineHeight: 1.8,
    backgroundColor: '#FAF8F0',
    textColor: '#333333'
  };
  
  private isComponentActive: boolean = false;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };
  
  private settingsPresets: ReadSettings[] = [
    { fontSize: 16, lineHeight: 1.6, backgroundColor: '#FAF8F0', textColor: '#333333' },
    { fontSize: 18, lineHeight: 1.8, backgroundColor: '#FFFFFF', textColor: '#333333' },
    { fontSize: 20, lineHeight: 2.0, backgroundColor: '#E8E8E8', textColor: '#333333' },
    { fontSize: 18, lineHeight: 1.8, backgroundColor: '#1A1A1A', textColor: '#CCCCCC' }
  ];

  aboutToAppear(): void {
    this.isComponentActive = true;
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    viewModelManager.setContext(context);

    this.currentChapterIndex = this.initialChapterIndex;
    this.currentChapterUrl = this.initialChapterUrl;

    this.loadBookInfo();
    this.loadSettings();
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    this.saveReadingProgress();
    // 清理内存，释放大型对象
    this.chapterContent = '';
    this.book = null;
    this.chapters = [];
  }

  async loadBookInfo(): Promise<void> {
    if (!this.isComponentActive || !this.bookId) return;

    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      this.book = await bookViewModel.getBookById(this.bookId);

      const chapterViewModel = viewModelManager.getChapterViewModel();
      this.chapters = await chapterViewModel.getChapters(this.bookId);

      if (this.currentChapterUrl) {
        await this.loadChapterContent(this.currentChapterUrl);
      }
    } catch (error) {
      Logger.error('ReadPage', `加载书籍信息失败: ${error}`);
    }
  }

  async loadChapterContent(chapterUrl: string): Promise<void> {
    if (!this.isComponentActive || !this.book || !chapterUrl) return;

    this.isLoading = true;
    try {
      const chapterViewModel = viewModelManager.getChapterViewModel();
      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      
      if (this.book.bookSourceId) {
        const bookSource = await bookSourceViewModel.getBookSourceById(this.book.bookSourceId);
        if (bookSource) {
          const result = await chapterViewModel.getChapterContent(
            this.bookId,
            chapterUrl,
            bookSource
          );
          this.chapterContent = result.content || '章节内容加载失败';
        } else {
          this.chapterContent = '章节内容加载失败';
        }
      } else {
        this.chapterContent = '章节内容加载失败';
      }
    } catch (error) {
      Logger.error('ReadPage', `加载章节内容失败: ${error}`);
      this.chapterContent = '章节内容加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  async saveReadingProgress(): Promise<void> {
    if (!this.isComponentActive || !this.book || !this.bookId) return;

    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      await bookViewModel.updateReadProgress(
        this.bookId,
        this.currentChapterIndex
      );
    } catch (error) {
      Logger.error('ReadPage', `保存阅读进度失败: ${error}`);
    }
  }

  loadSettings(): void {
    try {
      const settingsStr = AppStorage.get<string>(READ_SETTINGS_KEY);
      if (settingsStr) {
        this.readSettings = JSON.parse(settingsStr) as ReadSettings;
      }
    } catch (error) {
      Logger.error('ReadPage', `加载阅读设置失败: ${error}`);
    }
  }

  saveSettings(): void {
    try {
      AppStorage.setOrCreate<string>(READ_SETTINGS_KEY, JSON.stringify(this.readSettings));
    } catch (error) {
      Logger.error('ReadPage', `保存阅读设置失败: ${error}`);
    }
  }

  async prevChapter(): Promise<void> {
    if (this.currentChapterIndex > 0 && this.chapters.length > 0) {
      this.currentChapterIndex--;
      this.currentChapterUrl = this.chapters[this.currentChapterIndex].url;
      await this.loadChapterContent(this.currentChapterUrl);
    }
  }

  async nextChapter(): Promise<void> {
    if (this.currentChapterIndex < this.chapters.length - 1) {
      this.currentChapterIndex++;
      this.currentChapterUrl = this.chapters[this.currentChapterIndex].url;
      await this.loadChapterContent(this.currentChapterUrl);
    }
  }

  async openChapter(index: number): Promise<void> {
    this.showChapterSheet = false;
    if (index >= 0 && index < this.chapters.length) {
      this.currentChapterIndex = index;
      this.currentChapterUrl = this.chapters[index].url;
      await this.loadChapterContent(this.currentChapterUrl);
    }
  }

  handleBack(): void {
    NavigationManager.getInstance().navigateBack();
  }

  build() {
    Stack() {
      Column() {
        this.buildContent()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.readSettings.backgroundColor)

      if (this.showMenu) {
        this.buildMenu()
      }

      if (this.showSettings) {
        this.buildSettingsPanel()
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showChapterSheet, this.buildChapterSheet(), {
      height: '70%',
      backgroundColor: Color.Transparent,
      dragBar: true
    })
  }

  @Builder
  buildContent() {
    Column() {
      if (this.isLoading) {
        AppLoading({ text: '加载中...' })
      } else if (this.chapterContent) {
        Scroll() {
          Column() {
            Text(this.chapters[this.currentChapterIndex]?.title || '')
              .fontSize(this.readSettings.fontSize + 4)
              .fontColor(this.readSettings.textColor)
              .fontWeight(DesignSystem.Typography.weight.semibold)
              .width('100%')
              .margin({ bottom: DesignSystem.Spacing.lg })

            Text(this.chapterContent)
              .fontSize(this.readSettings.fontSize)
              .fontColor(this.readSettings.textColor)
              .lineHeight(this.readSettings.fontSize * this.readSettings.lineHeight)
              .width('100%')
          }
          .width('100%')
          .padding(DesignSystem.Spacing.lg)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .onClick(() => {
          this.showMenu = !this.showMenu;
        })

        this.buildBottomNavigation()
      } else {
        AppEmpty({
          icon: '📖',
          title: '内容加载失败',
          description: '请检查网络连接后重试'
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildBottomNavigation() {
    Row() {
      AppButton({
        text: '上一章',
        variant: 'ghost',
        buttonSize: 'sm',
        onClicked: () => {
          this.prevChapter();
        }
      })

      Text(`${this.currentChapterIndex + 1}/${this.chapters.length}`)
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(this.readSettings.textColor)

      AppButton({
        text: '下一章',
        variant: 'ghost',
        buttonSize: 'sm',
        onClicked: () => {
          this.nextChapter();
        }
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding(DesignSystem.Spacing.md)
    .backgroundColor(this.readSettings.backgroundColor)
  }

  @Builder
  buildMenu() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor(this.readSettings.textColor)
          .onClick(() => {
            this.handleBack();
          })

        Text(this.book?.name || '阅读')
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(this.readSettings.textColor)
          .fontWeight(DesignSystem.Typography.weight.medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('☰')
          .fontSize(24)
          .fontColor(this.readSettings.textColor)
          .onClick(() => {
            this.showChapterSheet = true;
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: DesignSystem.Spacing.md, right: DesignSystem.Spacing.md })
      .backgroundColor(this.readSettings.backgroundColor)

      Blank()

      Row() {
        AppButton({
          text: '目录',
          variant: 'ghost',
          buttonSize: 'sm',
          onClicked: () => {
            this.showChapterSheet = true;
          }
        })

        AppButton({
          text: '设置',
          variant: 'ghost',
          buttonSize: 'sm',
          onClicked: () => {
            this.showSettings = true;
          }
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .padding(DesignSystem.Spacing.md)
      .backgroundColor(this.readSettings.backgroundColor)
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      this.showMenu = false;
    })
  }

  @Builder
  buildSettingsPanel() {
    Column() {
      Row() {
        Text('阅读设置')
          .fontSize(DesignSystem.Typography.size.lg)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)

        Blank()

        Text('✕')
          .fontSize(20)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .onClick(() => {
            this.showSettings = false;
          })
      }
      .width('100%')
      .padding(DesignSystem.Spacing.lg)

      Column() {
        Text('字体大小')
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .width('100%')
          .margin({ bottom: DesignSystem.Spacing.sm })

        Row() {
          Text('A')
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))

          Slider({
            value: this.readSettings.fontSize,
            min: 14,
            max: 28,
            step: 2
          })
            .layoutWeight(1)
            .onChange((value: number) => {
              this.readSettings.fontSize = Math.round(value);
              this.saveSettings();
            })

          Text('A')
            .fontSize(22)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        Text('行间距')
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .width('100%')
          .margin({ top: DesignSystem.Spacing.lg, bottom: DesignSystem.Spacing.sm })

        Row() {
          ForEach([1.4, 1.6, 1.8, 2.0, 2.2], (value: number) => {
            Text(`${value}`)
              .fontSize(DesignSystem.Typography.size.sm)
              .fontColor(this.readSettings.lineHeight === value ?
                DesignSystem.getPrimaryColor(this.isLightMode) :
                DesignSystem.getSecondaryTextColor(this.isLightMode))
              .padding(DesignSystem.Spacing.sm)
              .borderRadius(DesignSystem.BorderRadius.sm)
              .backgroundColor(this.readSettings.lineHeight === value ?
                DesignSystem.getHoverColor(this.isLightMode) :
                Color.Transparent)
              .onClick(() => {
                this.readSettings.lineHeight = value;
                this.saveSettings();
              })
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)

        Text('主题')
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .width('100%')
          .margin({ top: DesignSystem.Spacing.lg, bottom: DesignSystem.Spacing.sm })

        Row() {
          ForEach(this.settingsPresets, (preset: ReadSettings, index: number) => {
            Column() {
              Row()
                .width(40)
                .height(40)
                .borderRadius(DesignSystem.BorderRadius.md)
                .backgroundColor(preset.backgroundColor)
                .border({
                  width: this.readSettings.backgroundColor === preset.backgroundColor ? 2 : 1,
                  color: this.readSettings.backgroundColor === preset.backgroundColor ?
                    DesignSystem.getPrimaryColor(this.isLightMode) :
                    DesignSystem.getBorderColor(this.isLightMode)
                })
            }
            .onClick(() => {
              this.readSettings.fontSize = preset.fontSize;
              this.readSettings.lineHeight = preset.lineHeight;
              this.readSettings.backgroundColor = preset.backgroundColor;
              this.readSettings.textColor = preset.textColor;
              this.saveSettings();
            })
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
      }
      .width('100%')
      .padding(DesignSystem.Spacing.lg)
    }
    .width('100%')
    .borderRadius({
      topLeft: DesignSystem.BorderRadius.xl,
      topRight: DesignSystem.BorderRadius.xl
    })
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    .position({ x: 0, y: '30%' })
    .shadow({
      radius: 20,
      color: 'rgba(0,0,0,0.15)',
      offsetX: 0,
      offsetY: -5
    })
  }

  @Builder
  buildChapterSheet() {
    Column() {
      Row() {
        Text('目录')
          .fontSize(DesignSystem.Typography.size.lg)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)
          .layoutWeight(1)

        Text(`${this.chapters.length} 章`)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
      }
      .width('100%')
      .padding(DesignSystem.Spacing.lg)

      List() {
        ForEach(this.chapters, (chapter: Chapter, index: number) => {
          ListItem() {
            Row() {
              Text(chapter.title)
                .fontSize(DesignSystem.Typography.size.sm)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)

              if (chapter.isVip) {
                Text('VIP')
                  .fontSize(DesignSystem.Typography.size.xs)
                  .fontColor('#FFFFFF')
                  .padding({
                    left: DesignSystem.Spacing.xs,
                    right: DesignSystem.Spacing.xs,
                    top: 2,
                    bottom: 2
                  })
                  .borderRadius(DesignSystem.BorderRadius.sm)
                  .backgroundColor(DesignSystem.getWarningColor(this.isLightMode))
              }
            }
            .width('100%')
            .padding(DesignSystem.Spacing.md)
            .borderRadius(DesignSystem.BorderRadius.md)
            .backgroundColor(this.currentChapterIndex === index ?
              DesignSystem.getHoverColor(this.isLightMode) :
              Color.Transparent)
          }
          .onClick(() => {
            this.openChapter(index);
          })
        })
      }
      .width('100%')
      .height('100%')
      .layoutWeight(1)
      .padding({
        left: DesignSystem.Spacing.lg,
        right: DesignSystem.Spacing.lg
      })
      .cachedCount(10)
    }
    .width('100%')
    .height('100%')
    .borderRadius({
      topLeft: DesignSystem.BorderRadius.xl,
      topRight: DesignSystem.BorderRadius.xl
    })
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }
}

export default ReadPage;
