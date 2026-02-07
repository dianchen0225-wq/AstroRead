import { BookSource } from '../models/BookSource';
import prompt from '@ohos.promptAction';
import { BookSourceViewModel } from '../viewmodel/BookSourceViewModel';
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
  responsiveRow
} from '../styles/ComponentStyles';

/**
 * 书源管理页面 - 重构版本
 * 集成主题系统，替换硬编码颜色值为主题变量
 */
@Component
export struct BookSourcePage {
  private bookSourceViewModel: BookSourceViewModel = new BookSourceViewModel();
  private themeManager: ThemeManager = ThemeManager.getInstance();
  
  @State bookSources: BookSource[] = [];
  @State isLoading: boolean = true;
  @State showImportDialog: boolean = false;
  @State importUrl: string = '';
  @State importError: string = '';
  @State isImporting: boolean = false;
  @State isToggling: boolean = false;
  @State currentTheme: AppTheme = this.themeManager.currentTheme;

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
    this.isLoading = true;
    try {
      this.bookSources = await this.bookSourceViewModel.loadEnabledBookSources();
    } catch (error) {
      console.error('Failed to load book sources:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 切换书源启用状态 - 使用 ViewModel
   */
  async toggleBookSource(bookSource: BookSource, targetEnabled: boolean): Promise<void> {
    if (this.isToggling) return;
    this.isToggling = true;
    
    try {
      await this.bookSourceViewModel.toggleBookSource(bookSource.id, targetEnabled);
      await this.loadBookSources();
    } catch (error) {
      console.error('Failed to toggle book source:', error);
      await this.loadBookSources();
      prompt.showToast({ message: '切换失败，请重试' });
    } finally {
      this.isToggling = false;
    }
  }

  /**
   * 删除书源
   */
  async deleteBookSource(bookSource: BookSource): Promise<void> {
    try {
      await this.bookSourceViewModel.deleteBookSource(bookSource.id);
      await this.loadBookSources();
      prompt.showToast({ message: '删除成功' });
    } catch (error) {
      console.error('Failed to delete book source:', error);
      prompt.showToast({ message: '删除失败，请重试' });
    }
  }

  /**
   * 重置导入相关状态
   */
  private resetImportState(): void {
    this.importUrl = '';
    this.importError = '';
    this.isImporting = false;
  }

  /**
   * 执行书源导入
   */
  async performImport(): Promise<void> {
    if (this.isImporting) return;
    if (!this.importUrl.trim()) {
      this.importError = '请输入书源URL或JSON';
      return;
    }

    this.isImporting = true;
    this.importError = '';

    try {
      const result = await this.bookSourceViewModel.importBookSource(this.importUrl);

      setTimeout(() => {
        if (this.showImportDialog) {
          if (result.success) {
            prompt.showToast({
              message: result.message,
              duration: 2000
            });
            
            this.loadBookSources();
            
            this.showImportDialog = false;
            this.resetImportState();
          } else {
            this.importError = result.message;
            this.isImporting = false;
          }
        }
      }, 0);
    } catch (error) {
      console.error('Failed to import book source:', error);
      
      setTimeout(() => {
        if (this.showImportDialog) {
          this.importError = error instanceof Error ? error.message : '未知错误';
          this.isImporting = false;
        }
      }, 0);
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('书源管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.currentTheme.textPrimary)

        Button('导入')
          .backgroundColor(this.currentTheme.colors.PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .onClick(() => {
            this.showImportDialog = true;
          })
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

      // 书源列表
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(this.currentTheme.colors.PRIMARY)
          Text('加载中...')
            .margin({ top: 16 })
            .fontSize(14)
            .fontColor(this.currentTheme.textTertiary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.bookSources.length === 0) {
        Column() {
          Image('https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=empty%20book%20source%20list%20illustration%2C%20minimal%20style&image_size=square')
            .width(120)
            .height(120)
            .margin({ bottom: 16 })
          Text('暂无书源')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.currentTheme.textSecondary)
          Text('点击导入按钮添加书源')
            .margin({ top: 8 })
            .fontSize(14)
            .fontColor(this.currentTheme.textTertiary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.bookSources, (source: BookSource) => {
            ListItem() {
              BookSourceItem({
                source: source,
                onToggle: (targetEnabled: boolean) => this.toggleBookSource(source, targetEnabled),
                onDelete: (source: BookSource) => this.deleteBookSource(source),
                currentTheme: this.currentTheme
              })
            }
            .animation({
              duration: 300,
              curve: Curve.EaseInOut
            })
          }, (source: BookSource) => source.id)
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .divider({ 
          strokeWidth: 1, 
          color: this.currentTheme.borderColor,
          startMargin: 20,
          endMargin: 20
        })
      }

      // 导入对话框
      if (this.showImportDialog) {
        Stack() {
          // 背景遮罩
          Text('')
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => {
              this.showImportDialog = false;
              this.resetImportState();
            })

          // 对话框内容
          Column() {
            Text('导入书源')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.currentTheme.textSecondary)
              .margin({ bottom: 16 })

            TextInput({
              placeholder: '请输入书源URL或粘贴书源JSON',
              text: this.importUrl
            })
            .width('100%')
            .height(120)
            .borderRadius(this.currentTheme.borderRadius.MD)
            .backgroundColor(this.currentTheme.surfaceColor)
            .padding(12)
            .margin({ bottom: 16 })
            .fontSize(14)
            .fontColor(this.currentTheme.textPrimary)
            .placeholderColor(this.currentTheme.textTertiary)
            .onChange((value: string) => {
              this.importUrl = value;
              if (this.importError) {
                this.importError = '';
              }
            })

            if (this.importError) {
              Text(this.importError)
                .fontSize(14)
                .fontColor(this.currentTheme.colors.ERROR)
                .margin({ bottom: 16 })
            }

            Row() {
              Button('取消')
                .width('48%')
                .height(40)
                .margin({ right: '4%' })
                .borderRadius(this.currentTheme.borderRadius.MD)
                .backgroundColor(this.currentTheme.surfaceColor)
                .fontColor(this.currentTheme.textPrimary)
                .onClick(() => {
                  this.showImportDialog = false;
                  this.resetImportState();
                })

              Button('导入')
                .width('48%')
                .height(40)
                .borderRadius(this.currentTheme.borderRadius.MD)
                .backgroundColor(this.isImporting ? this.currentTheme.surfaceColor : this.currentTheme.colors.PRIMARY)
                .fontColor('#FFFFFF')
                .onClick(() => {
                  if (!this.isImporting) {
                    this.performImport();
                  }
                })
            }
          }
          .width('80%')
          .padding(20)
          .backgroundColor(this.currentTheme.cardColor)
          .borderRadius(this.currentTheme.borderRadius.LG)
          .shadow({ 
            radius: this.currentTheme.shadows.LG.radius, 
            color: this.currentTheme.shadows.LG.color, 
            offsetX: this.currentTheme.shadows.LG.offsetX, 
            offsetY: this.currentTheme.shadows.LG.offsetY 
          })
          .animation({
            duration: 300,
            curve: Curve.EaseOut
          })
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .animation({
          duration: 200,
          curve: Curve.EaseOut
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentTheme.backgroundColor)
  }
}

/**
 * 书源列表项组件 - 重构版本
 */
@Component
struct BookSourceItem {
  public source: BookSource = {
    id: '',
    name: '',
    url: '',
    enabled: false,
    header: undefined,
    searchUrl: '',
    searchRule: {
      bookList: '',
      name: '',
      author: '',
      bookUrl: '',
      cover: undefined,
      intro: undefined,
      nextUrl: undefined
    },
    findRule: undefined,
    chapterRule: {
      chapterList: '',
      chapterName: '',
      chapterUrl: '',
      nextUrl: undefined
    },
    contentRule: {
      content: '',
      nextUrl: undefined,
      prevUrl: undefined,
      replaceRule: undefined
    },
    ruleType: 'xpath',
    sort: 0,
    lastUpdateTime: Date.now(),
    addTime: Date.now()
  };
  public onToggle: (targetEnabled: boolean) => void = () => {};
  public onDelete: (source: BookSource) => void = () => {};
  public currentTheme: AppTheme;

  build() {
    Row() {
      Column() {
        Text(this.source.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.currentTheme.textPrimary)
          .maxLines(1)
          .width('100%')

        Text(this.source.url)
          .margin({ top: 4 })
          .fontSize(14)
          .fontColor(this.currentTheme.textTertiary)
          .maxLines(1)
          .width('100%')

        Row() {
          Text(this.source.ruleType.toUpperCase())
            .fontSize(10)
            .fontColor('#FFFFFF')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(this.currentTheme.colors.PRIMARY)
            .borderRadius(4)
            .margin({ right: 8 })

          Text(this.source.enabled ? '已启用' : '已禁用')
            .fontSize(10)
            .fontColor(this.source.enabled ? this.currentTheme.colors.SUCCESS : this.currentTheme.colors.WARNING)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(this.source.enabled ? 
              this.currentTheme.colors.SUCCESS + '20' : 
              this.currentTheme.colors.WARNING + '20')
            .borderRadius(4)
        }
        .margin({ top: 8 })
      }
      .layoutWeight(1)

      Column() {
        Button(this.source.enabled ? '禁用' : '启用')
          .width(80)
          .height(32)
          .fontSize(12)
          .margin({ bottom: 8 })
          .borderRadius(16)
          .backgroundColor(this.source.enabled ? this.currentTheme.colors.WARNING : this.currentTheme.colors.SUCCESS)
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.onToggle(!this.source.enabled);
          })

        Button('删除')
          .width(80)
          .height(32)
          .fontSize(12)
          .borderRadius(16)
          .backgroundColor(this.currentTheme.colors.ERROR)
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.onDelete(this.source);
          })
      }
      .margin({ left: 16 })
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
    .animation({
      duration: 200,
      curve: Curve.EaseInOut
    })
  }
}