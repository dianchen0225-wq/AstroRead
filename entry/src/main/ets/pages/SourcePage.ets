@ComponentV2
export struct SourcePage {
  @Param isLightMode: boolean = true;
  @Local sourceList: SourceItemData[] = [
    { name: '笔趣阁', status: '正常', enabled: true },
    { name: '起点中文网', status: '正常', enabled: true },
    { name: '番茄小说', status: '正常', enabled: false }
  ];

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
              Image($r('app.media.ic_add'))
                .width(16)
                .height(16)
                .fillColor(this.isLightMode ? '#333' : '#e0d8c9')
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
          })

          Button() {
            Row() {
              Image($r('app.media.ic_refresh'))
                .width(16)
                .height(16)
                .fillColor(this.isLightMode ? '#333' : '#e0d8c9')
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

class SourceItemData {
  name: string = '';
  status: string = '';
  enabled: boolean = false;
}
