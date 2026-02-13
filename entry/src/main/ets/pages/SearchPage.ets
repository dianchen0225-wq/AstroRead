
    import { themeManager } from '../common/ThemeManager';
    import { DesignSystem } from '../common/DesignSystem';

    interface RankColor {
      light: string;
      dark: string;
    }
    @ComponentV2
    export struct SearchPage {
      @Local isLightMode: boolean = true;
      @Local searchText: string = '';
      @Local searchHistory: string[] = ['斗破苍穹', '凡人修仙传', '三体', '活着'];
      @Local hotSearchList: string[] = ['完美世界', '雪中悍刀行', '诡秘之主', '庆余年', '赘婿'];

      aboutToAppear(): void {
          // 初始化主题
          this.isLightMode = themeManager.isLightTheme();
          // 初始化搜索相关属性
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
                .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
            }
            .width(32)
            .height(32)
            .borderRadius(16)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .justifyContent(FlexAlign.Center)
            .margin({ right: 15 })

            Text($r('app.string.search_books'))
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

          // 内容区域
          Scroll() {
            Column() {
              // 搜索栏
              Row() {
                Text('🔍')
                  .fontSize(18)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  .margin({ right: 10 })

                TextInput({ placeholder: $r('app.string.search_placeholder'), text: this.searchText })
                  .layoutWeight(1)
                  .backgroundColor(Color.Transparent)
                  .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                  .placeholderColor(this.isLightMode ? '#666' : '#8a7f6e')
                  .onChange((value: string) => {
                    this.searchText = value;
                  })

                Button($r('app.string.search_button'))
                  .fontSize(14)
                  .fontColor(DesignSystem.Colors.text.primary.light)
                  .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
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
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .border({
                width: 1,
                color: DesignSystem.getBorderColor(this.isLightMode)
              })
              .margin({ bottom: 20 })

              // 搜索历史
              Column() {
                Row() {
                  Text($r('app.string.search_history'))
                    .fontSize(14)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                    .fontWeight(500)

                  Blank()

                  Text($r('app.string.clear_history'))
                    .fontSize(12)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
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
                      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                      .borderRadius(15)
                      .fontSize(12)
                      .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
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
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
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
                        .fontColor(DesignSystem.Colors.text.primary.light)
                        .fontSize(12)
                        .fontWeight(600)
                        .textAlign(TextAlign.Center)
                        .margin({ right: 12 })

                      Text(item)
                        .fontSize(14)
                        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
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
        .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
      }
      private getRankColor(index: number): string {
          const rankColors: RankColor[] = [
            { light: '#e8d9b0', dark: '#d4b483' },
            { light: '#ede0c3', dark: '#e0c595' },
            { light: '#f2e8d6', dark: '#eddfc8' }
          ];
          const color = rankColors[index] || rankColors[0];
          return this.isLightMode ? color.light : color.dark;
        }
    }
