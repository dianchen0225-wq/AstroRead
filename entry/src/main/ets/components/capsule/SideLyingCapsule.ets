import { DesignSystem } from '../../common/DesignSystem';
import { SVGIcon, CapsuleIconName } from './SVGIcon';
import { CapsuleShell } from './CapsuleShell';
import { DeviceLayoutMode } from './CapsuleStateStore';

@ComponentV2
export struct SideLyingCapsule {
  @Param isLightMode: boolean = true;
  @Param screenWidth: number = 360;
  @Param screenHeight: number = 780;
  @Param deviceLayoutMode: DeviceLayoutMode = DeviceLayoutMode.PORTRAIT_PHONE;
  @Param icons: CapsuleIconName[] = ['home', 'search', 'bookshelf', 'source', 'settings'];
  @Param activeIndex: number = 0;
  @Param onIconTap: (index: number) => void = () => {};
  @Param content?: () => void;

  @Computed
  get shouldUseSideLying(): boolean {
    return this.deviceLayoutMode === DeviceLayoutMode.LANDSCAPE_TABLET;
  }

  @Computed
  get verticalOffset(): number {
    const bias = DesignSystem.CapsuleSideLying.verticalBias;
    return this.screenHeight * (1 - bias) - DesignSystem.CapsuleSideLying.capsuleWidth / 2;
  }

  build() {
    if (this.shouldUseSideLying) {
      Column() {
        ForEach(this.icons, (name: CapsuleIconName, index?: number) => {
          Row() {
            SVGIcon({
              name: name,
              isActive: index === this.activeIndex,
              isLightMode: this.isLightMode,
              renderSize: DesignSystem.CapsuleSVGIcon.renderSize,
              useSystemSymbol: true
            })
          }
          .width(DesignSystem.CapsuleSideLying.capsuleWidth - DesignSystem.CapsuleSideLying.iconSpacing * 2)
          .height(DesignSystem.CapsuleSideLying.capsuleWidth - DesignSystem.CapsuleSideLying.iconSpacing * 2)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .borderRadius(DesignSystem.BorderRadius.md)
          .gesture(
            TapGesture()
              .onAction(() => {
                if (index !== undefined) {
                  this.onIconTap(index);
                }
              })
          )
        }, (name: CapsuleIconName, index?: number) => `side_icon_${index}`)
      }
      .width(DesignSystem.CapsuleSideLying.capsuleWidth)
      .padding({ top: DesignSystem.CapsuleSideLying.iconSpacing, bottom: DesignSystem.CapsuleSideLying.iconSpacing })
      .borderRadius(DesignSystem.CapsuleVisual.capsuleBorderRadius)
      .backgroundColor(this.isLightMode ? DesignSystem.CapsuleDayNight.dayBackground : DesignSystem.CapsuleDayNight.nightBackground)
      .shadow({
        radius: 8,
        color: this.isLightMode ? `rgba(0,0,0,${DesignSystem.CapsuleDayNight.dayShadowOpacity})` : 'transparent',
        offsetX: 0,
        offsetY: 2
      })
      .position({
        x: DesignSystem.CapsuleSideLying.leftMargin,
        y: this.verticalOffset
      })
    }
  }
}
