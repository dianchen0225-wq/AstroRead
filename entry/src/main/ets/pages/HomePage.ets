  import { themeManager } from '../common/ThemeManager';
  import { DesignSystem } from '../common/DesignSystem';

  @ComponentV2
  export struct HomePage {
    @Local isLightMode: boolean = themeManager.isLightTheme();
    @Local buttonPressedMap: Map<string, boolean> = new Map<string, boolean>();
    @Param safeAreaTop: number = 0;

    aboutToAppear(): void {
      this.isLightMode = themeManager.isLightTheme();
      themeManager.addListener((isDark: boolean) => {
        this.isLightMode = !isDark;
      });
    }

    build() {
      Column() {
        this.buildHeader()

        this.buildAppTitle()

        this.buildCoreSection()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    }

    @Builder
    buildHeader() {
      Row() {
        this.buildThemeToggle()

        Blank()

        this.buildHeaderRight()
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: this.safeAreaTop + 12,
        bottom: 8
      })
    }

    @Builder
    buildThemeToggle() {
      Row() {
        Text('⚙️')
          .fontSize(18)
          .margin({ right: 8 })

        Text(this.isLightMode ? $r('app.string.dark_mode') : $r('app.string.light_mode'))
          .fontSize(14)
          .fontColor('#333333')
          .fontWeight(500)

        this.buildToggleSwitch()
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .borderRadius(8)
      .backgroundColor('#F0EBE0')
      .border({ width: 1, color: '#DDDDDD' })
      .onClick(() => {
        themeManager.toggleTheme();
      })
    }

    @Builder
    buildToggleSwitch() {
      Row() {
        Row()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(this.isLightMode ? '#8A6D3B' : '#999999')

        Row()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(!this.isLightMode ? '#8A6D3B' : '#999999')
      }
      .width(24)
      .height(12)
      .borderRadius(6)
      .backgroundColor('#E0D8C9')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ left: 8 })
    }

    @Builder
    buildHeaderRight() {
      Row() {
        Text($r('app.string.core_entrance'))
          .fontSize(12)
          .fontColor('#666666')
          .fontWeight(400)
      }
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(8)
      .backgroundColor('#F0EBE0')
      .border({ width: 1, color: '#DDDDDD' })
    }

    @Builder
    buildAppTitle() {
      Column() {
        Text($r('app.string.app_name'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .fontSize(26)
          .fontColor('#8A6D3B')
          .fontWeight(700)
          .letterSpacing(3)
      }
      .width('100%')
      .padding({ top: 12, bottom: 20 })
    }

    @Builder
    buildCoreSection() {
      Column() {
        Text($r('app.string.core_display'))
          .width('100%')
          .fontSize(16)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(600)
          .margin({ bottom: 16 })

        this.buildButtonGrid()
      }
      .width('100%')
      .margin(10)
      .padding({ left: 15, right: 15 })
    }

    @Builder
    buildButtonGrid() {
      Column({ space: 8 }) {
        this.buildCoreButton(
          $r('app.string.my_bookshelf'),
          $r('app.string.my_bookshelf_desc'),
          '📖',
          '1'
        )

        this.buildCoreButton(
          $r('app.string.search_books'),
          $r('app.string.search_books_desc'),
          '🔍',
          '2'
        )

        this.buildCoreButton(
          $r('app.string.source_management'),
          $r('app.string.source_management_desc'),
          '📚',
          '3'
        )

        this.buildCoreButton(
          $r('app.string.settings'),
          $r('app.string.settings_desc'),
          '⚙️',
          '4'
        )
      }
      .width('100%')
    }

    @Builder
    buildCoreButton(title: ResourceStr, desc: ResourceStr, icon: string, key: string) {
      Row() {
        Row() {
          Text(icon)
            .fontSize(18)
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor('#E0D8C9')
        .justifyContent(FlexAlign.Center)
        .margin({ right: 15 })

        Column() {
          Text(title)
            .fontSize(16)
            .fontColor('#333333')
            .fontWeight(500)
            .lineHeight(20)

          Text(desc)
            .fontSize(12)
            .fontColor('#666666')
            .lineHeight(16)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('›')
          .fontSize(24)
          .fontColor('#999999')
          .margin({ left: 10 })
      }
      .width('100%')
      .height(64)
      .padding({ top: 12, bottom: 12, left: 15, right: 15 })
      .borderRadius(8)
      .backgroundColor(this.buttonPressedMap.get(key) ? '#E6E1D6' : '#F0EBE0')
      .border({
        width: 1,
        color: '#DDDDDD'
      })
      .gesture(
        LongPressGesture({ repeat: false })
          .onAction(() => {
            this.buttonPressedMap.set(key, true);
          })
      )
      .onClick(() => {
        this.buttonPressedMap.set(key, true);
        setTimeout(() => {
          this.buttonPressedMap.set(key, false);
        }, 150);
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.buttonPressedMap.set(key, false);
        }
      })
    }
  }
