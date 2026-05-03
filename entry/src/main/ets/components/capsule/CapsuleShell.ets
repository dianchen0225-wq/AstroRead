import { DesignSystem } from '../../common/DesignSystem';

@ComponentV2
export struct CapsuleShell {
  @Param isLightMode: boolean = true;
  @Param isVertical: boolean = false;
  @Param shellOpacity: number = 1.0;
  @Param showNightGlow: boolean = false;
  @Param gpuQualityLow: boolean = false;
  @BuilderParam content: () => void;

  @Computed
  get background(): string {
    return this.isLightMode
      ? DesignSystem.CapsuleDayNight.dayBackground
      : DesignSystem.CapsuleDayNight.nightBackground;
  }

  @Computed
  get shadowOpacity(): number {
    return this.isLightMode ? DesignSystem.CapsuleDayNight.dayShadowOpacity : 0;
  }

  build() {
    Row() {
      this.content()
    }
    .width(this.isVertical ? DesignSystem.CapsuleVisual.capsuleWidth : undefined)
    .height(this.isVertical ? undefined : DesignSystem.CapsuleVisual.capsuleHeight)
    .borderRadius(DesignSystem.CapsuleVisual.capsuleBorderRadius)
    .backgroundColor(this.background)
    .opacity(this.shellOpacity)
    .shadow({
      radius: 8,
      color: `rgba(0,0,0,${this.shadowOpacity})`,
      offsetX: 0,
      offsetY: 2
    } as ShadowOptions)
    .backdropBlur(DesignSystem.BorderRadius.xl)
    .justifyContent(FlexAlign.SpaceEvenly)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: DesignSystem.CapsuleVisual.iconSpacing,
      right: DesignSystem.CapsuleVisual.iconSpacing
    } as PaddingOptions)
    .borderWidth(this.showNightGlow && !this.isLightMode ? DesignSystem.CapsuleDayNight.nightGlowWidth : 0)
    .borderColor(this.showNightGlow && !this.isLightMode
      ? (this.gpuQualityLow ? 'rgba(180,40,40,0.5)' : DesignSystem.CapsuleDayNight.nightGlowColor)
      : 'transparent')
  }
}
