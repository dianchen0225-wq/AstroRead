import { DesignSystem } from '../../common/DesignSystem';
import { Chapter } from '../../models/Book';
import { ChapterListDataSource } from './ChapterListDataSource';

@ComponentV2
export struct ChapterListComponent {
  @Param chapterIndex: number = 0;
  @Param isLightMode: boolean = true;
  @Param searchKeyword: string = '';
  @Require @Param chapterDataSource: ChapterListDataSource;
  @Require @Param onJumpToChapter: (index: number) => void;
  @Require @Param onSearchKeywordChange: (keyword: string) => void;
  @Require @Param onClose: () => void;

  private get filteredChapters(): Chapter[] {
    const allChapters: Chapter[] = this.chapterDataSource.getChapters();
    if (!this.searchKeyword) {
      return allChapters;
    }
    return allChapters.filter((chapter: Chapter): boolean => chapter.title.includes(this.searchKeyword));
  }

  build() {
    Column() {
      Row() {
        Text('目录')
          .fontSize(18)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(600)
          .layoutWeight(1)

        Button() {
          Text('✕')
            .fontSize(20)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        }
        .width(32)
        .height(32)
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .onClick(() => {
          this.onClose();
        })
      }
      .width('100%')
      .padding(15)
      .alignItems(VerticalAlign.Center)

      TextInput({ placeholder: '搜索章节', text: this.searchKeyword })
        .width('100%')
        .height(40)
        .margin({ left: 15, right: 15, bottom: 10 })
        .backgroundColor(DesignSystem.getTertiaryBackgroundColor(this.isLightMode))
        .onChange((value: string) => {
          this.onSearchKeywordChange(value);
        })

      List() {
        LazyForEach(this.chapterDataSource, (chapter: Chapter, index: number) => {
          ListItem() {
            Row() {
              Text(chapter.title)
                .fontSize(14)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)

              if (chapter.isVip) {
                Text('VIP')
                  .fontSize(10)
                  .fontColor(DesignSystem.Colors.text.primary.light)
                  .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                  .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                  .borderRadius(4)
                  .margin({ left: 8 })
              }
            }
            .width('100%')
            .padding(12)
            .borderRadius(8)
            .backgroundColor(index === this.chapterIndex ? DesignSystem.getSecondaryBackgroundColor(this.isLightMode) : Color.Transparent)
            .onClick(() => {
              this.onJumpToChapter(index);
            })
          }
        }, (chapter: Chapter) => chapter.id)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 15, right: 15 })
      .scrollBar(BarState.Auto)
      .cachedCount(10)
    }
    .width(320)
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    .alignItems(HorizontalAlign.Start)
  }
}
