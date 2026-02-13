@ComponentV2
export struct HomePage {
  @Param isLightMode: boolean = true;
  @Param onModeChange: () => void = () => {};

  @Local buttonScaleMap: Map<string, number> = new Map<string, number>();

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text(this.isLightMode ? $r('app.string.dark_mode') : $r('app.string.light_mode'))
          .fontSize(15)
          .fontColor(this.isLightMode ? '#8a6d3b' : '#d4b483')
          .fontWeight(500)
          .onClick(() => {
            this.onModeChange();
          })

        Blank()

        Text($r('app.string.core_entrance'))
          .fontSize(14)
          .fontColor(this.isLightMode ? '#666' : '#8a7f6e')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 10 })

      // 应用标题
      Text($r('app.string.app_name'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ bottom: 20 })
        .fontSize(28)
        .fontColor(this.isLightMode ? '#8a6d3b' : '#d4b483')
        .fontWeight(700)
        .letterSpacing(1)

      // 核心功能区
      Column() {
        Text($r('app.string.core_display'))
          .width('100%')
          .fontSize(18)
          .fontColor(this.isLightMode ? '#666' : '#b8ad9a')
          .fontWeight(500)
          .margin({ bottom: 20 })

        // 功能按钮网格
        Grid() {
          GridItem() {
            this.buildCoreButton($r('app.string.my_bookshelf'), $r('app.string.my_bookshelf_desc'),
              $r('app.media.ic_book'), 1)
          }

          GridItem() {
            this.buildCoreButton($r('app.string.search_books'), $r('app.string.search_books_desc'),
              $r('app.media.ic_search'), 2)
          }

          GridItem() {
            this.buildCoreButton($r('app.string.source_management'), $r('app.string.source_management_desc'),
              $r('app.media.ic_source'), 3)
          }

          GridItem() {
            this.buildCoreButton($r('app.string.settings'), $r('app.string.settings_desc'),
              $r('app.media.ic_settings'), 4)
          }
        }
        .columnsTemplate('1fr 1fr')
        .rowsGap(15)
        .columnsGap(15)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isLightMode ? '#f5f1e8' : 'transparent')
  }

  @Builder
  buildCoreButton(title: ResourceStr, desc: ResourceStr, icon: Resource, pageIndex: number) {
    Row() {
      // 图标
      Row() {
        Image(icon)
          .width(20)
          .height(20)
          .fillColor(this.isLightMode ? '#8a6d3b' : '#d4b483')
      }
      .width(40)
      .height(40)
      .backgroundColor(this.isLightMode ? '#e0d8c9' : '#2a2a2a')
      .borderRadius(8)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 15 })

      // 文字内容
      Column() {
        Text(title)
          .fontSize(16)
          .fontColor(this.isLightMode ? '#333' : '#e0d8c9')
          .fontWeight(600)
          .margin({ bottom: 5 })

        Text(desc)
          .fontSize(12)
          .fontColor(this.isLightMode ? '#666' : '#8a7f6e')
          .lineHeight(1.4)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 箭头
      Image($r('app.media.ic_arrow_right'))
        .width(14)
        .height(14)
        .fillColor(this.isLightMode ? '#666' : '#8a7f6e')
    }
    .width('100%')
    .padding({ top: 18, bottom: 18, left: 15, right: 15 })
    .borderRadius(12)
    .backgroundColor(this.isLightMode ? '#f0ebe0' : '#1e1e1e')
    .border({
      width: 1,
      color: this.isLightMode ? '#ddd' : '#2a2a2a'
    })
    .scale({
      x: this.buttonScaleMap.get(pageIndex.toString()) ?? 1,
      y: this.buttonScaleMap.get(pageIndex.toString()) ?? 1
    })
    .onClick(() => {
      this.handleButtonClick(pageIndex.toString());
    })
  }

  handleButtonClick(key: string): void {
    const scale = 0.98;
    this.buttonScaleMap.set(key, scale);
    
    setTimeout(() => {
      this.buttonScaleMap.set(key, 1);
    }, 150);
  }
}
