import { Logger } from '../performance/Logger';
import { DesignSystem } from '../../common/DesignSystem';

export interface ImmersiveConfig {
  enabled: boolean;
  hideOnScrollDown: boolean;
  showOnScrollUp: boolean;
  hideDelay: number;
  showDelay: number;
  scrollThreshold: number;
  animationDuration: number;
  animationCurve: Curve;
  dockHideOffset: number;
  navBarHideOffset: number;
  overlayOpacityMin: number;
  overlayOpacityMax: number;
}

export interface UIVisibility {
  dockVisible: boolean;
  navBarVisible: boolean;
  statusBarVisible: boolean;
  overlayOpacity: number;
}

export type VisibilityCallback = (visibility: UIVisibility) => void;

const DEFAULT_IMMERSIVE_CONFIG: ImmersiveConfig = {
  enabled: true,
  hideOnScrollDown: true,
  showOnScrollUp: true,
  hideDelay: 80,
  showDelay: 40,
  scrollThreshold: 40,
  animationDuration: 250,
  animationCurve: Curve.EaseInOut,
  dockHideOffset: 100,
  navBarHideOffset: -80,
  overlayOpacityMin: 0.0,
  overlayOpacityMax: 1.0
};

export class ImmersiveUIManager {
  private static instance: ImmersiveUIManager;
  private config: ImmersiveConfig = DEFAULT_IMMERSIVE_CONFIG;
  private callbacks: VisibilityCallback[] = [];
  private state: UIVisibility = {
    dockVisible: true,
    navBarVisible: true,
    statusBarVisible: true,
    overlayOpacity: 1.0
  };

  private lastScrollY: number = 0;
  private accumulatedScroll: number = 0;
  private scrollTimestamp: number = 0;
  private isAnimating: boolean = false;
  private hideTimer: number = -1;
  private showTimer: number = -1;
  private readonly TAG = 'ImmersiveUIManager';

  private constructor() {}

  static getInstance(): ImmersiveUIManager {
    if (!ImmersiveUIManager.instance) {
      ImmersiveUIManager.instance = new ImmersiveUIManager();
    }
    return ImmersiveUIManager.instance;
  }

  setConfig(config: Partial<ImmersiveConfig>): void {
    if (config.enabled !== undefined) this.config.enabled = config.enabled;
    if (config.hideOnScrollDown !== undefined) this.config.hideOnScrollDown = config.hideOnScrollDown;
    if (config.showOnScrollUp !== undefined) this.config.showOnScrollUp = config.showOnScrollUp;
    if (config.hideDelay !== undefined) this.config.hideDelay = config.hideDelay;
    if (config.showDelay !== undefined) this.config.showDelay = config.showDelay;
    if (config.scrollThreshold !== undefined) this.config.scrollThreshold = config.scrollThreshold;
    if (config.animationDuration !== undefined) this.config.animationDuration = config.animationDuration;
    if (config.animationCurve !== undefined) this.config.animationCurve = config.animationCurve;
    if (config.dockHideOffset !== undefined) this.config.dockHideOffset = config.dockHideOffset;
    if (config.navBarHideOffset !== undefined) this.config.navBarHideOffset = config.navBarHideOffset;
    if (config.overlayOpacityMin !== undefined) this.config.overlayOpacityMin = config.overlayOpacityMin;
    if (config.overlayOpacityMax !== undefined) this.config.overlayOpacityMax = config.overlayOpacityMax;
    Logger.info(this.TAG, `沉浸式配置更新: enabled=${this.config.enabled}`);
  }

  getConfig(): ImmersiveConfig {
    return {
      enabled: this.config.enabled,
      hideOnScrollDown: this.config.hideOnScrollDown,
      showOnScrollUp: this.config.showOnScrollUp,
      hideDelay: this.config.hideDelay,
      showDelay: this.config.showDelay,
      scrollThreshold: this.config.scrollThreshold,
      animationDuration: this.config.animationDuration,
      animationCurve: this.config.animationCurve,
      dockHideOffset: this.config.dockHideOffset,
      navBarHideOffset: this.config.navBarHideOffset,
      overlayOpacityMin: this.config.overlayOpacityMin,
      overlayOpacityMax: this.config.overlayOpacityMax
    };
  }

  getState(): UIVisibility {
    return {
      dockVisible: this.state.dockVisible,
      navBarVisible: this.state.navBarVisible,
      statusBarVisible: this.state.statusBarVisible,
      overlayOpacity: this.state.overlayOpacity
    };
  }

  addCallback(callback: VisibilityCallback): void {
    this.callbacks.push(callback);
  }

  removeCallback(callback: VisibilityCallback): void {
    const index = this.callbacks.indexOf(callback);
    if (index > -1) {
      this.callbacks.splice(index, 1);
    }
  }

  onScroll(currentScrollY: number): void {
    if (!this.config.enabled) return;
    if (this.isAnimating) return;

    const scrollDelta = currentScrollY - this.lastScrollY;
    const now = Date.now();
    const timeDelta = now - this.scrollTimestamp;

    if (this.scrollTimestamp > 0 && timeDelta > 500) {
      this.accumulatedScroll = 0;
    }

    this.accumulatedScroll += scrollDelta;

    // 向下滚动超过阈值 → 隐藏UI
    if (this.config.hideOnScrollDown &&
        this.accumulatedScroll > this.config.scrollThreshold &&
        this.state.dockVisible) {
      this.hideUI();
      this.accumulatedScroll = 0;
    }

    // 向上滚动超过阈值 → 显示UI
    if (this.config.showOnScrollUp &&
        this.accumulatedScroll < -this.config.scrollThreshold &&
        !this.state.dockVisible) {
      this.showUI();
      this.accumulatedScroll = 0;
    }

    // 滚动到顶部 → 确保显示
    if (currentScrollY <= 0 && !this.state.dockVisible) {
      this.showUI();
      this.accumulatedScroll = 0;
    }

    this.lastScrollY = currentScrollY;
    this.scrollTimestamp = now;
  }

  hideUI(): void {
    this.clearTimers();
    this.isAnimating = true;

    this.hideTimer = setTimeout(() => {
      animateTo({
        duration: this.config.animationDuration,
        curve: this.config.animationCurve
      }, () => {
        this.state.dockVisible = false;
        this.state.navBarVisible = false;
        this.state.statusBarVisible = false;
        this.state.overlayOpacity = this.config.overlayOpacityMin;
        this.isAnimating = false;
        this.dispatchStateChange();
      });

      this.hideTimer = -1;
    }, this.config.hideDelay);

    Logger.debug(this.TAG, 'UI隐藏中...');
  }

  showUI(): void {
    this.clearTimers();
    this.isAnimating = true;

    this.showTimer = setTimeout(() => {
      animateTo({
        duration: this.config.animationDuration,
        curve: this.config.animationCurve
      }, () => {
        this.state.dockVisible = true;
        this.state.navBarVisible = true;
        this.state.statusBarVisible = true;
        this.state.overlayOpacity = this.config.overlayOpacityMax;
        this.isAnimating = false;
        this.dispatchStateChange();
      });

      this.showTimer = -1;
    }, this.config.showDelay);

    Logger.debug(this.TAG, 'UI显示中...');
  }

  toggleVisibility(): void {
    if (this.state.dockVisible) {
      this.hideUI();
    } else {
      this.showUI();
    }
  }

  setVisible(visible: boolean): void {
    if (visible) {
      this.showUI();
    } else {
      this.hideUI();
    }
  }

  forceShow(): void {
    this.clearTimers();
    animateTo({
      duration: 0,
      curve: Curve.Linear
    }, () => {
      this.state.dockVisible = true;
      this.state.navBarVisible = true;
      this.state.statusBarVisible = true;
      this.state.overlayOpacity = this.config.overlayOpacityMax;
      this.isAnimating = false;
      this.dispatchStateChange();
    });
  }

  forceHide(): void {
    this.clearTimers();
    animateTo({
      duration: 0,
      curve: Curve.Linear
    }, () => {
      this.state.dockVisible = false;
      this.state.navBarVisible = false;
      this.state.statusBarVisible = false;
      this.state.overlayOpacity = this.config.overlayOpacityMin;
      this.isAnimating = false;
      this.dispatchStateChange();
    });
  }

  reset(): void {
    this.clearTimers();
    this.accumulatedScroll = 0;
    this.lastScrollY = 0;
    this.isAnimating = false;
    this.forceShow();
  }

  private clearTimers(): void {
    if (this.hideTimer !== -1) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
    if (this.showTimer !== -1) {
      clearTimeout(this.showTimer);
      this.showTimer = -1;
    }
  }

  private dispatchStateChange(): void {
    const state = this.getState();
    for (const callback of this.callbacks) {
      try {
        callback(state);
      } catch (error) {
        Logger.error(this.TAG, `可见性回调异常: ${error}`);
      }
    }
  }
}

export const immersiveUI = ImmersiveUIManager.getInstance();
