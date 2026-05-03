import { DesignSystem } from '../../common/DesignSystem';
import { SVGIcon, CapsuleIconName } from './SVGIcon';

interface PetalItem {
  name: CapsuleIconName;
  x: number;
  y: number;
}

@ComponentV2
export struct PetalMenu {
  @Param isOpen: boolean = false;
  @Param isLightMode: boolean = true;
  @Param centerX: number = 0;
  @Param centerY: number = 0;
  @Param onSelect: (index: number) => void = () => {};
  @Param onCancel: () => void = () => {};
  @Local private activeIndex: number = -1;

  private readonly items: CapsuleIconName[] = ['catalog', 'brightness', 'fontsize', 'nightmode'];

  private getItemPositions(): PetalItem[] {
    const radius = DesignSystem.CapsulePetal.radius;
    const startAngle = DesignSystem.CapsulePetal.arcStartAngle * Math.PI / 180;
    const spanAngle = DesignSystem.CapsulePetal.arcSpanAngle * Math.PI / 180;
    const count = DesignSystem.CapsulePetal.itemCount;
    const step = count > 1 ? spanAngle / (count - 1) : 0;

    return this.items.map((name, i) => {
      const angle = startAngle + i * step;
      return {
        name,
        x: this.centerX + radius * Math.cos(angle),
        y: this.centerY + radius * Math.sin(angle)
      };
    });
  }

  build() {
    if (this.isOpen) {
      Stack() {
        ForEach(this.getItemPositions(), (item: PetalItem, index?: number) => {
          Row() {
            SVGIcon({ name: item.name, isLightMode: this.isLightMode, renderSize: 22, useSystemSymbol: true })
          }
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor(this.isLightMode ? 'rgba(255,255,255,0.9)' : 'rgba(30,30,30,0.9)')
          .shadow({ radius: 4, color: 'rgba(0,0,0,0.15)', offsetX: 0, offsetY: 2 })
          .justifyContent(FlexAlign.Center)
          .position({ x: item.x - 22, y: item.y - 22 })
          .scale({ x: this.activeIndex === index ? 1.15 : 1, y: this.activeIndex === index ? 1.15 : 1 })
        }, (item: PetalItem, index?: number) => `petal_${index}`)
      }
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }
}
