import { DesignSystem } from '../../common/DesignSystem';
import { SVGIcon } from './SVGIcon';

@ComponentV2
export struct ThinLine {
  @Param isLightMode: boolean = true;
  @Param onExpand: () => void = () => {};
  @Local private swipeDistance: number = 0;

  private getLineColor(): string {
    return this.isLightMode
      ? `rgba(0,0,0,${DesignSystem.CapsuleVisual.thinLineOpacity})`
      : `rgba(255,255,255,${DesignSystem.CapsuleVisual.thinLineOpacity})`;
  }

  build() {
    Row() {
      SVGIcon({ name: 'add', isLightMode: this.isLightMode, renderSize: 12, useSystemSymbol: true })
    }
    .width('100%')
    .height(DesignSystem.CapsuleVisual.thinLineHeight)
    .backgroundColor(this.getLineColor())
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(DesignSystem.CapsuleVisual.thinLineHeight / 2)
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        PanGesture({ direction: PanDirection.Vertical })
          .onActionUpdate((event: GestureEvent) => {
            this.swipeDistance = -event.offsetY;
          })
          .onActionEnd(() => {
            if (this.swipeDistance >= DesignSystem.CapsuleGesture.appSwipeThreshold) {
              this.onExpand();
            }
            this.swipeDistance = 0;
          }),
        TapGesture()
          .onAction(() => {
            this.onExpand();
          })
      )
    )
  }
}
