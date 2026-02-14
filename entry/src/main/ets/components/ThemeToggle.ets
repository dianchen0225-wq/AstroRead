/*
 * Copyright (c) [2025] [Your Company Name]
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * 主题切换组件
 * 支持亮色/暗黑模式切换
 */

import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';

@Component
export struct ThemeToggle {
  @State isDarkMode: boolean = themeManager.isDarkTheme();

  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isDarkMode = isDark;
  };

  aboutToAppear(): void {
    themeManager.addListener(this.themeListener);
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  build() {
    Button() {
      Row() {
        Text(this.isDarkMode ? '☀️' : '🌙')
          .fontSize(18)
          .fontColor(DesignSystem.getPrimaryTextColor(!this.isDarkMode))

        Text(this.isDarkMode ? '亮色模式' : '暗黑模式')
          .fontSize(14)
          .fontColor(DesignSystem.getPrimaryTextColor(!this.isDarkMode))
          .fontWeight(FontWeight.Medium)
          .margin({ left: 8 })
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 12 })
    }
    .height(36)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(!this.isDarkMode))
    .borderRadius(18)
    .onClick(() => {
      themeManager.toggleTheme();
    })
    .animation({
      duration: 300,
      curve: Curve.EaseOut,
    })
  }
}