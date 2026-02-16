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
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { Book } from '../models/Book';
import { Logger } from '../utils/Logger';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import common from '@ohos.app.ability.common';

@ComponentV2
export struct BookshelfPage {
  @Local isLightMode: boolean = true;
  @Local activeTabIndex: number = 0;
  @Local bookList: Book[] = [];
  @Local isLoading: boolean = false;
  
  private isComponentActive: boolean = false;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isComponentActive = true;
    this.isLightMode = themeManager.isLightTheme();
    this.activeTabIndex = 0;
    themeManager.addListener(this.themeListener);
    
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    viewModelManager.setContext(context);
    
    this.loadBooks();
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    this.bookList = [];
  }

  async loadBooks(): Promise<void> {
    if (!this.isComponentActive) return;
    
    this.isLoading = true;
    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      this.bookList = await bookViewModel.loadAllBooks();
    } catch (error) {
      Logger.error('BookshelfPage', `加载书籍失败: ${error}`);
    } finally {
      if (this.isComponentActive) {
        this.isLoading = false;
      }
    }
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

        Text($r('app.string.bookshelf'))
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

      Row() {
        Column() {
          Text($r('app.string.recent_read'))
            .fontSize(14)
            .fontColor(this.activeTabIndex === 0 ?
              DesignSystem.getPrimaryColor(this.isLightMode) :
              DesignSystem.getSecondaryTextColor(this.isLightMode))
            .padding({ top: 12, bottom: 10 })
            .onClick(() => {
              this.activeTabIndex = 0;
            })

          Row()
            .width(24)
            .height(2)
            .borderRadius(1)
            .backgroundColor(this.activeTabIndex === 0 ?
              DesignSystem.getPrimaryColor(this.isLightMode) :
              Color.Transparent)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text($r('app.string.favorites'))
            .fontSize(14)
            .fontColor(this.activeTabIndex === 1 ?
              DesignSystem.getPrimaryColor(this.isLightMode) :
              DesignSystem.getSecondaryTextColor(this.isLightMode))
            .padding({ top: 12, bottom: 10 })
            .onClick(() => {
              this.activeTabIndex = 1;
            })

          Row()
            .width(24)
            .height(2)
            .borderRadius(1)
            .backgroundColor(this.activeTabIndex === 1 ?
              DesignSystem.getPrimaryColor(this.isLightMode) :
              Color.Transparent)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .border({
        width: { bottom: 1 },
        color: DesignSystem.getBorderColor(this.isLightMode)
      })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(DesignSystem.getPrimaryColor(this.isLightMode))
          Text('加载中...')
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ top: 10 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.bookList.length === 0) {
        Column() {
          Text('📚')
            .fontSize(48)
            .margin({ bottom: 16 })
          Text('书架空空如也')
            .fontSize(16)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ bottom: 8 })
          Text('去搜索页面添加书籍吧')
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        }
        .width('100%')
        .height(300)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.bookList, (book: Book) => {
            ListItem() {
              Row() {
                if (book.cover) {
                  Image(book.cover)
                    .width(60)
                    .height(80)
                    .borderRadius(6)
                } else {
                  Row() {
                    Text('📖')
                      .fontSize(24)
                      .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
                  }
                  .width(60)
                  .height(80)
                  .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                  .borderRadius(6)
                  .justifyContent(FlexAlign.Center)
                }

                Column() {
                  Text(book.name)
                    .fontSize(16)
                    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                    .fontWeight(600)
                    .margin({ bottom: 4 })

                  if (book.author) {
                    Text(book.author)
                      .fontSize(12)
                      .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                      .margin({ bottom: 8 })
                  }

                  Row() {
                    Progress({
                      value: book.readProgress,
                      total: 100,
                      type: ProgressType.Linear
                    })
                      .width('100%')
                      .height(4)
                      .color(DesignSystem.getPrimaryColor(this.isLightMode))
                      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                      .margin({ right: 10 })

                    Text(`${book.readProgress}%`)
                      .fontSize(11)
                      .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
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
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .onClick(() => {
                try {
                  router.pushUrl({
                    url: 'pages/BookDetailPage',
                    params: {
                      bookId: book.id
                    }
                  });
                  hilog.info(0, 'BookshelfPage', 'push page success');
                } catch (err) {
                  hilog.error(0, 'BookshelfPage', `pushPage failed: ${err}`);
                }
              })
            }
          }, (book: Book) => book.id)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 20, right: 20 })
        .margin({ top: 15 })
        .cachedCount(5)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }
}
