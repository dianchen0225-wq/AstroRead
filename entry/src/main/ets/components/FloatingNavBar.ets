import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';
import { floatingNavManager, FloatingNavConfig } from '../common/FloatingNavManager';

interface NavItem {
  index: number;
  icon: string;
  label: string;
}

@ComponentV2
export struct FloatingNavBar {
  @Param currentIndex: number = 0;
  @Param onTabChange?: (index: number) => void;
  @Param screenWidth: number = 360;
  @Param screenHeight: number = 780;
  @Param safeAreaBottom: number = 0;
  
  @Local isLightMode: boolean = true;
  @Local config: FloatingNavConfig = floatingNavManager.getConfig();
  @Local isVisible: boolean = true;
  @Local isExpanded: boolean = false;
  @Local hideTimer: number = -1;
  
  private navItems: NavItem[] = [
    { index: 0, icon: '🏠', label: '首页' },
    { index: 1, icon: '🔍', label: '搜索' },
    { index: 2, icon: '📚', label: '书架' },
    { index: 3, icon: '📖', label: '书源' },
    { index: 4, icon: '⚙️', label: '设置' }
  ];
  
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };
  
  private configListener: (config: FloatingNavConfig) => void = (config: FloatingNavConfig) => {
    this.config = config;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    floatingNavManager.addConfigChangeListener(this.configListener);
    
    if (this.config.autoHide) {
      this.startAutoHideTimer();
    }
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
    floatingNavManager.removeConfigChangeListener(this.configListener);
    this.clearHideTimer();
  }

  private startAutoHideTimer(): void {
    this.clearHideTimer();
    if (this.config.autoHide && this.config.enabled) {
      this.hideTimer = setTimeout(() => {
        this.isVisible = false;
      }, this.config.autoHideDelay);
    }
  }

  private clearHideTimer(): void {
    if (this.hideTimer !== -1) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
  }

  private handleInteraction(): void {
    if (this.config.autoHide) {
      this.isVisible = true;
      this.startAutoHideTimer();
    }
  }

  private getPositionStyle(): { x: number | string; y: number | string } {
    return floatingNavManager.getPositionStyle(
      this.screenWidth,
      this.screenHeight,
      this.safeAreaBottom
    );
  }

  private getBackgroundColor(): string {
    const baseColor = this.isLightMode ? '#FFFFFF' : '#1A1A1A';
    const opacity = Math.floor(this.config.backgroundOpacity * 255).toString(16).padStart(2, '0');
    return baseColor + opacity;
  }

  private isBottomPosition(): boolean {
    return this.config.position.startsWith('bottom');
  }

  build() {
    if (!this.config.enabled) {
      return;
    }

    const position = this.getPositionStyle();
    const isBottom = this.isBottomPosition();

    Stack() {
      Row() {
        if (this.isExpanded || !isBottom) {
          ForEach(this.navItems, (item: NavItem) => {
            this.buildNavItem(item)
          })
        } else {
          this.buildCollapsedNav()
        }
      }
      .width(this.config.width)
      .height(this.config.height)
      .borderRadius(this.config.borderRadius)
      .backgroundColor(this.getBackgroundColor())
      .opacity(this.config.opacity)
      .shadow({
        radius: 12,
        color: this.isLightMode ? 'rgba(0,0,0,0.15)' : 'rgba(0,0,0,0.4)',
        offsetX: 0,
        offsetY: 4
      })
      .backdropBlur(this.config.blurEnabled ? 20 : 0)
      .border({
        width: 1,
        color: this.isLightMode ? 'rgba(0,0,0,0.08)' : 'rgba(255,255,255,0.1)'
      })
      .padding({ left: 8, right: 8 })
      .justifyContent(FlexAlign.SpaceEvenly)
      .animation({
        duration: this.config.animationEnabled ? 300 : 0,
        curve: Curve.EaseOut
      })
      .onClick(() => {
        this.handleInteraction();
      })
      .onHover((isHover: boolean) => {
        this.handleInteraction();
      })
    }
    .position({
      x: position.x,
      y: position.y
    })
    .opacity(this.isVisible ? 1 : 0.3)
    .scale({
      x: this.isVisible ? 1 : 0.9,
      y: this.isVisible ? 1 : 0.9
    })
    .animation({
      duration: this.config.animationEnabled ? 200 : 0,
      curve: Curve.EaseOut
    })
    .onClick(() => {
      if (!this.isVisible) {
        this.handleInteraction();
      }
    })
  }

  @Builder
  buildNavItem(item: NavItem) {
    Column() {
      Text(item.icon)
        .fontSize(20)
        .fontColor(this.currentIndex === item.index ?
          DesignSystem.getPrimaryColor(this.isLightMode) :
          DesignSystem.getSecondaryTextColor(this.isLightMode))
        .scale({
          x: this.currentIndex === item.index ? 1.1 : 1,
          y: this.currentIndex === item.index ? 1.1 : 1
        })
        .animation({ duration: 200, curve: Curve.EaseOut })

      if (this.config.height >= 60) {
        Text(item.label)
          .fontSize(10)
          .fontColor(this.currentIndex === item.index ?
            DesignSystem.getPrimaryColor(this.isLightMode) :
            DesignSystem.getSecondaryTextColor(this.isLightMode))
          .margin({ top: 2 })
          .animation({ duration: 200, curve: Curve.EaseOut })
      }
    }
    .padding(8)
    .borderRadius(12)
    .backgroundColor(this.currentIndex === item.index ?
      DesignSystem.getHoverColor(this.isLightMode) :
      Color.Transparent)
    .onClick(() => {
      this.handleInteraction();
      if (this.onTabChange) {
        this.onTabChange(item.index);
      }
    })
  }

  @Builder
  buildCollapsedNav() {
    Row() {
      Text(this.navItems[this.currentIndex]?.icon || '🏠')
        .fontSize(24)
        .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))

      Text('☰')
        .fontSize(16)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ left: 8 })
    }
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.handleInteraction();
      this.isExpanded = true;
    })
  }
}

@ComponentV2
export struct FloatingNavToggle {
  @Local isLightMode: boolean = true;
  @Local config: FloatingNavConfig = floatingNavManager.getConfig();
  
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };
  
  private configListener: (config: FloatingNavConfig) => void = (config: FloatingNavConfig) => {
    this.config = config;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    floatingNavManager.addConfigChangeListener(this.configListener);
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
    floatingNavManager.removeConfigChangeListener(this.configListener);
  }

  build() {
    Row() {
      Toggle({ type: ToggleType.Switch, isOn: this.config.enabled })
        .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
        .onChange((isOn: boolean) => {
          floatingNavManager.setEnabled(isOn);
        })
    }
  }
}
