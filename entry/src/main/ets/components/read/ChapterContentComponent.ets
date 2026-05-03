import { DesignSystem } from '../../common/DesignSystem';
import { ChapterContent } from '../../models/Book';
import { ReadConfig } from '../../models/ReadConfig';

@ComponentV2
export struct ChapterContentComponent {
  @Param chapterContent: ChapterContent | null = null;
  @Param isLoading: boolean = false;
  @Param loadError: string = '';
  @Param showRetryCount: number = 0;
  @Param maxRetryCount: number = 3;
  @Param isLightMode: boolean = true;
  @Param readConfig: ReadConfig = {} as ReadConfig;
  @Param chapterTitle: string = '';
  @Require @Param scroller: Scroller;
  @Require @Param onRetry: () => void;
  @Require @Param onGoBack: () => void;
  @Require @Param onScroll: () => void;
  @Require @Param onScrollEnd: () => void;

  build() {
    Column() {
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
      } else if (this.loadError) {
        Column() {
          Text('章节加载失败')
            .fontSize(20)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .fontWeight(600)
            .margin({ bottom: 16 })

          Text(`错误详情: ${this.loadError}`)
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .textAlign(TextAlign.Center)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('80%')
            .margin({ bottom: 8 })

          Text(`重试次数: ${this.showRetryCount}/${this.maxRetryCount}`)
            .fontSize(12)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ bottom: 24 })

          Row() {
            Button('重试')
              .fontSize(16)
              .fontColor(Color.White)
              .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
              .borderRadius(8)
              .width(100)
              .height(40)
              .margin({ right: 16 })
              .enabled(this.showRetryCount < this.maxRetryCount)
              .opacity(this.showRetryCount >= this.maxRetryCount ? 0.5 : 1)
              .onClick(() => {
                this.onRetry();
              })

            Button('返回书架')
              .fontSize(16)
              .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .borderRadius(8)
              .width(100)
              .height(40)
              .onClick(() => {
                this.onGoBack();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          if (this.showRetryCount >= this.maxRetryCount) {
            Text('已达到最大重试次数，请检查网络连接或书源配置')
              .fontSize(12)
              .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
              .margin({ top: 16 })
              .textAlign(TextAlign.Center)
              .width('80%')
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding(20)
      } else if (this.chapterContent) {
        Column() {
          if (this.chapterTitle) {
            Text(this.chapterTitle)
              .fontSize(18)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .fontWeight(600)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 20, bottom: 20 })
          }
          Scroll(this.scroller) {
            Column() {
              Text(this.chapterContent.content)
                .fontSize(this.readConfig.fontSize)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .lineHeight(this.readConfig.fontSize * this.readConfig.lineSpacing)
                .width('100%')
                .padding({
                  left: this.readConfig.margins.left,
                  right: this.readConfig.margins.right,
                  top: this.readConfig.margins.top,
                  bottom: this.readConfig.margins.bottom
                })
                .letterSpacing(this.readConfig.letterSpacing)
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .scrollable(ScrollDirection.Vertical)
          .edgeEffect(EdgeEffect.Spring)
          .onScroll(() => {
            this.onScroll();
          })
          .onScrollEnd(() => {
            this.onScrollEnd();
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .height('100%')
  }
}
