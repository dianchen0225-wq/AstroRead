import { DesignSystem } from '../../common/DesignSystem';
import { themeManager, ThemeMode } from '../../common/ThemeManager';
import { Logger } from '../performance/Logger';

export class DayNightBreathing {
  private readonly TAG = 'DayNightBreathing';
  private isTransitioning: boolean = false;
  private currentBrightness: number = 1.0;
  private breathTimer: number = 0;
  private cycleStartTime: number = 0;
  private targetIsDark: boolean = false;
  private themeListener: ((isDark: boolean) => void) | null = null;

  constructor() {
    this.themeListener = (isDark: boolean): void => {
      this.startBreathingTransition(isDark);
    };
    themeManager.addListener(this.themeListener);
  }

  startBreathingTransition(targetIsDark: boolean): void {
    if (this.isTransitioning) {
      this.cancelCurrentTransition();
    }

    this.targetIsDark = targetIsDark;
    this.isTransitioning = true;
    this.cycleStartTime = Date.now();

    const totalBreathDuration = DesignSystem.CapsuleAnimation.breathCycleDuration * DesignSystem.CapsuleAnimation.breathCycles;
    const stepInterval = 16;

    this.breathTimer = setInterval(() => {
      const elapsed = Date.now() - this.cycleStartTime;

      if (elapsed >= totalBreathDuration) {
        clearInterval(this.breathTimer);
        this.currentBrightness = 1.0;
        this.isTransitioning = false;
        this.onBreathComplete();
        return;
      }

      const cycleProgress = elapsed / DesignSystem.CapsuleAnimation.breathCycleDuration;
      const sinValue = Math.sin(cycleProgress * Math.PI);
      const minBright = DesignSystem.CapsuleDayNight.breathMinBrightness;
      const maxBright = DesignSystem.CapsuleDayNight.breathMaxBrightness;
      this.currentBrightness = minBright + (maxBright - minBright) * sinValue;
    }, stepInterval) as number;
  }

  private onBreathComplete(): void {
    const iconTransitionDuration = DesignSystem.CapsuleAnimation.iconColorTransition;
    Logger.info(this.TAG, `呼吸完成，开始${iconTransitionDuration}ms图标色渐变`);
  }

  cancelCurrentTransition(): void {
    if (this.breathTimer) {
      clearInterval(this.breathTimer);
      this.breathTimer = 0;
    }
    this.isTransitioning = false;
  }

  getBrightness(): number {
    return this.currentBrightness;
  }

  getIsTransitioning(): boolean {
    return this.isTransitioning;
  }

  getTargetIconColor(): string {
    return this.targetIsDark
      ? DesignSystem.CapsuleDayNight.nightIconColor
      : DesignSystem.CapsuleDayNight.dayIconColor;
  }

  getBackground(): string {
    return this.targetIsDark
      ? DesignSystem.CapsuleDayNight.nightBackground
      : DesignSystem.CapsuleDayNight.dayBackground;
  }

  getShadowOpacity(): number {
    return this.targetIsDark ? 0 : DesignSystem.CapsuleDayNight.dayShadowOpacity;
  }

  destroy(): void {
    this.cancelCurrentTransition();
    if (this.themeListener) {
      themeManager.removeListener(this.themeListener);
      this.themeListener = null;
    }
  }
}
