/**
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';

@ComponentV2
export struct HomePage {
  @Local isLightMode: boolean = true;
  @Local buttonPressedMap: Map<string, boolean> = new Map<string, boolean>();
  @Param safeAreaTop: number = 0;
  
  private isComponentActive: boolean = false;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isComponentActive = true;
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    this.buttonPressedMap.clear();
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
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(500)

      this.buildToggleSwitch()
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .borderRadius(8)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({ width: 1, color: DesignSystem.getBorderColor(this.isLightMode) })
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
        .backgroundColor(this.isLightMode ? DesignSystem.getPrimaryColor(this.isLightMode) : DesignSystem.getSecondaryTextColor(this.isLightMode))

      Row()
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor(!this.isLightMode ? DesignSystem.getPrimaryColor(this.isLightMode) : DesignSystem.getSecondaryTextColor(this.isLightMode))
    }
    .width(24)
    .height(12)
    .borderRadius(6)
    .backgroundColor(DesignSystem.getBorderColor(this.isLightMode))
    .justifyContent(FlexAlign.SpaceEvenly)
    .margin({ left: 8 })
  }

  @Builder
  buildHeaderRight() {
    Row() {
      Text($r('app.string.core_entrance'))
        .fontSize(12)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .fontWeight(400)
    }
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .borderRadius(8)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({ width: 1, color: DesignSystem.getBorderColor(this.isLightMode) })
  }

  @Builder
  buildAppTitle() {
    Column() {
      Text($r('app.string.app_name'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontSize(26)
        .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
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
      .backgroundColor(DesignSystem.getBorderColor(this.isLightMode))
      .justifyContent(FlexAlign.Center)
      .margin({ right: 15 })

      Column() {
        Text(title)
          .fontSize(16)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(500)
          .lineHeight(20)

        Text(desc)
          .fontSize(12)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .lineHeight(16)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize(24)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ left: 10 })
    }
    .width('100%')
    .height(64)
    .padding({ top: 12, bottom: 12, left: 15, right: 15 })
    .borderRadius(8)
    .backgroundColor(this.buttonPressedMap.get(key) ? 
      DesignSystem.getBorderColor(this.isLightMode) : 
      DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
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
