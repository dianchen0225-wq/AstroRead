import { DesignSystem } from '../../common/DesignSystem';
import { SVGIcon } from './SVGIcon';

@ComponentV2
export struct ChapterProgressRing {
  @Param progress: number = 0;
  @Param isReadingPage: boolean = false;
  @Param isLightMode: boolean = true;
  @Param onJumpToCatalog: () => void = () => {};

  private getStrokeColor(): string {
    return this.isLightMode
      ? DesignSystem.CapsuleDayNight.dayIconColor
      : DesignSystem.CapsuleDayNight.nightIconColor;
  }

  private getTrackColor(): string {
    return this.isLightMode ? 'rgba(0,0,0,0.08)' : 'rgba(255,255,255,0.08)';
  }

  build() {
    Row() {
      if (this.isReadingPage && this.progress > 0) {
        Stack() {
          Progress({ value: this.progress, total: 100, type: ProgressType.Ring })
            .width(28)
            .height(28)
            .color(this.getStrokeColor())
            .backgroundColor(this.getTrackColor())
            .style({ strokeWidth: 2.5 })

          Text(`${Math.round(this.progress)}%`)
            .fontSize(7)
            .fontColor(this.getStrokeColor())
            .fontWeight(500)
        }
        .width(28)
        .height(28)
      } else {
        SVGIcon({ name: 'add', isLightMode: this.isLightMode, renderSize: 22, useSystemSymbol: true })
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .gesture(
      TapGesture()
        .onAction(() => {
          if (this.isReadingPage) {
            this.onJumpToCatalog();
          }
        })
    )
  }
}
