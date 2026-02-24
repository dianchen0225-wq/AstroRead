import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { ContentFilterConfig, ReplaceRule, FilterRule, DEFAULT_FILTER_CONFIG } from '../models/ContentFilter';
import { ContentFilter } from '../utils/ContentFilter';
import { Logger } from '../utils/Logger';
import { router } from '@kit.ArkUI';

interface RouterParams {
  config?: ContentFilterConfig;
}

@Entry
@ComponentV2
struct ContentFilterPage {
  @Local isLightMode: boolean = true;
  @Local config: ContentFilterConfig = { ...DEFAULT_FILTER_CONFIG };
  @Local showAddReplaceDialog: boolean = false;
  @Local showAddFilterDialog: boolean = false;
  @Local editingReplaceRule: ReplaceRule | null = null;
  @Local editingFilterRule: FilterRule | null = null;
  @Local newReplacePattern: string = '';
  @Local newReplaceReplacement: string = '';
  @Local newReplaceDescription: string = '';
  @Local newFilterPattern: string = '';
  @Local newFilterDescription: string = '';

  private contentFilter: ContentFilter = ContentFilter.createDefault();
  private readonly TAG = 'ContentFilterPage';

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    try {
      const params = router.getState()?.params as RouterParams;
      if (params?.config) {
        this.config = params.config;
        this.contentFilter.setConfig(this.config);
      }
    } catch (error) {
      Logger.error(this.TAG, `获取参数失败: ${error}`);
    }
  }

  private toggleReplaceRule(rule: ReplaceRule): void {
    const index = this.config.replaceRules.findIndex(r => r.id === rule.id);
    if (index >= 0) {
      this.config.replaceRules[index] = { ...rule, enabled: !rule.enabled };
      this.config = { ...this.config };
    }
  }

  private toggleFilterRule(rule: FilterRule): void {
    const index = this.config.filterRules.findIndex(r => r.id === rule.id);
    if (index >= 0) {
      this.config.filterRules[index] = { ...rule, enabled: !rule.enabled };
      this.config = { ...this.config };
    }
  }

  private deleteReplaceRule(ruleId: string): void {
    this.config.replaceRules = this.config.replaceRules.filter(r => r.id !== ruleId);
    this.config = { ...this.config };
  }

  private deleteFilterRule(ruleId: string): void {
    this.config.filterRules = this.config.filterRules.filter(r => r.id !== ruleId);
    this.config = { ...this.config };
  }

  private addReplaceRule(): void {
    if (!this.newReplacePattern) {
      return;
    }
    const newRule: ReplaceRule = {
      id: `replace_${Date.now()}`,
      pattern: this.newReplacePattern,
      replacement: this.newReplaceReplacement,
      enabled: true,
      description: this.newReplaceDescription || undefined
    };
    this.config.replaceRules.push(newRule);
    this.config = { ...this.config };
    this.resetReplaceDialog();
  }

  private addFilterRule(): void {
    if (!this.newFilterPattern) {
      return;
    }
    const newRule: FilterRule = {
      id: `filter_${Date.now()}`,
      pattern: this.newFilterPattern,
      enabled: true,
      description: this.newFilterDescription || undefined
    };
    this.config.filterRules.push(newRule);
    this.config = { ...this.config };
    this.resetFilterDialog();
  }

  private resetReplaceDialog(): void {
    this.newReplacePattern = '';
    this.newReplaceReplacement = '';
    this.newReplaceDescription = '';
    this.showAddReplaceDialog = false;
  }

  private resetFilterDialog(): void {
    this.newFilterPattern = '';
    this.newFilterDescription = '';
    this.showAddFilterDialog = false;
  }

  private saveConfig(): void {
    this.contentFilter.setConfig(this.config);
    Logger.info(this.TAG, '配置已保存');
    router.back();
  }

  build() {
    Column() {
      Row() {
        Row() {
          Text('‹')
            .fontSize(20)
            .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .justifyContent(FlexAlign.Center)
        .margin({ right: 15 })
        .onClick(() => {
          router.back();
        })

        Text('内容净化设置')
          .fontSize(18)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(600)
          .layoutWeight(1)

        Button('保存')
          .fontSize(14)
          .fontColor(DesignSystem.Colors.text.primary.light)
          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .borderRadius(8)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => {
            this.saveConfig();
          })
      }
      .width('100%')
      .padding({ left: 15, right: 20, top: 15, bottom: 15 })
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .border({
        width: { bottom: 1 },
        color: DesignSystem.getBorderColor(this.isLightMode)
      })

      Scroll() {
        Column() {
          Column() {
            Row() {
              Text('替换规则')
                .fontSize(16)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .fontWeight(600)
                .layoutWeight(1)

              Button('+ 添加')
                .fontSize(12)
                .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .borderRadius(6)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .onClick(() => {
                  this.showAddReplaceDialog = true;
                })
            }
            .width('100%')
            .margin({ bottom: 12 })

            ForEach(this.config.replaceRules, (rule: ReplaceRule) => {
              Row() {
                Toggle({ type: ToggleType.Switch, isOn: rule.enabled })
                  .onChange((isOn: boolean) => {
                    this.toggleReplaceRule(rule);
                  })
                  .width(40)
                  .height(22)

                Column() {
                  Text(rule.description || '替换规则')
                    .fontSize(14)
                    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(rule.pattern.substring(0, 30) + (rule.pattern.length > 30 ? '...' : ''))
                    .fontSize(11)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 12 })

                Text('删除')
                  .fontSize(12)
                  .fontColor('#FF6B6B')
                  .onClick(() => {
                    this.deleteReplaceRule(rule.id);
                  })
              }
              .width('100%')
              .padding(12)
              .borderRadius(8)
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .margin({ bottom: 8 })
            }, (rule: ReplaceRule) => rule.id)
          }
          .width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .margin({ bottom: 16 })

          Column() {
            Row() {
              Text('过滤规则')
                .fontSize(16)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .fontWeight(600)
                .layoutWeight(1)

              Button('+ 添加')
                .fontSize(12)
                .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .borderRadius(6)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .onClick(() => {
                  this.showAddFilterDialog = true;
                })
            }
            .width('100%')
            .margin({ bottom: 12 })

            ForEach(this.config.filterRules, (rule: FilterRule) => {
              Row() {
                Toggle({ type: ToggleType.Switch, isOn: rule.enabled })
                  .onChange((isOn: boolean) => {
                    this.toggleFilterRule(rule);
                  })
                  .width(40)
                  .height(22)

                Column() {
                  Text(rule.description || '过滤规则')
                    .fontSize(14)
                    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(rule.pattern.substring(0, 30) + (rule.pattern.length > 30 ? '...' : ''))
                    .fontSize(11)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 12 })

                Text('删除')
                  .fontSize(12)
                  .fontColor('#FF6B6B')
                  .onClick(() => {
                    this.deleteFilterRule(rule.id);
                  })
              }
              .width('100%')
              .padding(12)
              .borderRadius(8)
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .margin({ bottom: 8 })
            }, (rule: FilterRule) => rule.id)
          }
          .width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .margin({ bottom: 16 })

          Column() {
            Text('广告过滤')
              .fontSize(16)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .fontWeight(600)
              .width('100%')
              .margin({ bottom: 12 })

            Row() {
              Text('启用广告过滤')
                .fontSize(14)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.config.enableAdFilter })
                .onChange((isOn: boolean) => {
                  this.config.enableAdFilter = isOn;
                  this.config = { ...this.config };
                })
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
          }
          .width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    .bindSheet($$this.showAddReplaceDialog, this.addReplaceSheetBuilder(), {
      height: 300,
      backgroundColor: DesignSystem.getSecondaryBackgroundColor(this.isLightMode),
      dragBar: true
    })
    .bindSheet($$this.showAddFilterDialog, this.addFilterSheetBuilder(), {
      height: 280,
      backgroundColor: DesignSystem.getSecondaryBackgroundColor(this.isLightMode),
      dragBar: true
    })
  }

  @Builder
  addReplaceSheetBuilder() {
    Column() {
      Text('添加替换规则')
        .fontSize(16)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(600)
        .margin({ bottom: 16 })

      TextInput({ placeholder: '匹配模式（正则表达式）', text: $$this.newReplacePattern })
        .width('100%')
        .height(44)
        .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
        .borderRadius(8)
        .margin({ bottom: 12 })

      TextInput({ placeholder: '替换为', text: $$this.newReplaceReplacement })
        .width('100%')
        .height(44)
        .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
        .borderRadius(8)
        .margin({ bottom: 12 })

      TextInput({ placeholder: '描述（可选）', text: $$this.newReplaceDescription })
        .width('100%')
        .height(44)
        .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
        .borderRadius(8)
        .margin({ bottom: 16 })

      Row() {
        Button('取消')
          .fontSize(14)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .borderRadius(8)
          .layoutWeight(1)
          .margin({ right: 8 })
          .onClick(() => {
            this.resetReplaceDialog();
          })

        Button('添加')
          .fontSize(14)
          .fontColor(DesignSystem.Colors.text.primary.light)
          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .borderRadius(8)
          .layoutWeight(1)
          .onClick(() => {
            this.addReplaceRule();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
  }

  @Builder
  addFilterSheetBuilder() {
    Column() {
      Text('添加过滤规则')
        .fontSize(16)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(600)
        .margin({ bottom: 16 })

      TextInput({ placeholder: '匹配模式（正则表达式）', text: $$this.newFilterPattern })
        .width('100%')
        .height(44)
        .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
        .borderRadius(8)
        .margin({ bottom: 12 })

      TextInput({ placeholder: '描述（可选）', text: $$this.newFilterDescription })
        .width('100%')
        .height(44)
        .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
        .borderRadius(8)
        .margin({ bottom: 16 })

      Row() {
        Button('取消')
          .fontSize(14)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .borderRadius(8)
          .layoutWeight(1)
          .margin({ right: 8 })
          .onClick(() => {
            this.resetFilterDialog();
          })

        Button('添加')
          .fontSize(14)
          .fontColor(DesignSystem.Colors.text.primary.light)
          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .borderRadius(8)
          .layoutWeight(1)
          .onClick(() => {
            this.addFilterRule();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
  }
}

export default ContentFilterPage;
