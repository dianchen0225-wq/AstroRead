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
export struct SettingsPage {
  @Local isLightMode: boolean = true;
  @Local fontSize: number = 16;
  @Local cacheSize: string = '128MB';
  @Local autoUpdate: boolean = true;
  @Local readModeIndex: number = 0;
  
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
  }
  
  build() {
    Column() {
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

        Text($r('app.string.settings'))
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

      Scroll() {
        Column() {
          Column() {
            Text($r('app.string.reading_settings'))
              .fontSize(14)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .fontWeight(600)
              .margin({ bottom: 12 })
              .width('100%')

            Row() {
              Text($r('app.string.reading_mode'))
                .fontSize(14)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

              Text(this.isLightMode ? '白天模式' : '夜间模式')
                .fontSize(14)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .borderRadius(8)
                .border({
                  width: 1,
                  color: DesignSystem.getBorderColor(this.isLightMode)
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .border({
              width: { bottom: 1 },
              color: DesignSystem.getBorderColor(this.isLightMode)
            })

            Row() {
              Text($r('app.string.font_size'))
                .fontSize(14)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

              Row() {
                Button() {
                  Text('A-')
                    .fontSize(14)
                    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                }
                .width(32)
                .height(32)
                .borderRadius(16)
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .border({
                  width: 1,
                  color: DesignSystem.getBorderColor(this.isLightMode)
                })
                .onClick(() => {
                  if (this.fontSize > 12) {
                    this.fontSize--;
                  }
                })

                Text(`${this.fontSize}px`)
                  .fontSize(12)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  .width(40)
                  .textAlign(TextAlign.Center)

                Button() {
                  Text('A+')
                    .fontSize(14)
                    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                }
                .width(32)
                .height(32)
                .borderRadius(16)
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .border({
                  width: 1,
                  color: DesignSystem.getBorderColor(this.isLightMode)
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

          Column() {
            Text($r('app.string.app_settings'))
              .fontSize(14)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .fontWeight(600)
              .margin({ bottom: 12 })
              .width('100%')

            Row() {
              Text($r('app.string.auto_update'))
                .fontSize(14)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

              Toggle({ type: ToggleType.Switch, isOn: this.autoUpdate })
                .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
                .onChange((isOn: boolean) => {
                  this.autoUpdate = isOn;
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .border({
              width: { bottom: 1 },
              color: DesignSystem.getBorderColor(this.isLightMode)
            })

            Row() {
              Text($r('app.string.clear_cache'))
                .fontSize(14)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

              Text(this.cacheSize)
                .fontSize(14)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .border({
              width: { bottom: 1 },
              color: DesignSystem.getBorderColor(this.isLightMode)
            })
            .onClick(() => {
              this.cacheSize = '0MB';
            })

            Row() {
              Text($r('app.string.about_us'))
                .fontSize(14)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

              Text('›')
                .fontSize(20)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
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
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }
}
