
    import { themeManager } from '../common/ThemeManager';

    interface BookItemData {
      title: string;
      author: string;
      progress: number;
    }

    @ComponentV2
    export struct BookshelfPage {
      @Local isLightMode: boolean = true;
      @Local activeTabIndex: number = 0;
      @Local bookList: BookItemData[] = [];

      aboutToAppear(): void {
          // 初始化主题
          this.isLightMode = themeManager.isLightTheme();
          this.activeTabIndex = 0;
          this.bookList = [
            { title: '斗破苍穹', author: '天蚕土豆', progress: 65 },
            { title: '凡人修仙传', author: '忘语', progress: 32 }
          ];
          // 监听主题变化
          themeManager.addListener((isDark: boolean) => {
            this.isLightMode = !isDark;
          });
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

            Text($r('app.string.bookshelf'))
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

          // 标签页
          Row() {
            Column() {
              Text($r('app.string.recent_read'))
                .fontSize(14)
                .fontColor(this.activeTabIndex === 0 ?
                  (this.isLightMode ? '#8a6d3b' : '#d4b483') :
                  (this.isLightMode ? '#666' : '#8a7f6e'))
                .padding({ top: 12, bottom: 10 })
                .onClick(() => {
                  this.activeTabIndex = 0;
                })

              Row()
                .width(24)
                .height(2)
                .borderRadius(1)
                .backgroundColor(this.activeTabIndex === 0 ?
                  (this.isLightMode ? '#8a6d3b' : '#d4b483') :
                  Color.Transparent)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            Column() {
              Text($r('app.string.favorites'))
                .fontSize(14)
                .fontColor(this.activeTabIndex === 1 ?
                  (this.isLightMode ? '#8a6d3b' : '#d4b483') :
                  (this.isLightMode ? '#666' : '#8a7f6e'))
                .padding({ top: 12, bottom: 10 })
                .onClick(() => {
                  this.activeTabIndex = 1;
                })

              Row()
                .width(24)
                .height(2)
                .borderRadius(1)
                .backgroundColor(this.activeTabIndex === 1 ?
                  (this.isLightMode ? '#8a6d3b' : '#d4b483') :
                  Color.Transparent)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .border({
            width: { bottom: 1 },
            color: this.isLightMode ? '#ddd' : '#222'
          })

          // 书籍列表
          List({ space: 12 }) {
            ForEach(this.bookList, (item: BookItemData) => {
              ListItem() {
                Row() {
                  Row() {
                    Text('📖')
                      .fontSize(24)
                      .fontColor(this.isLightMode ? '#8a6d3b' : '#d4b483')
                  }
                  .width(60)
                  .height(80)
                  .backgroundColor(this.isLightMode ? '#e0d8c9' : '#2a2a2a')
                  .borderRadius(6)
                  .justifyContent(FlexAlign.Center)

                  Column() {
                    Text(item.title)
                      .fontSize(16)
                      .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
                      .fontWeight(600)
                      .margin({ bottom: 4 })

                    Text(item.author)
                      .fontSize(12)
                      .fontColor(this.isLightMode ? '#666' : '#8a7f6e')
                      .margin({ bottom: 8 })

                    Row() {
                      Progress({
                        value: item.progress,
                        total: 100,
                        type: ProgressType.Linear
                      })
                        .width('100%')
                        .height(4)
                        .color(this.isLightMode ? '#8a6d3b' : '#d4b483')
                        .backgroundColor(this.isLightMode ? '#ddd' : '#2a2a2a')
                        .margin({ right: 10 })

                      Text(`${item.progress}%`)
                        .fontSize(11)
                        .fontColor(this.isLightMode ? '#666' : '#8a7f6e')
                        .width(35)
                        .textAlign(TextAlign.End)
                    }
                  }
                  .layoutWeight(1)
                  .justifyContent(FlexAlign.SpaceBetween)
                }
                .width('100%')
                .padding(15)
                .borderRadius(12)
                .backgroundColor(this.isLightMode ? '#f0ebe0' : '#1e1e1e')
                .border({
                  width: 1,
                  color: this.isLightMode ? '#ddd' : '#2a2a2a'
                })
              }
            })
          }
          .width('100%')
          .height('100%')
          .padding({ left: 20, right: 20 })
          .margin({ top: 15 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.isLightMode ? '#f5f1e8' : 'transparent')
      }
    }
