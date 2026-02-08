import { ReadConfig } from '../models/ReadConfig';
import { DEFAULT_READ_CONFIG } from '../models/ReadConfig';
import { ReadConfigViewModel } from '../viewmodel/ReadConfigViewModel';
import { ThemeManager } from '../styles/ThemeManager';
import { AppTheme, AppColors, AppShadows } from '../styles/Theme';
import { ThemeToggle } from '../components/ThemeToggle';

/**
 * 设置页面 - 重构版本
 * 集成主题系统，优化UI样式
 */
@Component
export struct SettingsPage {
  private readConfigViewModel: ReadConfigViewModel = new ReadConfigViewModel();
  private themeManager: ThemeManager = ThemeManager.getInstance();
  
  @State readConfig: ReadConfig = DEFAULT_READ_CONFIG;
  @State isLoading: boolean = true;
  @State currentTheme: AppTheme = this.themeManager.currentTheme;

  aboutToAppear(): void {
    // 注册主题变更监听
    this.themeManager.onThemeChange((theme: AppTheme) => {
      this.currentTheme = theme;
    });
    this.loadReadConfig();
  }

  aboutToDisappear(): void {
    // 清理主题监听
    this.themeManager.offThemeChange(() => {});
  }

  /**
   * 加载阅读配置 - 使用 ViewModel
   */
  async loadReadConfig(): Promise<void> {
    this.isLoading = true;
    try {
      this.readConfig = await this.readConfigViewModel.loadReadConfig();
    } catch (error) {
      console.error('Failed to load read config:', error);
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('设置')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.currentTheme.textPrimary)
        
        Blank()
        
        // 主题切换按钮
        ThemeToggle()
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      .height(64)
      .backgroundColor(this.currentTheme.surfaceColor)
      .shadow({
        radius: AppShadows.SM.radius,
        color: AppShadows.SM.color,
        offsetX: AppShadows.SM.offsetX,
        offsetY: AppShadows.SM.offsetY
      })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(AppColors.PRIMARY)
          Text('加载中...')
            .margin({ top: 16 })
            .fontSize(14)
            .fontColor(this.currentTheme.textTertiary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          // 主题设置卡片
          Column() {
            Text('主题设置')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.currentTheme.textPrimary)
              .margin({ bottom: 20, left: 4 })

            // 主题模式
            Row() {
              Text('主题模式')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.currentTheme.textPrimary)
              
              Blank()
              
              ThemeToggle()
            }
            .width('100%')
            .padding({ top: 16, bottom: 16, left: 20, right: 20 })
            .borderRadius(12)
            .backgroundColor(this.currentTheme.surfaceColor)
            .animation({
              duration: 200,
              curve: Curve.EaseOut
            })

            // 跟随系统主题
            Row() {
              Text('跟随系统主题')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.currentTheme.textPrimary)
              
              Blank()
              
              Toggle({ 
                type: ToggleType.Switch, 
                isOn: false // TODO: 实现系统主题跟随
              })
                .width(50)
                .height(30)
                .selectedColor(AppColors.PRIMARY)
                .onChange((isOn: boolean) => {
                  // TODO: 实现系统主题跟随功能
                })
            }
            .width('100%')
            .padding({ top: 16, bottom: 16, left: 20, right: 20 })
            .borderRadius(12)
            .backgroundColor(this.currentTheme.surfaceColor)
            .animation({
              duration: 200,
              curve: Curve.EaseOut
            })
          }
          .backgroundColor(this.currentTheme.cardColor)
          .borderRadius(12)
          .padding(16)
          .shadow({
            radius: 4,
            color: 'rgba(0, 0, 0, 0.1)',
            offsetX: 0,
            offsetY: 2
          })
          .margin({ top: 20, left: 20, right: 20 })

          // 阅读设置卡片
          Column() {
            Text('阅读设置')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.currentTheme.textPrimary)
              .margin({ bottom: 20, left: 4 })

            // 字体大小
            Row() {
              Text('字体大小')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.currentTheme.textPrimary)
              Row() {
                Text(`${this.readConfig.fontSize}sp`)
                  .fontSize(14)
                  .fontColor(this.currentTheme.textTertiary)
                  .margin({ right: 12 })
                Slider({
                  value: this.readConfig.fontSize,
                  min: 12,
                  max: 24,
                  step: 1
                })
                .width(120)
                .height(40)
                .blockColor(AppColors.PRIMARY)
                .trackColor(this.currentTheme.surfaceColor)
                .selectedColor(AppColors.PRIMARY)
                .onChange((value: number) => {
                  this.readConfigViewModel.updateFontSize(value).then(() => {
                    this.readConfig = this.readConfigViewModel.getCurrentConfig();
                  });
                })
              }
            }
            .width('100%')
            .padding({ top: 16, bottom: 16, left: 20, right: 20 })
            .borderRadius(12)
            .backgroundColor(this.currentTheme.surfaceColor)
            .animation({
              duration: 200,
              curve: Curve.EaseOut
            })

            // 行间距
            Row() {
              Text('行间距')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.currentTheme.textPrimary)
              Row() {
                Text(`${this.readConfig.lineSpacing}x`)
                  .fontSize(14)
                  .fontColor(this.currentTheme.textTertiary)
                  .margin({ right: 12 })
                Slider({
                  value: this.readConfig.lineSpacing,
                  min: 1.0,
                  max: 2.0,
                  step: 0.1
                })
                .width(120)
                .height(40)
                .blockColor(AppColors.PRIMARY)
                .trackColor(this.currentTheme.surfaceColor)
                .selectedColor(AppColors.PRIMARY)
                .onChange((value: number) => {
                  this.readConfigViewModel.updateLineSpacing(value).then(() => {
                    this.readConfig = this.readConfigViewModel.getCurrentConfig();
                  });
                })
              }
            }
            .width('100%')
            .padding({ top: 16, bottom: 16, left: 20, right: 20 })
            .borderRadius(12)
            .backgroundColor(this.currentTheme.surfaceColor)
            .animation({
              duration: 200,
              curve: Curve.EaseOut
            })

            // 翻页模式
            Row() {
              Text('翻页模式')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.currentTheme.textPrimary)
              Button(this.getPageTurnModeText(this.readConfig.pageTurnMode))
                .fontSize(14)
                .fontColor(AppColors.PRIMARY)
                .fontWeight(FontWeight.Medium)
                .backgroundColor(AppColors.PRIMARY + '10')
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .borderRadius(16)
                .onClick(() => {
                  // TODO: 显示翻页模式选择对话框
                })
            }
            .width('100%')
            .padding({ top: 16, bottom: 16, left: 20, right: 20 })
            .borderRadius(12)
            .backgroundColor(this.currentTheme.surfaceColor)
            .animation({
              duration: 200,
              curve: Curve.EaseOut
            })

            // 夜间模式
            Row() {
              Text('夜间模式')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.currentTheme.textPrimary)
              Toggle({ 
                type: ToggleType.Switch, 
                isOn: this.readConfig.isNightMode 
              })
                .width(50)
                .height(30)
                .selectedColor(AppColors.PRIMARY)
                .onChange((isOn: boolean) => {
                  this.readConfigViewModel.toggleNightMode(isOn).then(() => {
                    this.readConfig = this.readConfigViewModel.getCurrentConfig();
                  });
                })
            }
            .width('100%')
            .padding({ top: 16, bottom: 16, left: 20, right: 20 })
            .borderRadius(12)
            .backgroundColor(this.currentTheme.surfaceColor)
            .animation({
              duration: 200,
              curve: Curve.EaseOut
            })
          }
          .backgroundColor(this.currentTheme.cardColor)
          .borderRadius(12)
          .padding(16)
          .shadow({
            radius: 4,
            color: 'rgba(0, 0, 0, 0.1)',
            offsetX: 0,
            offsetY: 2
          })
          .margin({ top: 20, left: 20, right: 20 })

          // 关于卡片
          Column() {
            Text('关于')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.currentTheme.textPrimary)
              .margin({ bottom: 20, left: 4 })

            Row() {
              Text('应用版本')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.currentTheme.textPrimary)
              Text('1.0.0')
                .fontSize(14)
                .fontColor(this.currentTheme.textTertiary)
            }
            .width('100%')
            .padding({ top: 16, bottom: 16, left: 20, right: 20 })
            .borderRadius(12)
            .backgroundColor(this.currentTheme.surfaceColor)
            .animation({
              duration: 200,
              curve: Curve.EaseOut
            })

            Row() {
              Text('开发者')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.currentTheme.textPrimary)
              Text('AstroRead Team')
                .fontSize(14)
                .fontColor(this.currentTheme.textTertiary)
            }
            .width('100%')
            .padding({ top: 16, bottom: 16, left: 20, right: 20 })
            .borderRadius(12)
            .backgroundColor(this.currentTheme.surfaceColor)
            .animation({
              duration: 200,
              curve: Curve.EaseOut
            })
          }
          .backgroundColor(this.currentTheme.cardColor)
          .borderRadius(12)
          .padding(16)
          .shadow({
            radius: 4,
            color: 'rgba(0, 0, 0, 0.1)',
            offsetX: 0,
            offsetY: 2
          })
          .margin({ top: 20, left: 20, right: 20, bottom: 20 })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentTheme.backgroundColor)
  }

  /**
   * 获取翻页模式文本
   */
  getPageTurnModeText(mode: string): string {
    const modeMap: Record<string, string> = {
      'cover': '覆盖',
      'slide': '滑动',
      'scroll': '滚动',
      'simulation': '仿真'
    };
    return modeMap[mode] || mode;
  }
}