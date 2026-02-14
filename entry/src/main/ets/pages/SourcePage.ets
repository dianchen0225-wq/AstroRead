import { themeManager } from '../common/ThemeManager';
import { BookSourceViewModel } from '../viewmodel/BookSourceViewModel';
import { BookSource } from '../models/BookSource';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { DesignSystem } from '../common/DesignSystem';

interface SourceItemData {
  name: string;
  status: string;
  enabled: boolean;
  id: string;
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
  private bookSourceViewModel: BookSourceViewModel = new BookSourceViewModel();
  private decoder = util.TextDecoder.create('utf-8');
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    this.loadSources();
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  async loadSources() {
    const sources: BookSource[] = await this.bookSourceViewModel.loadAllBookSources();
    this.sourceList = sources.map((source: BookSource) => {
      const item: SourceItemData = {
        name: source.name,
        status: source.enabled ? '正常' : '已禁用',
        enabled: source.enabled,
        id: source.id
      };
      return item;
    });
  }

  async toggleSource(id: string) {
    const source: BookSource | undefined = this.bookSourceViewModel.getBookSourceById(id);
    if (source) {
      const enabled: boolean = !source.enabled;
      await this.bookSourceViewModel.toggleBookSource(id, enabled);
      await this.loadSources();
    }
  }

  // 显示导入对话框
  showImportDialogUI() {
    this.showImportDialog = true;
    this.importUrl = '';
  }

  // 从URL导入书源
  async importFromUrl(url: string) {
    if (!url || url.trim().length === 0) {
      promptAction.showToast({
        message: '请输入书源URL',
        duration: 2000
      });
      return;
    }

    this.isImporting = true;
    try {
      let result = await this.bookSourceViewModel.importBookSource(url.trim());
      promptAction.showToast({
        message: result.message,
        duration: 2000
      });
      await this.loadSources();
      this.showImportDialog = false;
    } catch (error) {
      promptAction.showToast({
        message: '导入失败：' + (error instanceof Error ? error.message : '未知错误'),
        duration: 2000
      });
    } finally {
      this.isImporting = false;
    }
  }

  // 从本地文件导入
  async addSource() {
    try {
      const documentPicker = new picker.DocumentViewPicker(getContext(this) as common.UIAbilityContext);
      const documentSelectOptions = new picker.DocumentSelectOptions();
      const documentSelectResult = await documentPicker.select(documentSelectOptions);
      if (documentSelectResult) {
        const uri = documentSelectResult[0];
        const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        const arrayBuffer = new ArrayBuffer(1024 * 1024); // 增加到1MB
        fs.readSync(file.fd, arrayBuffer);
        let text = this.decoder.decodeWithStream(new Uint8Array(arrayBuffer), { stream: false } as DecodeOptions);
        let result = await this.bookSourceViewModel.importBookSource(text);
        promptAction.showToast({
          message: result.message,
          duration: 2000
        });
        await this.loadSources();
      }
    } catch (e) {
      let error: BusinessError = e as BusinessError;
      console.error(`DocumentViewPicker.select failed with error: ${JSON.stringify(error)}`);
    }
  }

  async updateSource() {
    for (let i = 0; i < this.sourceList.length; i++) {
      const item: SourceItemData = this.sourceList[i];
      await this.toggleSource(item.id);
    }
  }

  build() {
    Column() {
      // 顶部导航
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
        // 按钮区域
        Row() {
          // 网络导入按钮
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
          .onClick(() => {
            this.showImportDialogUI();
          })

          // 本地导入按钮
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
          .onClick(() => {
            this.addSource();
          })

          // 更新书源按钮
          Button() {
            Row() {
              Text('↻')
                .fontSize(16)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .margin({ right: 8 })

              Text($r('app.string.update_source'))
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
          .onClick(() => {
            this.updateSource();
          })
        }
        .width('100%')
        .margin({ bottom: 20 })

        // 书源列表
        Column() {
          if (this.sourceList.length === 0) {
            // 空状态提示
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

                  Text(item.status)
                    .fontSize(12)
                    .fontColor(item.enabled ? '#4caf50' : '#999')
                    .fontWeight(500)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: item.enabled })
                  .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
                  .onChange((isOn: boolean) => {
                    item.enabled = isOn;
                    this.toggleSource(item.id);
                  })
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

      // 导入对话框
      if (this.showImportDialog) {
        Column() {
          Column() {
            // 对话框标题
            Text('导入书源')
              .fontSize(18)
              .fontWeight(600)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 20 })

            // URL输入框
            TextInput({ placeholder: '请输入书源URL或粘贴JSON', text: this.importUrl })
              .width('100%')
              .height(44)
              .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .placeholderColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .onChange((value: string) => {
                this.importUrl = value;
              })

            // 按钮区域
            Row() {
              Button('取消')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .borderRadius(8)
                .margin({ right: 10 })
                .onClick(() => {
                  this.showImportDialog = false;
                })

              Button(this.isImporting ? '导入中...' : '导入')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                .fontColor('#fff')
                .borderRadius(8)
                .enabled(!this.isImporting)
                .onClick(() => {
                  this.importFromUrl(this.importUrl);
                })
            }
            .width('100%')
            .margin({ top: 20 })
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
          // 点击背景关闭对话框
          this.showImportDialog = false;
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }
}
