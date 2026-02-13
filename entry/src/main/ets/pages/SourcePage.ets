import { themeManager } from '../common/ThemeManager';
import { BookSourceViewModel } from '../viewmodel/BookSourceViewModel';
import { BookSource } from '../models/BookSource';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';

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
  private bookSourceViewModel: BookSourceViewModel = new BookSourceViewModel();
  private decoder = util.TextDecoder.create('utf-8');

  aboutToAppear(): void {
    // 初始化主题
    this.isLightMode = themeManager.isLightTheme();
    // 监听主题变化
    themeManager.addListener((isDark: boolean) => {
      this.isLightMode = !isDark;
    });
    // 加载书源列表
    this.loadSources();
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

  async addSource() {
    try {
      const documentPicker = new picker.DocumentViewPicker(getContext(this) as common.UIAbilityContext);
      const documentSelectOptions = new picker.DocumentSelectOptions();
      const documentSelectResult = await documentPicker.select(documentSelectOptions);
      if (documentSelectResult) {
        const uri = documentSelectResult[0];
        const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        const arrayBuffer = new ArrayBuffer(4096);
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
            .fontColor(this.isLightMode ? '#8a6d3b' : '#8a7f6e')
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor(this.isLightMode ? '#e0d8c9' : '#1e1e1e')
        .justifyContent(FlexAlign.Center)
        .margin({ right: 15 })

        Text($r('app.string.source_management'))
          .fontSize(18)
          .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
          .fontWeight(600)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 15, right: 20, top: 15, bottom: 15 })
      .backgroundColor(this.isLightMode ? '#f0ebe0' : '#121212')
      .border({
        width: { bottom: 1 },
        color: this.isLightMode ? '#ddd' : '#222'
      })

      Column() {
        Row() {
          Button() {
            Row() {
              Text('＋')
                .fontSize(16)
                .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
                .margin({ right: 8 })

              Text($r('app.string.add_source'))
                .fontSize(14)
                .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
            }
          }
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.isLightMode ? '#f0ebe0' : '#1e1e1e')
          .border({
            width: 1,
            color: this.isLightMode ? '#ddd' : '#2a2a2a'
          })
          .borderRadius(12)
          .margin({ right: 10 })
          .onClick(() => {
            this.addSource();
          })

          Button() {
            Row() {
              Text('↻')
                .fontSize(16)
                .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
                .margin({ right: 8 })

              Text($r('app.string.update_source'))
                .fontSize(14)
                .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
            }
          }
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.isLightMode ? '#f0ebe0' : '#1e1e1e')
          .border({
            width: 1,
            color: this.isLightMode ? '#ddd' : '#2a2a2a'
          })
          .borderRadius(12)
          .onClick(() => {
            this.updateSource();
          })
        }
        .width('100%')
        .margin({ bottom: 20 })

        Column() {
          ForEach(this.sourceList, (item: SourceItemData) => {
            Row() {
              Column() {
                Text(item.name)
                  .fontSize(14)
                  .fontWeight(500)
                  .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
                  .margin({ bottom: 4 })

                Text(item.status)
                  .fontSize(12)
                  .fontColor('#4caf50')
                  .fontWeight(500)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: item.enabled })
                .selectedColor(this.isLightMode ? '#8a6d3b' : '#d4b483')
                .onChange((isOn: boolean) => {
                  item.enabled = isOn;
                  this.toggleSource(item.id);
                })
            }
            .width('100%')
            .padding(15)
            .backgroundColor(this.isLightMode ? '#f0ebe0' : '#1e1e1e')
            .borderRadius(12)
            .border({
              width: 1,
              color: this.isLightMode ? '#ddd' : '#2a2a2a'
            })
          })
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .padding(20)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isLightMode ? '#f5f1e8' : 'transparent')
  }
}
