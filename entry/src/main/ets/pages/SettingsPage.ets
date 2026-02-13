@ComponentV2
export struct SettingsPage {
  @Param isLightMode: boolean = true;
  @Local fontSize: number = 16;
  @Local cacheSize: string = '128MB';
  @Local autoUpdate: boolean = true;
  @Local readModeIndex: number = 0;

  build() {
    Column() {
      // 顶部导航
      Row() {
        Row() {
          Image($r('app.media.ic_arrow_right'))
            .width(16)
            .height(16)
            .fillColor(this.isLightMode ? '#8a6d3b' : '#8a7f6e')
            .rotate({ angle: 180 })
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor(this.isLightMode ? '#e0d8c9' : '#1e1e1e')
        .justifyContent(FlexAlign.Center)
        .margin({ right: 15 })

        Text($r('app.string.settings'))
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

      // 内容区域
      Scroll() {
        Column() {
          // 阅读设置
          Column() {
            Text($r('app.string.reading_settings'))
              .fontSize(14)
              .fontColor(this.isLightMode ? '#333' : '#b8ad9a')
              .fontWeight(600)
              .margin({ bottom: 12 })
              .width('100%')

            // 阅读模式
            Row() {
              Text($r('app.string.reading_mode'))
                .fontSize(14)
                .fontColor(this.isLightMode ? '#333' : '#e0d8c9')

              Text('白天模式')
                .fontSize(14)
                .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor(this.isLightMode ? '#f0ebe0' : '#1e1e1e')
                .borderRadius(8)
                .border({
                  width: 1,
                  color: this.isLightMode ? '#ddd' : '#2a2a2a'
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .border({
              width: { bottom: 1 },
              color: this.isLightMode ? '#ddd' : '#222'
            })

            // 字体大小
            Row() {
              Text($r('app.string.font_size'))
                .fontSize(14)
                .fontColor(this.isLightMode ? '#333' : '#e0d8c9')

              Row() {
                Button() {
                  Text('A-')
                    .fontSize(14)
                    .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
                }
                .width(32)
                .height(32)
                .borderRadius(16)
                .backgroundColor(this.isLightMode ? '#f0ebe0' : '#1e1e1e')
                .border({
                  width: 1,
                  color: this.isLightMode ? '#ddd' : '#2a2a2a'
                })
                .onClick(() => {
                  if (this.fontSize > 12) {
                    this.fontSize--;
                  }
                })

                Text(`${this.fontSize}px`)
                  .fontSize(12)
                  .fontColor(this.isLightMode ? '#666' : '#8a7f6e')
                  .width(40)
                  .textAlign(TextAlign.Center)

                Button() {
                  Text('A+')
                    .fontSize(14)
                    .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
                }
                .width(32)
                .height(32)
                .borderRadius(16)
                .backgroundColor(this.isLightMode ? '#f0ebe0' : '#1e1e1e')
                .border({
                  width: 1,
                  color: this.isLightMode ? '#ddd' : '#2a2a2a'
                })
                .onClick(() => {
                  if (this.fontSize < 24) {
                    this.fontSize++;
                  }
                })
              }
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
          }
          .width('100%')
          .margin({ bottom: 25 })

          // 应用设置
          Column() {
            Text($r('app.string.app_settings'))
              .fontSize(14)
              .fontColor(this.isLightMode ? '#333' : '#b8ad9a')
              .fontWeight(600)
              .margin({ bottom: 12 })
              .width('100%')

            // 自动更新
            Row() {
              Text($r('app.string.auto_update'))
                .fontSize(14)
                .fontColor(this.isLightMode ? '#333' : '#e0d8c9')

              Toggle({ type: ToggleType.Switch, isOn: this.autoUpdate })
                .selectedColor(this.isLightMode ? '#8a6d3b' : '#d4b483')
                .onChange((isOn: boolean) => {
                  this.autoUpdate = isOn;
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .border({
              width: { bottom: 1 },
              color: this.isLightMode ? '#ddd' : '#222'
            })

            // 缓存清理
            Row() {
              Text($r('app.string.clear_cache'))
                .fontSize(14)
                .fontColor(this.isLightMode ? '#333' : '#e0d8c9')

              Text(this.cacheSize)
                .fontSize(14)
                .fontColor(this.isLightMode ? '#666' : '#8a7f6e')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .border({
              width: { bottom: 1 },
              color: this.isLightMode ? '#ddd' : '#222'
            })
            .onClick(() => {
              this.cacheSize = '0MB';
            })

            // 关于我们
            Row() {
              Text($r('app.string.about_us'))
                .fontSize(14)
                .fontColor(this.isLightMode ? '#333' : '#e0d8c9')

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(this.isLightMode ? '#666' : '#8a7f6e')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isLightMode ? '#f5f1e8' : 'transparent')
  }
}
