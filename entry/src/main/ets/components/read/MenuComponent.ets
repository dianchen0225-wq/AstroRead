import { DesignSystem } from '../../common/DesignSystem';
import { Book } from '../../models/Book';
import { Chapter } from '../../models/Book';
import { ReadConfig } from '../../models/ReadConfig';
import { viewModelManager } from '../../viewmodel/ViewModelManager';

@ComponentV2
export struct MenuComponent {
  @Param book: Book | null = null;
  @Param chapters: Chapter[] = [];
  @Param chapterIndex: number = 0;
  @Param isLightMode: boolean = true;
  @Param showMenu: boolean = false;
  @Param menuOpacity: number = 0;
  @Param isBookmarked: boolean = false;
  @Param isCaching: boolean = false;
  @Param cachedChapterCount: number = 0;
  @Param readConfig: ReadConfig = {} as ReadConfig;
  @Require @Param onShowChapterList: () => void;
  @Require @Param onToggleBookmark: () => void;
  @Require @Param onCacheChapters: () => void;
  @Require @Param onShowSettings: () => void;
  @Require @Param onPrevChapter: () => void;
  @Require @Param onNextChapter: () => void;
  @Require @Param onJumpToChapter: (index: number) => void;
  @Require @Param onReadConfigChange: () => void;

  private getChapterProgress(): number {
    if (this.chapters.length === 0) {
      return 0;
    }
    return ((this.chapterIndex + 1) / this.chapters.length) * 100;
  }

  private getPageTurnModeText(mode: string): string {
    switch (mode) {
      case 'cover': return '覆盖';
      case 'slide': return '滑动';
      case 'scroll': return '滚动';
      case 'simulation': return '仿真';
      default: return mode;
    }
  }

  build() {
    Column() {
      Column() {
        Row() {
          if (this.book) {
            Column() {
              Text(this.book.name)
                .fontSize(16)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .fontWeight(600)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              if (this.chapters.length > this.chapterIndex) {
                Text(this.chapters[this.chapterIndex].title)
                  .fontSize(12)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 4 })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: DesignSystem.Spacing.sm })
          }
        }
        .width('100%')
        .padding({ left: DesignSystem.Spacing.md, right: DesignSystem.Spacing.lg, top: 15, bottom: 15 })
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .border({
          width: { bottom: 1 },
          color: DesignSystem.getBorderColor(this.isLightMode)
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column() {
        Row() {
          Text('A-')
            .fontSize(16)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(8)
            .margin({ right: 8 })
            .onClick(() => {
              this.readConfig.fontSize = Math.max(this.readConfig.fontSize - 2, 12);
              viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
              this.onReadConfigChange();
            })

          Text('A+')
            .fontSize(16)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(8)
            .margin({ right: 16 })
            .onClick(() => {
              this.readConfig.fontSize = Math.min(this.readConfig.fontSize + 2, 32);
              viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
              this.onReadConfigChange();
            })

          Blank()

          Text('目录')
            .fontSize(14)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(8)
            .margin({ right: 8 })
            .onClick(() => {
              this.onShowChapterList();
            })

          Text(this.isBookmarked ? '书签' : '书签')
            .fontSize(14)
            .fontColor(this.isBookmarked ? DesignSystem.getPrimaryColor(this.isLightMode) : DesignSystem.getPrimaryTextColor(this.isLightMode))
            .backgroundColor(this.isBookmarked ? DesignSystem.getTertiaryBackgroundColor(this.isLightMode) : DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(8)
            .margin({ right: 8 })
            .onClick(() => {
              this.onToggleBookmark();
            })

          Text(this.isCaching ? `缓存中${this.cachedChapterCount}` : '缓存')
            .fontSize(14)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(8)
            .margin({ right: 8 })
            .onClick(() => {
              this.onCacheChapters();
            })

          Text('设置')
            .fontSize(14)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(8)
            .onClick(() => {
              this.onShowSettings();
            })
        }
        .width('100%')
        .padding({ left: 15, right: 15, top: 12, bottom: 12 })

        Row() {
          Text('上一章')
            .fontSize(14)
            .fontColor(this.chapterIndex > 0 ? DesignSystem.getPrimaryTextColor(this.isLightMode) : '#999')
            .backgroundColor(this.chapterIndex > 0 ? DesignSystem.getSecondaryBackgroundColor(this.isLightMode) : 'transparent')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .borderRadius(8)
            .onClick(() => {
              if (this.chapterIndex > 0) {
                this.onPrevChapter();
              }
            })

          Column() {
            Text(`${this.getChapterProgress().toFixed(0)}%`)
              .fontSize(12)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))

            Slider({
              value: this.getChapterProgress(),
              min: 0,
              max: 100,
              step: 1,
              style: SliderStyle.OutSet
            })
              .width('100%')
              .height(4)
              .margin({ top: 4 })
              .blockColor(DesignSystem.getPrimaryColor(this.isLightMode))
              .trackColor(DesignSystem.getBorderColor(this.isLightMode))
              .trackThickness(4)
              .blockSize({ width: 16, height: 16 })
              .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
              .onChange((value: number) => {
                const targetChapterIndex = Math.floor((value / 100) * this.chapters.length);
                if (targetChapterIndex >= 0 && targetChapterIndex < this.chapters.length && targetChapterIndex !== this.chapterIndex) {
                  this.onJumpToChapter(targetChapterIndex);
                }
              })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          Text('下一章')
            .fontSize(14)
            .fontColor(this.chapterIndex < this.chapters.length - 1 ? DesignSystem.getPrimaryTextColor(this.isLightMode) : '#999')
            .backgroundColor(this.chapterIndex < this.chapters.length - 1 ? DesignSystem.getSecondaryBackgroundColor(this.isLightMode) : 'transparent')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .borderRadius(8)
            .onClick(() => {
              if (this.chapterIndex < this.chapters.length - 1) {
                this.onNextChapter();
              }
            })
        }
        .width('100%')
        .padding({ left: 15, right: 15, top: 8, bottom: 12 })
        .justifyContent(FlexAlign.SpaceBetween)

        Row() {
          Text('翻页模式:')
            .fontSize(12)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))

          ForEach(['cover', 'slide', 'scroll'], (mode: string) => {
            Text(this.getPageTurnModeText(mode))
              .fontSize(12)
              .fontColor(this.readConfig.pageTurnMode === mode ? Color.White : DesignSystem.getPrimaryTextColor(this.isLightMode))
              .backgroundColor(this.readConfig.pageTurnMode === mode ? DesignSystem.getPrimaryColor(this.isLightMode) : DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .borderRadius(6)
              .margin({ left: 8 })
              .onClick(() => {
                this.readConfig.pageTurnMode = mode as 'cover' | 'slide' | 'scroll' | 'simulation';
                viewModelManager.getReadConfigViewModel().updateReadConfig(this.readConfig);
              })
          })
        }
        .width('100%')
        .padding({ left: 15, right: 15, bottom: 15 })
      }
      .width('100%')
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .border({
        width: { top: 1 },
        color: DesignSystem.getBorderColor(this.isLightMode)
      })
    }
    .width('100%')
  }
}
