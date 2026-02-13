@ComponentV2
export struct SearchPage {
  @Param isLightMode: boolean = true;
  @Local searchText: string = '';
  @Local searchHistory: string[] = ['斗破苍穹', '凡人修仙传', '三体', '活着'];
  @Local hotSearchList: string[] = ['完美世界', '雪中悍刀行', '诡秘之主', '庆余年', '赘婿'];

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

        Text($r('app.string.search_books'))
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
          // 搜索栏
          Row() {
            Image($r('app.media.ic_search'))
              .width(18)
              .height(18)
              .fillColor(this.isLightMode ? '#666' : '#8a7f6e')
              .margin({ right: 10 })

            TextInput({ placeholder: $r('app.string.search_placeholder'), text: this.searchText })
              .layoutWeight(1)
              .backgroundColor(Color.Transparent)
              .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
              .placeholderColor(this.isLightMode ? '#666' : '#8a7f6e')
              .onChange((value: string) => {
                this.searchText = value;
              })

            Button($r('app.string.search_button'))
              .fontSize(14)
              .fontColor('#fff')
              .backgroundColor(this.isLightMode ? '#8a6d3b' : '#d4b483')
              .borderRadius(8)
              .padding({ left: 15, right: 15, top: 8, bottom: 8 })
              .margin({ left: 10 })
              .onClick(() => {
                if (this.searchText.trim()) {
                  console.info(`搜索: ${this.searchText}`);
                }
              })
          }
          .width('100%')
          .padding(15)
          .borderRadius(12)
          .backgroundColor(this.isLightMode ? '#f0ebe0' : '#1e1e1e')
          .border({
            width: 1,
            color: this.isLightMode ? '#ddd' : '#2a2a2a'
          })
          .margin({ bottom: 20 })

          // 搜索历史
          Column() {
            Row() {
              Text($r('app.string.search_history'))
                .fontSize(14)
                .fontColor(this.isLightMode ? '#666' : '#b8ad9a')
                .fontWeight(500)

              Blank()

              Text($r('app.string.clear_history'))
                .fontSize(12)
                .fontColor(this.isLightMode ? '#666' : '#8a7f6e')
                .onClick(() => {
                  this.searchHistory = [];
                })
            }
            .width('100%')
            .margin({ bottom: 12 })

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.searchHistory, (item: string) => {
                Text(item)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor(this.isLightMode ? '#f0ebe0' : '#1e1e1e')
                  .borderRadius(15)
                  .fontSize(12)
                  .fontColor(this.isLightMode ? '#666' : '#8a7f6e')
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => {
                    this.searchText = item;
                  })
              })
            }
          }
          .width('100%')
          .margin({ bottom: 25 })

          // 热门搜索
          Column() {
            Text($r('app.string.hot_search'))
              .width('100%')
              .fontSize(14)
              .fontColor(this.isLightMode ? '#666' : '#b8ad9a')
              .fontWeight(500)
              .margin({ bottom: 12 })

            Column() {
              ForEach(this.hotSearchList, (item: string, index: number) => {
                Row() {
                  Text((index + 1).toString())
                    .width(20)
                    .height(20)
                    .borderRadius(10)
                    .backgroundColor(this.getRankColor(index))
                    .fontColor('#121212')
                    .fontSize(12)
                    .fontWeight(600)
                    .textAlign(TextAlign.Center)
                    .margin({ right: 12 })

                  Text(item)
                    .fontSize(14)
                    .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
                }
                .width('100%')
                .margin({ bottom: 12 })
              })
            }
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
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

  getRankColor(index: number): string {
    switch (index) {
      case 0:
        return this.isLightMode ? '#e8d9b0' : '#d4b483';
      case 1:
        return this.isLightMode ? '#ede0c3' : '#e0c595';
      case 2:
        return this.isLightMode ? '#f2e8d6' : '#eddfc8';
      default:
        return this.isLightMode ? '#e8d9b0' : '#d4b483';
    }
  }
}
