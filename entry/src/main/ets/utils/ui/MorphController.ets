import { DesignSystem } from '../../common/DesignSystem';
import { CapsuleMorphState, CapsuleStateStore } from '../../components/capsule/CapsuleStateStore';

export class MorphController {
  private readonly TAG = 'MorphController';
  private stateStore: CapsuleStateStore;
  private isTabActive: boolean = true;
  private morphAnimationId: number = 0;

  constructor(stateStore: CapsuleStateStore) {
    this.stateStore = stateStore;
  }

  getCurrentState(): CapsuleMorphState {
    return this.stateStore.morphState;
  }

  transitionToThinLine(): void {
    if (this.stateStore.morphState === CapsuleMorphState.FULL && this.stateStore.isDeepReading) {
      this.animateTransition(CapsuleMorphState.THIN_LINE);
    }
  }

  transitionToHidden(): void {
    if (this.stateStore.morphState !== CapsuleMorphState.HIDDEN) {
      this.animateTransition(CapsuleMorphState.HIDDEN);
    }
  }

  expandFromThinLine(): void {
    if (this.stateStore.morphState === CapsuleMorphState.THIN_LINE) {
      this.animateTransition(CapsuleMorphState.FULL);
    }
  }

  expandFromHidden(): void {
    if (this.stateStore.morphState === CapsuleMorphState.HIDDEN) {
      this.animateTransition(CapsuleMorphState.FULL);
    }
  }

  onScrollPage(): void {
    if (this.stateStore.isReadingPage && this.isTabActive) {
      this.stateStore.incrementConsecutivePages();
      this.checkDeepReading();
    }
  }

  onTabSwitch(): void {
    this.isTabActive = true;
    this.stateStore.resetDeepReading();
    if (this.stateStore.morphState === CapsuleMorphState.THIN_LINE) {
      this.animateTransition(CapsuleMorphState.FULL);
    }
  }

  onLeaveReadingPage(): void {
    this.stateStore.resetDeepReading();
    if (this.stateStore.morphState === CapsuleMorphState.THIN_LINE) {
      this.animateTransition(CapsuleMorphState.FULL);
    }
  }

  private checkDeepReading(): void {
    if (this.stateStore.isDeepReading && this.stateStore.morphState === CapsuleMorphState.FULL) {
      this.transitionToThinLine();
    }
  }

  private animateTransition(targetState: CapsuleMorphState): void {
    this.morphAnimationId++;
    this.stateStore.morphState = targetState;
  }

  getMorphDuration(): number {
    return DesignSystem.CapsuleAnimation.morphDuration;
  }

  getMorphOrientationDuration(): number {
    return DesignSystem.CapsuleAnimation.morphOrientationDuration;
  }

  reset(): void {
    this.morphAnimationId = 0;
    this.isTabActive = true;
  }
}
