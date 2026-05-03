import { DesignSystem } from '../../common/DesignSystem';
import { ReadConfig } from '../../models/ReadConfig';
import { viewModelManager } from '../../viewmodel/ViewModelManager';

type BackgroundTheme = 'light' | 'dark' | 'eye-care' | 'paper';

interface ThemeConfig {
  name: string;
  backgroundColor: string;
  textColor: string;
}

@ComponentV2
export struct SettingsComponent {
  @Param isLightMode: boolean = true;
  @Param readConfig: ReadConfig = {} as ReadConfig;
  @Require @Param onClose: () => void;
  @Require @Param onChangeTheme: (theme: BackgroundTheme) => void;
  @Require @Param onReadConfigChange: () => void;

  private readonly themeConfigs: Record<BackgroundTheme, ThemeConfig> = {
    'light': { name: '白天', backgroundColor: '#FAF7F2', textColor: '#1A1A1A' },
    'dark': { name: '夜间', backgroundColor: '#121212', textColor: '#FAF8F5' },
    'eye-care': { name: '护眼', backgroundColor: '#C7EDCC', textColor: '#2F4F4F' },
    'paper': { name: '纸质', backgroundColor: '#F5F5DC', textColor: '#2F4F4F' }
  };

  private getCurrentTheme(): BackgroundTheme {
    const backgroundColor = this.readConfig.backgroundColor;
    const textColor = this.readConfig.textColor;
    if (backgroundColor === '#FAF7F2' && textColor === '#1A1A1A') {
      return 'light';
    }
    if (backgroundColor === '#121212' && textColor === '#FAF8F5') {
      return 'dark';
    }
    if (backgroundColor === '#C7EDCC' && textColor === '#2F4F4F') {
      return 'eye-care';
    }
    if (backgroundColor === '#F5F5DC' && textColor === '#2F4F4F') {
      return 'paper';
    }
    return 'light';
  }

  private getPageTurnModeText(mode: string): string {
    switch (mode) {
      case 'cover': return '覆盖';
      case 'slide': return '滑动';
      case 'scroll': return '滚动';
      case 'simulation': return '仿真';
      default: return mode;
    }
  }

  build() {
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
          this.onClose();
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
                  this.onChangeTheme(theme);
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
}
