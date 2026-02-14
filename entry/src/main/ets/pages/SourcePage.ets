import { themeManager } from '../common/ThemeManager';
import { BookSourceViewModel, ImportResult } from '../viewmodel/BookSourceViewModel';
import { BookSource } from '../models/BookSource';
import { SecurityScanResult, SecurityRisk, SecurityRiskLevel } from '../utils/SourceSandbox';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { DesignSystem } from '../common/DesignSystem';
import { Logger } from '../utils/Logger';

interface SourceItemData {
  name: string;
  status: string;
  enabled: boolean;
  id: string;
  isValidating: boolean;
}

interface DecodeOptions {
  stream: boolean;
}

@ComponentV2
export struct SourcePage {
  @Local isLightMode: boolean = themeManager.isLightTheme();
  @Local sourceList: SourceItemData[] = [];
  @Local showImportDialog: boolean = false;
  @Local importUrl: string = '';
  @Local isImporting: boolean = false;
  @Local isUpdating: boolean = false;
  @Local updateProgress: string = '';
  @Local showSecurityWarning: boolean = false;
  @Local securityScanResult: SecurityScanResult | null = null;
  @Local pendingImportContent: string = '';
  @Local pendingImportFormat: string = '';
  
  private bookSourceViewModel: BookSourceViewModel = new BookSourceViewModel();
  private decoder = util.TextDecoder.create('utf-8');
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    this.bookSourceViewModel.setContext(getContext(this) as common.UIAbilityContext);
    this.loadSources();
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  async loadSources() {
    try {
      const sources: BookSource[] = await this.bookSourceViewModel.loadAllBookSources();
      this.sourceList = sources.map((source: BookSource) => {
        const item: SourceItemData = {
          name: source.name,
          status: source.enabled ? '正常' : '已禁用',
          enabled: source.enabled,
          id: source.id,
          isValidating: false
        };
        return item;
      });
    } catch (error) {
      Logger.error('SourcePage', `加载书源失败: ${error}`);
      promptAction.showToast({
        message: '加载书源失败',
        duration: 2000
      });
    }
  }

  async toggleSource(id: string) {
    const source: BookSource | undefined = this.bookSourceViewModel.getBookSourceById(id);
    if (source) {
      const enabled: boolean = !source.enabled;
      await this.bookSourceViewModel.toggleBookSource(id, enabled);
      await this.loadSources();
    }
  }

  showImportDialogUI() {
    this.showImportDialog = true;
    this.importUrl = '';
  }

  async importFromUrl(url: string): Promise<void> {
    if (!url || url.trim().length === 0) {
      try {
        promptAction.showToast({
          message: '请输入书源URL',
          duration: 2000
        });
      } catch (e) {
        let code = e.code;
        let name = e.name;
        let message = e.message;
        Logger.error('SourcePage', `promptAction.showToast call failed. code is ${code}, message is ${message}`);
      }
      return;
    }

    const trimmedUrl = url.trim();
    
    if (!this.isValidUrl(trimmedUrl)) {
      try {
        promptAction.showToast({
          message: '请输入有效的URL地址',
          duration: 2000
        });
      } catch (e) {
        let code = e.code;
        let name = e.name;
        let message = e.message;
        Logger.error('SourcePage', `promptAction.showToast call failed. code is ${code}, message is ${message}`);
      }
      return;
    }

    this.isImporting = true;
    try {
      Logger.info('SourcePage', `开始从URL导入书源: ${trimmedUrl}`);
      
      const scanResult = this.bookSourceViewModel.scanSourceSecurity(trimmedUrl);
      
      if (scanResult.riskLevel === 'critical' || scanResult.riskLevel === 'high') {
        this.securityScanResult = scanResult;
        this.pendingImportContent = trimmedUrl;
        this.pendingImportFormat = 'url';
        this.showSecurityWarning = true;
        this.isImporting = false;
        return;
      }
      
      const result: ImportResult = await this.bookSourceViewModel.importBookSource(trimmedUrl);
      
      if (result.success) {
        promptAction.showToast({
          message: result.message || `成功导入${result.count || 0}个书源`,
          duration: 2000
        });
        await this.loadSources();
        this.showImportDialog = false;
      } else {
        promptAction.showToast({
          message: result.message || '导入失败',
          duration: 3000
        });
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : '未知错误';
      Logger.error('SourcePage', `导入失败: ${errorMessage}`);
      
      if (errorMessage.includes('network') || errorMessage.includes('网络')) {
        promptAction.showToast({
          message: '网络连接失败，请检查网络设置',
          duration: 3000
        });
      } else if (errorMessage.includes('timeout') || errorMessage.includes('超时')) {
        promptAction.showToast({
          message: '请求超时，请稍后重试',
          duration: 3000
        });
      } else {
        promptAction.showToast({
          message: `导入失败: ${errorMessage}`,
          duration: 3000
        });
      }
    } finally {
      this.isImporting = false;
    }
  }

  async confirmImportWithRisk(): Promise<void> {
    this.showSecurityWarning = false;
    this.isImporting = true;
    
    try {
      let result: ImportResult;
      
      if (this.pendingImportFormat === 'url') {
        result = await this.bookSourceViewModel.importBookSource(this.pendingImportContent);
      } else {
        result = await this.bookSourceViewModel.importBookSource(this.pendingImportContent, this.pendingImportFormat);
      }
      
      if (result.success) {
        promptAction.showToast({
          message: result.message || `成功导入${result.count || 0}个书源`,
          duration: 2000
        });
        await this.loadSources();
        this.showImportDialog = false;
      } else {
        promptAction.showToast({
          message: result.message || '导入失败',
          duration: 3000
        });
      }
    } catch (error) {
      promptAction.showToast({
        message: '导入失败: ' + (error instanceof Error ? error.message : '未知错误'),
        duration: 2000
      });
    } finally {
      this.isImporting = false;
      this.pendingImportContent = '';
      this.pendingImportFormat = '';
      this.securityScanResult = null;
    }
  }

  cancelImportWithRisk() {
    this.showSecurityWarning = false;
    this.pendingImportContent = '';
    this.pendingImportFormat = '';
    this.securityScanResult = null;
    try {
      promptAction.showToast({
        message: '已取消导入',
        duration: 2000
      });
    } catch (e) {
      let code = e.code;
      let name = e.name;
      let message = e.message;
      Logger.error('SourcePage', `promptAction.showToast call failed. code is ${code}, message is ${message}`);
    }
  }

  private isValidUrl(url: string): boolean {
    try {
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (error) {
      return false;
    }
  }

  async addSource(): Promise<void> {
    try {
      const documentPicker = new picker.DocumentViewPicker(getContext(this) as common.UIAbilityContext);
      const documentSelectOptions = new picker.DocumentSelectOptions();
      const documentSelectResult = await documentPicker.select(documentSelectOptions);
      if (documentSelectResult) {
        const uri = documentSelectResult[0];
        const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        const arrayBuffer = new ArrayBuffer(1024 * 1024);
        fs.readSync(file.fd, arrayBuffer);
        let text = this.decoder.decodeWithStream(new Uint8Array(arrayBuffer), { stream: false } as DecodeOptions);
        
        const scanResult = this.bookSourceViewModel.scanSourceSecurity(text);
        
        if (scanResult.riskLevel === 'critical' || scanResult.riskLevel === 'high') {
          this.securityScanResult = scanResult;
          this.pendingImportContent = text;
          this.pendingImportFormat = this.bookSourceViewModel.detectSourceFormat(text);
          this.showSecurityWarning = true;
          return;
        }
        
        this.isImporting = true;
        try {
          const result: ImportResult = await this.bookSourceViewModel.importBookSource(text);
          promptAction.showToast({
            message: result.message || `成功导入${result.count || 0}个书源`,
            duration: 2000
          });
          await this.loadSources();
        } catch (error) {
          promptAction.showToast({
            message: '导入失败: ' + (error instanceof Error ? error.message : '未知错误'),
            duration: 2000
          });
        } finally {
          this.isImporting = false;
        }
      }
    } catch (e) {
      let error: BusinessError = e as BusinessError;
      Logger.error('SourcePage', `本地导入失败: ${JSON.stringify(error)}`);
    }
  }

  async updateSource(): Promise<void> {
    if (this.sourceList.length === 0) {
      try {
        promptAction.showToast({
          message: '暂无书源可更新',
          duration: 2000
        });
      } catch (e) {
        let code = e.code;
        let name = e.name;
        let message = e.message;
        Logger.error('SourcePage', `promptAction.showToast call failed. code is ${code}, message is ${message}`);
      }
      return;
    }

    this.isUpdating = true;
    this.updateProgress = '正在验证书源...';
    
    try {
      const sources: BookSource[] = await this.bookSourceViewModel.loadAllBookSources();
      const totalSources = sources.length;
      
      let validCount = 0;
      let invalidCount = 0;

      for (let i = 0; i < sources.length; i++) {
        const source = sources[i];
        this.updateProgress = `正在验证 (${i + 1}/${totalSources})...`;
        
        try {
          const isValid = await this.bookSourceViewModel.testBookSource(source);
          
          
          if (isValid) {
            validCount++;
            source.enabled = true;
          } else {
            invalidCount++;
            source.enabled = false;
          }
          
          await this.bookSourceViewModel.upsertBookSource(source);
          
          if (i < sources.length - 1) {
            await new Promise<void>(resolve => setTimeout(resolve, 500));
          }
        } catch (error) {
          Logger.error('SourcePage', `验证书源${source.name}失败: ${error}`);
          invalidCount++;
        }
      }

      await this.loadSources();
      
      promptAction.showToast({
        message: `验证完成: 有效${validCount}个, 失效${invalidCount}个`,
        duration: 3000
      });
    } catch (error) {
      Logger.error('SourcePage', `更新书源失败: ${error}`);
      promptAction.showToast({
        message: '书源更新失败，请稍后重试',
        duration: 2000
      });
    } finally {
      this.isUpdating = false;
      this.updateProgress = '';
    }
  }

  async validateSingleSource(id: string) {
    const item = this.sourceList.find(s => s.id === id);
    if (!item) return;
    
    item.isValidating = true;
    item.status = '验证中...';
    
    try {
      const source = this.bookSourceViewModel.getBookSourceById(id);
      if (source) {
        const isValid = await this.bookSourceViewModel.testBookSource(source);
        source.enabled = isValid;
        await this.bookSourceViewModel.upsertBookSource(source);
        
        item.status = isValid ? '正常' : '失效';
        item.enabled = isValid;
        
        promptAction.showToast({
          message: isValid ? '书源有效' : '书源已失效',
          duration: 2000
        });
      }
    } catch (error) {
      item.status = '验证失败';
      promptAction.showToast({
        message: '验证失败，请稍后重试',
        duration: 2000
      });
    } finally {
      item.isValidating = false;
    }
  }

  async deleteSource(id: string) {
    try {
      const result = await this.bookSourceViewModel.deleteBookSource(id);
      if (result.success) {
        promptAction.showToast({
          message: '删除成功',
          duration: 2000
        });
        await this.loadSources();
      } else {
        promptAction.showToast({
          message: result.message || '删除失败',
          duration: 2000
        });
      }
    } catch (error) {
      promptAction.showToast({
        message: '删除失败',
        duration: 2000
      });
    }
  }

  build() {
    Stack() {
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

          Text($r('app.string.source_management'))
            .fontSize(18)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .fontWeight(600)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 15, right: 20, top: 15, bottom: 15 })
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .border({
          width: { bottom: 1 },
          color: DesignSystem.getBorderColor(this.isLightMode)
        })

        Column() {
          Row() {
            Button() {
              Row() {
                Text('🌐')
                  .fontSize(16)
                  .margin({ right: 8 })
                Text('网络导入')
                  .fontSize(14)
                  .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              }
            }
            .layoutWeight(1)
            .height(40)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .border({
              width: 1,
              color: DesignSystem.getBorderColor(this.isLightMode)
            })
            .borderRadius(12)
            .margin({ right: 10 })
            .enabled(!this.isImporting && !this.isUpdating)
            .onClick(() => {
              this.showImportDialogUI();
            })

            Button() {
              Row() {
                Text('📁')
                  .fontSize(16)
                  .margin({ right: 8 })
                Text('本地导入')
                  .fontSize(14)
                  .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              }
            }
            .layoutWeight(1)
            .height(40)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .border({
              width: 1,
              color: DesignSystem.getBorderColor(this.isLightMode)
            })
            .borderRadius(12)
            .margin({ right: 10 })
            .enabled(!this.isImporting && !this.isUpdating)
            .onClick(() => {
              this.addSource();
            })

            Button() {
              Row() {
                if (this.isUpdating) {
                  LoadingProgress()
                    .width(16)
                    .height(16)
                    .color(DesignSystem.getPrimaryTextColor(this.isLightMode))
                    .margin({ right: 8 })
                } else {
                  Text('↻')
                    .fontSize(16)
                    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                    .margin({ right: 8 })
                }
                Text(this.isUpdating ? '验证中' : '验证书源')
                  .fontSize(14)
                  .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              }
            }
            .layoutWeight(1)
            .height(40)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .border({
              width: 1,
              color: DesignSystem.getBorderColor(this.isLightMode)
            })
            .borderRadius(12)
            .enabled(!this.isImporting && !this.isUpdating)
            .onClick(() => {
              this.updateSource();
            })
          }
          .width('100%')
          .margin({ bottom: 10 })

          if (this.isUpdating && this.updateProgress) {
            Row() {
              LoadingProgress()
                .width(16)
                .height(16)
                .color(DesignSystem.getPrimaryColor(this.isLightMode))
                .margin({ right: 8 })
              Text(this.updateProgress)
                .fontSize(12)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
          }

          Column() {
            if (this.sourceList.length === 0) {
              Column() {
                Text('📚')
                  .fontSize(48)
                  .margin({ bottom: 16 })
                Text('暂无书源')
                  .fontSize(16)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  .margin({ bottom: 8 })
                Text('点击"网络导入"按钮添加书源')
                  .fontSize(14)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  .margin({ bottom: 16 })
                Button('网络导入书源')
                  .fontSize(14)
                  .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                  .fontColor('#fff')
                  .borderRadius(8)
                  .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                  .onClick(() => {
                    this.showImportDialogUI();
                  })
              }
              .width('100%')
              .height(200)
              .justifyContent(FlexAlign.Center)
            } else {
              ForEach(this.sourceList, (item: SourceItemData) => {
                Row() {
                  Column() {
                    Text(item.name)
                      .fontSize(14)
                      .fontWeight(500)
                      .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                      .margin({ bottom: 4 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Row() {
                      Text(item.status)
                        .fontSize(12)
                        .fontColor(this.getStatusColor(item.status))
                        .fontWeight(500)
                      
                      if (item.isValidating) {
                        LoadingProgress()
                          .width(12)
                          .height(12)
                          .color(DesignSystem.getPrimaryColor(this.isLightMode))
                          .margin({ left: 8 })
                      }
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Row() {
                    Button('验证')
                      .fontSize(12)
                      .height(28)
                      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                      .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                      .borderRadius(6)
                      .margin({ right: 8 })
                      .enabled(!item.isValidating)
                      .onClick(() => {
                        this.validateSingleSource(item.id);
                      })

                    Toggle({ type: ToggleType.Switch, isOn: item.enabled })
                      .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
                      .onChange((isOn: boolean) => {
                        item.enabled = isOn;
                        this.toggleSource(item.id);
                      })
                  }
                }
                .width('100%')
                .padding(15)
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .borderRadius(12)
                .border({
                  width: 1,
                  color: DesignSystem.getBorderColor(this.isLightMode)
                })
                .margin({ bottom: 8 })
              })
            }
          }
          .width('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .padding(20)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))

      if (this.showImportDialog) {
        Column() {
          Column() {
            Text('导入书源')
              .fontSize(18)
              .fontWeight(600)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 12 })

            Text('支持阅读APP格式的JSON书源')
              .fontSize(12)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 16 })

            TextInput({ placeholder: '请输入书源URL', text: this.importUrl })
              .width('100%')
              .height(44)
              .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .placeholderColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .enabled(!this.isImporting)
              .onChange((value: string) => {
                this.importUrl = value;
              })

            Text('示例: https://example.com/sources.json')
              .fontSize(11)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .width('100%')
              .margin({ top: 8, bottom: 16 })

            Row() {
              Button('取消')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .borderRadius(8)
                .margin({ right: 10 })
                .enabled(!this.isImporting)
                .onClick(() => {
                  this.showImportDialog = false;
                })

              Button(this.isImporting ? '导入中...' : '导入')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                .fontColor('#fff')
                .borderRadius(8)
                .enabled(!this.isImporting && this.importUrl.trim().length > 0)
                .onClick(() => {
                  this.importFromUrl(this.importUrl);
                })
            }
            .width('100%')
          }
          .width('90%')
          .constraintSize({ maxWidth: 400 })
          .padding(24)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (!this.isImporting) {
            this.showImportDialog = false;
          }
        })
      }

      if (this.showSecurityWarning && this.securityScanResult) {
        Column() {
          Column() {
            Row() {
              Text('⚠️')
                .fontSize(24)
              Text('安全警告')
                .fontSize(18)
                .fontWeight(600)
                .fontColor('#FF6B00')
                .margin({ left: 8 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ bottom: 16 })

            Text(this.securityScanResult.summary)
              .fontSize(14)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 16 })

            Scroll() {
              Column() {
                ForEach(this.securityScanResult.risks.slice(0, 5), (risk: SecurityRisk) => {
                  Row() {
                    Text(this.getRiskLevelEmoji(risk.level))
                      .fontSize(14)
                      .margin({ right: 8 })

                    Column() {
                      Text(risk.type)
                        .fontSize(12)
                        .fontWeight(500)
                        .fontColor(this.getRiskLevelColor(risk.level))

                      Text(risk.description)
                        .fontSize(11)
                        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                        .margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                  .border({
                    width: { bottom: 1 },
                    color: DesignSystem.getBorderColor(this.isLightMode)
                  })
                })
              }
              .width('100%')
            }
            .width('100%')
            .constraintSize({ maxHeight: 200 })
            .margin({ bottom: 16 })

            Text('是否仍要导入此书源？')
              .fontSize(13)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 16 })

            Row() {
              Button('取消导入')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .borderRadius(8)
                .margin({ right: 10 })
                .onClick(() => {
                  this.cancelImportWithRisk();
                })

              Button('继续导入')
                .layoutWeight(1)
                .height(44)
                .backgroundColor('#FF6B00')
                .fontColor('#fff')
                .borderRadius(8)
                .onClick(() => {
                  this.confirmImportWithRisk();
                })
            }
            .width('100%')
          }
          .width('90%')
          .constraintSize({ maxWidth: 400 })
          .padding(24)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .borderRadius(16)
          .border({
            width: 2,
            color: '#FF6B00'
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.6)')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }

  private getRiskLevelEmoji(level: SecurityRiskLevel): string {
    switch (level) {
      case 'critical': return '🔴';
      case 'high': return '🟠';
      case 'medium': return '🟡';
      case 'low': return '🟢';
      default: return '⚪';
    }
  }

  private getRiskLevelColor(level: SecurityRiskLevel): string {
    return this.bookSourceViewModel.getSecurityRiskLevelColor(level);
  }

  private getStatusColor(status: string): string {
    switch (status) {
      case '正常':
        return '#4caf50';
      case '失效':
      case '验证失败':
        return '#f44336';
      case '已禁用':
        return '#999999';
      case '验证中...':
        return '#ff9800';
      default:
        return '#999999';
    }
  }
}
