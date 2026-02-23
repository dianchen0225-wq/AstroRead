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
import { NavigationManager } from '../common/NavigationManager';

interface SettingItem {
  icon: string;
  title: string;
  subtitle?: string;
  action?: () => void;
  trailing?: 'arrow' | 'toggle' | 'text' | 'custom';
  trailingValue?: string;
}

@ComponentV2
export struct SettingsPage {
  @Local isLightMode: boolean = true;
  @Local fontSize: number = 16;
  @Local cacheSize: string = '128MB';
  @Local autoUpdate: boolean = true;
  @Local pressedItem: string = '';
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
  }

  private getReadingSettings(): SettingItem[] {
    const items: SettingItem[] = [
      {
        icon: '🌙',
        title: '阅读模式',
        subtitle: this.isLightMode ? '白天模式' : '夜间模式',
        trailing: 'text',
        trailingValue: this.isLightMode ? '白天' : '夜间'
      },
      {
        icon: '🔤',
        title: '字体大小',
        trailing: 'custom',
        trailingValue: `${this.fontSize}px`
      }
    ];
    return items;
  }

  private getAppSettings(): SettingItem[] {
    const items: SettingItem[] = [
      {
        icon: '🔄',
        title: '自动更新',
        trailing: 'toggle'
      },
      {
        icon: '🗑️',
        title: '清除缓存',
        trailing: 'text',
        trailingValue: this.cacheSize
      },
      {
        icon: '📋',
        title: '调试日志',
        trailing: 'arrow'
      },
      {
        icon: 'ℹ️',
        title: '关于我们',
        trailing: 'arrow'
      }
    ];
    return items;
  }
  
  build() {
    Column() {
      this.buildHeader()

      Scroll() {
        Column() {
          this.buildSection('阅读设置', this.getReadingSettings())
          
          this.buildSection('应用设置', this.getAppSettings())
          
          this.buildAppInfo()
        }
        .width('100%')
        .padding(DesignSystem.Spacing.xl)
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

  @Builder
  buildHeader() {
    Row() {
      Row() {
        Text('‹')
          .fontSize(DesignSystem.Typography.size.xl)
          .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
      }
      .width(40)
      .height(40)
      .borderRadius(DesignSystem.BorderRadius.md)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .justifyContent(FlexAlign.Center)
      .border({
        width: 1,
        color: DesignSystem.getBorderColor(this.isLightMode)
      })
      .onClick(() => {
        NavigationManager.getInstance().navigateBack();
      })

      Text($r('app.string.settings'))
        .fontSize(DesignSystem.Typography.size.xl)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.bold)
        .layoutWeight(1)
        .margin({ left: DesignSystem.Spacing.md })
    }
    .width('100%')
    .padding({
      left: DesignSystem.Spacing.xl,
      right: DesignSystem.Spacing.xl,
      top: this.safeAreaTop + DesignSystem.Spacing.lg,
      bottom: DesignSystem.Spacing.lg
    })
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: { bottom: 1 },
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
  }

  @Builder
  buildSection(title: string, items: SettingItem[]) {
    Column() {
      Text(title)
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.semibold)
        .margin({ bottom: DesignSystem.Spacing.md })
        .width('100%')
        .letterSpacing(1)

      Column() {
        ForEach(items, (item: SettingItem, index: number) => {
          this.buildSettingItem(item, index === items.length - 1)
        })
      }
      .width('100%')
      .borderRadius(DesignSystem.BorderRadius.md)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .border({
        width: 1,
        color: DesignSystem.getBorderColor(this.isLightMode)
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: DesignSystem.Spacing.xl })
  }

  @Builder
  buildSettingItem(item: SettingItem, isLast: boolean) {
    Row() {
      Row() {
        Text(item.icon)
          .fontSize(DesignSystem.IconSize.sm)
      }
      .width(36)
      .height(36)
      .borderRadius(DesignSystem.BorderRadius.sm)
      .backgroundColor(DesignSystem.getHoverColor(this.isLightMode))
      .justifyContent(FlexAlign.Center)
      .margin({ right: DesignSystem.Spacing.md })

      Column() {
        Text(item.title)
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.medium)

        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ top: DesignSystem.Spacing.xs })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.buildTrailing(item)
    }
    .width('100%')
    .padding(DesignSystem.Spacing.lg)
    .border({
      width: isLast ? 0 : { bottom: 1 },
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .backgroundColor(this.pressedItem === item.title ?
      DesignSystem.getHoverColor(this.isLightMode) :
      Color.Transparent)
    .opacity(this.pressedItem === item.title ? 0.9 : 1)
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      this.handleItemAction(item);
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedItem = item.title;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedItem = '';
      }
    })
  }

  @Builder
  buildTrailing(item: SettingItem) {
    if (item.trailing === 'arrow') {
      Text('›')
        .fontSize(DesignSystem.Typography.size.xl)
        .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
    } else if (item.trailing === 'toggle') {
      Toggle({ type: ToggleType.Switch, isOn: this.autoUpdate })
        .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
        .onChange((isOn: boolean) => {
          this.autoUpdate = isOn;
        })
    } else if (item.trailing === 'text' && item.trailingValue) {
      Text(item.trailingValue)
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .padding({
          left: DesignSystem.Spacing.md,
          right: DesignSystem.Spacing.md,
          top: DesignSystem.Spacing.xs,
          bottom: DesignSystem.Spacing.xs
        })
        .borderRadius(DesignSystem.BorderRadius.sm)
        .backgroundColor(DesignSystem.getHoverColor(this.isLightMode))
    } else if (item.trailing === 'custom' && item.title === '字体大小') {
      Row() {
        Row() {
          Text('A-')
            .fontSize(DesignSystem.Typography.size.sm)
            .fontColor(this.fontSize > 12 ?
              DesignSystem.getPrimaryTextColor(this.isLightMode) :
              DesignSystem.getTertiaryTextColor(this.isLightMode))
        }
        .width(32)
        .height(32)
        .borderRadius(DesignSystem.BorderRadius.sm)
        .backgroundColor(DesignSystem.getHoverColor(this.isLightMode))
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.fontSize > 12) {
            this.fontSize--;
          }
        })

        Text(`${this.fontSize}`)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.medium)
          .width(40)
          .textAlign(TextAlign.Center)

        Row() {
          Text('A+')
            .fontSize(DesignSystem.Typography.size.sm)
            .fontColor(this.fontSize < 24 ?
              DesignSystem.getPrimaryTextColor(this.isLightMode) :
              DesignSystem.getTertiaryTextColor(this.isLightMode))
        }
        .width(32)
        .height(32)
        .borderRadius(DesignSystem.BorderRadius.sm)
        .backgroundColor(DesignSystem.getHoverColor(this.isLightMode))
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.fontSize < 24) {
            this.fontSize++;
          }
        })
      }
    }
  }

  private handleItemAction(item: SettingItem): void {
    switch (item.title) {
      case '阅读模式':
        themeManager.toggleTheme();
        break;
      case '清除缓存':
        this.cacheSize = '0MB';
        break;
      case '调试日志':
        NavigationManager.getInstance().navigateTo('DebugLogPage');
        break;
      case '关于我们':
        break;
    }
  }

  @Builder
  buildAppInfo() {
    Column() {
      Text('AstroRead')
        .fontSize(DesignSystem.Typography.size.lg)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.bold)
        .letterSpacing(2)

      Text('版本 1.0.0')
        .fontSize(DesignSystem.Typography.size.xs)
        .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
        .margin({ top: DesignSystem.Spacing.xs })

      Text('Made with ❤️ for readers')
        .fontSize(DesignSystem.Typography.size.xs)
        .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
        .margin({ top: DesignSystem.Spacing.sm })
    }
    .width('100%')
    .padding(DesignSystem.Spacing.xxl)
    .alignItems(HorizontalAlign.Center)
  }
}
