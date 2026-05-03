import { DesignSystem } from '../../common/DesignSystem';

class InkPoint {
  x: number = 0;
  y: number = 0;
  currentRadius: number = 0;
  opacity: number = 0;
  timestamp: number = 0;

  constructor(x: number, y: number, currentRadius: number, opacity: number, timestamp: number) {
    this.x = x;
    this.y = y;
    this.currentRadius = currentRadius;
    this.opacity = opacity;
    this.timestamp = timestamp;
  }
}

@ComponentV2
export struct InkEffect {
  @Param isLightMode: boolean = true;
  @Param isActive: boolean = true;
  @Param gpuQualityLow: boolean = false;
  @Param fps: number = 60;
  @Local private inkPoints: InkPoint[] = [];
  @Local private canvasWidth: number = 200;
  @Local private canvasHeight: number = 100;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private getMaxRadius(): number {
    if (this.fps < 45) {
      return DesignSystem.CapsuleInk.lowGPUMaxRadius;
    }
    return DesignSystem.CapsuleInk.maxRadius;
  }

  private shouldUseStaticHighlight(): boolean {
    return this.gpuQualityLow || this.fps < 30;
  }

  private getInkColor(): string {
    return this.isLightMode
      ? DesignSystem.Colors.primary.light
      : DesignSystem.Colors.primary.dark;
  }

  build() {
    if (this.isActive && !this.shouldUseStaticHighlight()) {
      Stack() {
        Canvas(this.context)
          .width(this.canvasWidth)
          .height(this.canvasHeight)
          .onReady(() => {
            this.drawInkCircles();
          })
      }
      .hitTestBehavior(HitTestMode.Transparent)
      .gesture(
        PanGesture()
          .onActionStart((event: GestureEvent) => {
            if (event.fingerList) {
              for (const finger of event.fingerList) {
                this.addInkPoint(finger.globalX, finger.globalY);
              }
            }
          })
          .onActionUpdate((event: GestureEvent) => {
            if (event.fingerList) {
              for (const finger of event.fingerList) {
                this.addInkPoint(finger.globalX, finger.globalY);
              }
            }
          })
          .onActionEnd(() => {
            this.startRetract();
          })
      )
    }
  }

  private addInkPoint(x: number, y: number): void {
    const now = Date.now();
    const maxRadius = this.getMaxRadius();
    const newPoint = new InkPoint(
      x,
      y,
      2,
      DesignSystem.CapsuleInk.circleOpacity,
      now
    );

    const newPoints: InkPoint[] = [];
    for (let i = 0; i < this.inkPoints.length; i++) {
      newPoints.push(this.inkPoints[i]);
    }
    newPoints.push(newPoint);
    this.inkPoints = newPoints;

    const expandInterval = setInterval(() => {
      const updatedPoints: InkPoint[] = [];
      for (let i = 0; i < this.inkPoints.length; i++) {
        const p = this.inkPoints[i];
        if (p === newPoint && p.currentRadius < maxRadius) {
          const updated = new InkPoint(p.x, p.y, p.currentRadius + 1, p.opacity, p.timestamp);
          updatedPoints.push(updated);
        } else {
          updatedPoints.push(p);
        }
      }
      this.inkPoints = updatedPoints;
      if (newPoint.currentRadius >= maxRadius) {
        clearInterval(expandInterval);
      }
    }, 16) as number;
  }

  private startRetract(): void {
    setTimeout(() => {
      this.inkPoints = [];
    }, DesignSystem.CapsuleInk.retractDuration);
  }

  private drawInkCircles(): void {
    this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    const inkColor = this.getInkColor();

    for (const point of this.inkPoints) {
      this.context.beginPath();
      this.context.arc(point.x, point.y, point.currentRadius, 0, Math.PI * 2);
      this.context.fillStyle = inkColor;
      this.context.globalAlpha = point.opacity;
      this.context.fill();
      this.context.closePath();
    }
    this.context.globalAlpha = 1.0;
  }
}
