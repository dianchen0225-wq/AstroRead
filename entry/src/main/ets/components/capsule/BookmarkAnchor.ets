import { DesignSystem } from '../../common/DesignSystem';

@ComponentV2
export struct BookmarkAnchor {
  @Param isLightMode: boolean = true;
  @Param isDragging: boolean = false;
  @Param lineLength: number = 0;
  @Param showDot: boolean = false;
  @Param onBookmarkCreate: () => void = () => {};
  @Param handleDragStart: () => void = () => {};
  @Param handleDragEnd: (distance: number) => void = () => {};
  @Local private dragDistance: number = 0;

  private getLineColor(): string {
    return this.isLightMode ? DesignSystem.Colors.primary.light : DesignSystem.Colors.primary.dark;
  }

  build() {
    Stack() {
      if (this.isDragging && this.dragDistance > 0) {
        Column() {
          Row()
            .width(DesignSystem.CapsuleBookmark.lineWidth)
            .height(this.dragDistance)
            .backgroundColor(this.getLineColor())
            .borderRadius(DesignSystem.CapsuleBookmark.lineWidth / 2)

          Row()
            .width(DesignSystem.CapsuleBookmark.headDiameter)
            .height(DesignSystem.CapsuleBookmark.headDiameter)
            .borderRadius(DesignSystem.CapsuleBookmark.headDiameter / 2)
            .backgroundColor(this.getLineColor())
        }
        .alignItems(HorizontalAlign.Center)
      }

      if (this.showDot) {
        Row()
          .width(DesignSystem.CapsuleBookmark.dotDiameter)
          .height(DesignSystem.CapsuleBookmark.dotDiameter)
          .borderRadius(DesignSystem.CapsuleBookmark.dotDiameter / 2)
          .backgroundColor('#E53935')
          .position({ x: '85%', y: -2 })
      }
    }
    .gesture(
      PanGesture({ direction: PanDirection.Vertical })
        .onActionStart(() => {
          this.handleDragStart();
        })
        .onActionUpdate((event: GestureEvent) => {
          this.dragDistance = Math.max(0, -event.offsetY);
        })
        .onActionEnd(() => {
          if (this.dragDistance >= DesignSystem.CapsuleBookmark.minTriggerDistance) {
            this.onBookmarkCreate();
          }
          this.handleDragEnd(this.dragDistance);
          this.dragDistance = 0;
        })
    )
  }
}
