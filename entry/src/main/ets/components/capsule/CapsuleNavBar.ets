import { DesignSystem } from '../../common/DesignSystem';
import { themeManager } from '../../common/ThemeManager';
import { CapsuleStateStore, CapsuleMorphState, DeviceLayoutMode, ScrollDirection } from './CapsuleStateStore';
import { SVGIcon, CapsuleIconName } from './SVGIcon';
import { CapsuleShell } from './CapsuleShell';
import { ThinLine } from './ThinLine';
import { PetalMenu } from './PetalMenu';
import { BookmarkAnchor } from './BookmarkAnchor';
import { ChapterProgressRing } from './ChapterProgressRing';
import { InkEffect } from './InkEffect';
import { SideLyingCapsule } from './SideLyingCapsule';
import { VelocityAwareController } from '../../utils/ui/VelocityAwareController';
import { MorphController } from '../../utils/ui/MorphController';
import { GestureIntentLayer } from '../../utils/ui/GestureIntentLayer';
import { DayNightBreathing } from '../../utils/ui/DayNightBreathing';

@ComponentV2
export struct CapsuleNavBar {
  @Param isReadingPage: boolean = false;
  @Param chapterProgress: number = 0;
  @Param brightnessValue: number = 50;
  @Param fontSizeValue: number = 16;
  @Param totalChapters: number = 0;
  @Param currentChapterIndex: number = 0;
  @Param scrollVelocity: number = 0;
  @Param scrollDirection: ScrollDirection = ScrollDirection.NONE;
  @Param onTabChange: (index: number) => void = () => {};
  @Param onBrightnessChange: (value: number) => void = () => {};
  @Param onFontSizeChange: (value: number) => void = () => {};
  @Param onJumpToChapterList: () => void = () => {};
  @Param onBookmarkCreate: () => void = () => {};

  @Local private morphState: CapsuleMorphState = CapsuleMorphState.FULL;
  @Local private isLightMode: boolean = true;
  @Local private currentOpacity: number = 1.0;
  @Local private activeTabIndex: number = 0;
  @Local private isPetalOpen: boolean = false;
  @Local private isBookmarkDragging: boolean = false;
  @Local private showBookmarkDot: boolean = false;
  @Local private screenWidth: number = 360;
  @Local private screenHeight: number = 780;
  @Local private deviceLayoutMode: DeviceLayoutMode = DeviceLayoutMode.PORTRAIT_PHONE;
  @Local private breathBrightness: number = 1.0;

  private stateStore: CapsuleStateStore = CapsuleStateStore.getInstance();
  private velocityController: VelocityAwareController = new VelocityAwareController();
  private morphController: MorphController = new MorphController(this.stateStore);
  private gestureIntentLayer: GestureIntentLayer = new GestureIntentLayer();
  private dayNightBreathing: DayNightBreathing = new DayNightBreathing();

  private readonly tabIcons: CapsuleIconName[] = ['home', 'search', 'bookshelf', 'source', 'settings'];
  private readonly readingIcons: CapsuleIconName[] = ['brightness', 'catalog', 'fontsize'];

  private themeListener: ((isDark: boolean) => void) | null = null;

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    this.themeListener = (isDark: boolean): void => {
      this.isLightMode = !isDark;
    };
    themeManager.addListener(this.themeListener);
    this.syncStateFromStore();
  }

  aboutToDisappear(): void {
    if (this.themeListener) {
      themeManager.removeListener(this.themeListener);
      this.themeListener = null;
    }
    this.dayNightBreathing.destroy();
  }

  private syncStateFromStore(): void {
    this.morphState = this.stateStore.morphState;
    this.currentOpacity = this.stateStore.currentOpacity;
    this.screenWidth = this.stateStore.screenWidth;
    this.screenHeight = this.stateStore.screenHeight;
    this.deviceLayoutMode = this.stateStore.deviceLayoutMode;
  }

  private handleScrollUpdate(): void {
    const result = this.velocityController.handleScroll(this.scrollVelocity, this.scrollDirection);
    this.stateStore.updateOpacityThrottled(result.opacity);

    if (result.shouldElasticPush) {
      this.morphController.transitionToHidden();
    }

    if (result.shouldFadeOut && this.morphState === CapsuleMorphState.FULL) {
      this.stateStore.updateOpacityThrottled(0);
    }

    this.syncStateFromStore();
  }

  private handleExpandFromThinLine(): void {
    this.morphController.expandFromThinLine();
    this.syncStateFromStore();
  }

  private handleTabTap(index: number): void {
    this.activeTabIndex = index;
    this.morphController.onTabSwitch();
    this.onTabChange(index);
    this.syncStateFromStore();
  }

  private getBottomOffset(): number {
    return DesignSystem.CapsuleGesture.airGapFromSystemBar + 32;
  }

  private shouldShowSideLying(): boolean {
    return this.deviceLayoutMode === DeviceLayoutMode.LANDSCAPE_TABLET;
  }

  build() {
    Stack() {
      if (this.shouldShowSideLying()) {
        SideLyingCapsule({
          isLightMode: this.isLightMode,
          screenWidth: this.screenWidth,
          screenHeight: this.screenHeight,
          deviceLayoutMode: this.deviceLayoutMode,
          icons: this.isReadingPage ? this.readingIcons : this.tabIcons,
          activeIndex: this.activeTabIndex,
          onIconTap: (index: number) => { this.handleTabTap(index); }
        })
      } else if (this.morphState === CapsuleMorphState.THIN_LINE) {
        ThinLine({
          isLightMode: this.isLightMode,
          onExpand: () => { this.handleExpandFromThinLine(); }
        })
      } else if (this.morphState === CapsuleMorphState.FULL) {
        Stack() {
          CapsuleShell({
            isLightMode: this.isLightMode,
            isVertical: false,
            shellOpacity: this.currentOpacity * this.breathBrightness,
            showNightGlow: !this.isLightMode,
            gpuQualityLow: false,
            content: this.buildShellContent
          })

          PetalMenu({
            isOpen: this.isPetalOpen,
            isLightMode: this.isLightMode,
            centerX: this.screenWidth / 2,
            centerY: this.screenHeight - this.getBottomOffset() - DesignSystem.CapsuleVisual.capsuleHeight,
            onSelect: (index: number) => { this.isPetalOpen = false; },
            onCancel: () => { this.isPetalOpen = false; }
          })

          BookmarkAnchor({
            isLightMode: this.isLightMode,
            isDragging: this.isBookmarkDragging,
            lineLength: 0,
            showDot: this.showBookmarkDot,
            onBookmarkCreate: () => {
              this.showBookmarkDot = true;
              this.onBookmarkCreate();
            },
            handleDragStart: () => { this.isBookmarkDragging = true; },
            handleDragEnd: () => { this.isBookmarkDragging = false; }
          })

          if (this.isReadingPage) {
            InkEffect({
              isLightMode: this.isLightMode,
              isActive: true,
              gpuQualityLow: false,
              fps: 60
            })
          }
        }
        .gesture(
          LongPressGesture({ duration: DesignSystem.CapsulePetal.longPressThreshold })
            .onAction(() => {
              this.isPetalOpen = !this.isPetalOpen;
            })
        )
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  buildShellContent() {
    if (this.isReadingPage) {
      this.buildReadingContent()
    } else {
      this.buildTabContent()
    }
  }

  @Builder
  buildTabContent() {
    ForEach(this.tabIcons, (name: CapsuleIconName, index?: number) => {
      Row() {
        SVGIcon({
          name: name,
          isActive: index === this.activeTabIndex,
          isLightMode: this.isLightMode,
          renderSize: DesignSystem.CapsuleSVGIcon.renderSize,
          useSystemSymbol: true
        })
      }
      .gesture(
        TapGesture()
          .onAction(() => {
            if (index !== undefined) {
              this.handleTabTap(index);
            }
          })
      )
    }, (name: CapsuleIconName, index?: number) => `tab_${index}`)
  }

  @Builder
  buildReadingContent() {
    Row() {
      SVGIcon({
        name: 'brightness',
        isLightMode: this.isLightMode,
        renderSize: 18,
        useSystemSymbol: true
      })
    }
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal })
        .onActionUpdate((event: GestureEvent) => {
          const delta = event.offsetX * 0.2;
          const newValue = this.stateStore.clampBrightness(this.brightnessValue + delta);
          this.onBrightnessChange(newValue);
        })
    )

    ChapterProgressRing({
      progress: this.chapterProgress,
      isReadingPage: this.isReadingPage,
      isLightMode: this.isLightMode,
      onJumpToCatalog: () => { this.onJumpToChapterList(); }
    })

    Row() {
      SVGIcon({
        name: 'fontsize',
        isLightMode: this.isLightMode,
        renderSize: 18,
        useSystemSymbol: true
      })
    }
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal })
        .onActionUpdate((event: GestureEvent) => {
          const delta = event.offsetX * 0.05;
          const newValue = this.stateStore.clampFontSize(this.fontSizeValue + delta);
          this.onFontSizeChange(newValue);
        })
    )
  }
}
