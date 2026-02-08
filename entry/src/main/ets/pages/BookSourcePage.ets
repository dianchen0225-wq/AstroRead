import { BookSource } from '../models/BookSource';
import { UIContext, PromptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { BookSourceViewModel } from '../viewmodel/BookSourceViewModel';
import { ThemeManager } from '../styles/ThemeManager';
import { AppTheme, ThemeType } from '../styles/Theme';
import { AppColors, AppBorderRadius, AppShadows } from '../styles/Theme';

/**
 * 书源管理页面 - 优化版本
 * 使用本地图标资源，改进状态提示系统
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
  @State pageState: 'loading' | 'empty' | 'hasSources' = 'loading';

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
   * 显示Toast消息（使用新API替代废弃的showToast）
   */
  private showToast(message: string, duration: number = 2000): void {
    try {
      const uiContext: UIContext = this.getUIContext();
      const promptAction: PromptAction = uiContext.getPromptAction();
      
      promptAction.openToast({
        message: message,
        duration: duration
      }).catch((error: BusinessError) => {
        console.error(`显示Toast失败，错误码：${error.code}, 错误信息：${error.message}`);
      });
    } catch (error) {
      console.error('获取UIContext失败:', error);
    }
  }

  /**
   * 加载书源列表 - 使用 ViewModel
   */
  async loadBookSources(): Promise<void> {
    this.isLoading = true;
    this.pageState = 'loading';
    try {
      this.bookSources = await this.bookSourceViewModel.loadEnabledBookSources();
      
      // 更新页面状态
      if (this.bookSources.length > 0) {
        this.pageState = 'hasSources';
      } else {
        this.pageState = 'empty';
      }
    } catch (error) {
      console.error('Failed to load book sources:', error);
      this.pageState = 'empty';
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
      this.showToast('切换失败，请重试');
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
      this.showToast('删除成功');
    } catch (error) {
      console.error('Failed to delete book source:', error);
      this.showToast('删除失败，请重试');
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
            this.showToast(result.message, 2000);
            
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

      Text('正在加载书源列表')
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
        
        Image($r('app.media.ic_book_source'))
          .width(48)
          .height(48)
          .fillColor(this.currentTheme.textTertiary)
      }
      .margin({ bottom: 32 })

      Text('暂无书源')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTheme.textPrimary)

      Text('点击导入按钮添加书源')
        .margin({ top: 8 })
        .fontSize(14)
        .fontColor(this.currentTheme.textTertiary)

      Button('导入书源')
        .margin({ top: 24 })
        .height(40)
        .padding({ left: 24, right: 24 })
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(AppColors.PRIMARY)
        .borderRadius(20)
        .onClick(() => {
          this.showImportDialog = true;
        })
    }
    .alignItems(HorizontalAlign.Center)
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
          .backgroundColor(AppColors.PRIMARY)
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
        radius: AppShadows.SM.radius,
        color: AppShadows.SM.color,
        offsetX: AppShadows.SM.offsetX,
        offsetY: AppShadows.SM.offsetY
      })

      // 内容区域
      if (this.pageState === 'hasSources') {
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
      } else {
        this.buildStateIndicator()
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
            .borderRadius(AppBorderRadius.MD)
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
                .fontColor(AppColors.ERROR)
                .margin({ bottom: 16 })
            }

            Row() {
              Button('取消')
                .width('48%')
                .height(40)
                .margin({ right: '4%' })
                .borderRadius(AppBorderRadius.MD)
                .backgroundColor(this.currentTheme.surfaceColor)
                .fontColor(this.currentTheme.textPrimary)
                .onClick(() => {
                  this.showImportDialog = false;
                  this.resetImportState();
                })

              Button('导入')
                .width('48%')
                .height(40)
                .borderRadius(AppBorderRadius.MD)
                .backgroundColor(this.isImporting ? this.currentTheme.surfaceColor : AppColors.PRIMARY)
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
          .borderRadius(AppBorderRadius.LG)
          .shadow({ 
            radius: AppShadows.LG.radius, 
            color: AppShadows.LG.color, 
            offsetX: AppShadows.LG.offsetX, 
            offsetY: AppShadows.LG.offsetY 
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
 * 书源列表项组件 - 优化版本
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
  public currentTheme: AppTheme = new AppTheme(ThemeType.LIGHT);

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
            .backgroundColor(AppColors.PRIMARY)
            .borderRadius(4)
            .margin({ right: 8 })

          Text(this.source.enabled ? '已启用' : '已禁用')
            .fontSize(10)
            .fontColor(this.source.enabled ? AppColors.SUCCESS : AppColors.WARNING)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(this.source.enabled ? 
              AppColors.SUCCESS + '20' : 
              AppColors.WARNING + '20')
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
          .backgroundColor(this.source.enabled ? AppColors.WARNING : AppColors.SUCCESS)
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.onToggle(!this.source.enabled);
          })

        Button('删除')
          .width(80)
          .height(32)
          .fontSize(12)
          .borderRadius(16)
          .backgroundColor(AppColors.ERROR)
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