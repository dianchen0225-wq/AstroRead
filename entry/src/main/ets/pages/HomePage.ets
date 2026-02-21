import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { NavigationManager } from '../common/NavigationManager';
import { PageHeader } from '../components/CommonNavBar';

interface GradientColorItem {
  color: string;
  position: number;
}

interface MenuItem {
  id: string;
  title: ResourceStr;
  desc: ResourceStr;
  icon: string;
  gradientColors: GradientColorItem[];
  gradientStart: string;
  route: string;
  tabIndex?: number;
}

@ComponentV2
export struct HomePage {
  @Local isLightMode: boolean = true;
  @Local pressedItemId: string = '';
  @Param safeAreaTop: number = 0;
  @Param onNavigate: (route: string, params?: ESObject) => void = () => {};
  
  private menuItems: MenuItem[] = [
    {
      id: 'bookshelf',
      title: $r('app.string.my_bookshelf'),
      desc: $r('app.string.my_bookshelf_desc'),
      icon: '📚',
      gradientColors: [{ color: '#667eea', position: 0 } as GradientColorItem, { color: '#764ba2', position: 1 } as GradientColorItem],
      gradientStart: '#667eea',
      route: 'BookshelfPage',
      tabIndex: 2
    },
    {
      id: 'search',
      title: $r('app.string.search_books'),
      desc: $r('app.string.search_books_desc'),
      icon: '🔍',
      gradientColors: [{ color: '#f093fb', position: 0 } as GradientColorItem, { color: '#f5576c', position: 1 } as GradientColorItem],
      gradientStart: '#f093fb',
      route: 'SearchPage',
      tabIndex: 1
    },
    {
      id: 'source',
      title: $r('app.string.source_management'),
      desc: $r('app.string.source_management_desc'),
      icon: '📖',
      gradientColors: [{ color: '#4facfe', position: 0 } as GradientColorItem, { color: '#00f2fe', position: 1 } as GradientColorItem],
      gradientStart: '#4facfe',
      route: 'SourcePage',
      tabIndex: 3
    },
    {
      id: 'settings',
      title: $r('app.string.settings'),
      desc: $r('app.string.settings_desc'),
      icon: '⚙️',
      gradientColors: [{ color: '#43e97b', position: 0 } as GradientColorItem, { color: '#38f9d7', position: 1 } as GradientColorItem],
      gradientStart: '#43e97b',
      route: 'SettingsPage',
      tabIndex: 4
    }
  ];
  
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  private getGradientColors(item: MenuItem): Array<[string, number]> {
    const result: Array<[string, number]> = [];
    for (let i = 0; i < item.gradientColors.length; i++) {
      const gc = item.gradientColors[i];
      result.push([gc.color, gc.position]);
    }
    return result;
  }

  private handleNavigation(item: MenuItem): void {
    if (item.tabIndex !== undefined && this.onNavigate) {
      this.onNavigate('TabSwitch', { tabIndex: item.tabIndex });
    } else {
      NavigationManager.getInstance().navigateTo(item.route);
    }
  }

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  build() {
    Column() {
      this.buildHeader()
      
      this.buildAppTitle()
      
      this.buildQuickActions()
      
      this.buildMenuSection()
      
      Blank()
      
      this.buildFooter()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }

  @Builder
  buildHeader() {
    Row() {
      this.buildThemeToggle()
      
      Blank()
      
      this.buildVersionBadge()
    }
    .width('100%')
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: this.safeAreaTop + DesignSystem.Spacing.md,
      bottom: DesignSystem.Spacing.sm
    })
  }

  @Builder
  buildThemeToggle() {
    Row() {
      Text(this.isLightMode ? '🌙' : '☀️')
        .fontSize(DesignSystem.IconSize.md)
        .margin({ right: DesignSystem.Spacing.sm })
      
      Text(this.isLightMode ? $r('app.string.dark_mode') : $r('app.string.light_mode'))
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.medium)
    }
    .padding({
      left: DesignSystem.Spacing.md,
      right: DesignSystem.Spacing.md,
      top: DesignSystem.Spacing.sm,
      bottom: DesignSystem.Spacing.sm
    })
    .borderRadius(DesignSystem.BorderRadius.lg)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .shadow({
      radius: 4,
      color: this.isLightMode ? 'rgba(0,0,0,0.03)' : 'rgba(0,0,0,0.2)',
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => {
      themeManager.toggleTheme();
    })
  }

  @Builder
  buildVersionBadge() {
    Row() {
      Text('v1.0')
        .fontSize(DesignSystem.Typography.size.xs)
        .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.medium)
    }
    .padding({
      left: DesignSystem.Spacing.sm,
      right: DesignSystem.Spacing.sm,
      top: DesignSystem.Spacing.xs,
      bottom: DesignSystem.Spacing.xs
    })
    .borderRadius(DesignSystem.BorderRadius.md)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }

  @Builder
  buildAppTitle() {
    Column() {
      Text($r('app.string.app_name'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontSize(DesignSystem.Typography.size.xxxl)
        .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
        .fontWeight(DesignSystem.Typography.weight.bold)
        .letterSpacing(4)
        .textShadow({
          radius: 8,
          color: this.isLightMode ? 'rgba(139, 105, 20, 0.2)' : 'rgba(212, 180, 131, 0.3)',
          offsetX: 0,
          offsetY: 2
        })
      
      Text('畅享阅读时光')
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ top: DesignSystem.Spacing.sm })
        .letterSpacing(2)
    }
    .width('100%')
    .padding({
      top: DesignSystem.Spacing.lg,
      bottom: DesignSystem.Spacing.xl
    })
  }

  @Builder
  buildQuickActions() {
    Row() {
      this.buildQuickActionItem('📚', '继续阅读', () => {
        if (this.onNavigate) {
          this.onNavigate('TabSwitch', { tabIndex: 2 });
        }
      })
      
      this.buildQuickActionItem('🔍', '搜索书籍', () => {
        if (this.onNavigate) {
          this.onNavigate('TabSwitch', { tabIndex: 1 });
        }
      })
      
      this.buildQuickActionItem('📥', '导入书源', () => {
        if (this.onNavigate) {
          this.onNavigate('TabSwitch', { tabIndex: 3 });
        }
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      bottom: DesignSystem.Spacing.lg
    })
  }

  @Builder
  buildQuickActionItem(icon: string, title: string, action: () => void) {
    Column() {
      Row() {
        Text(icon)
          .fontSize(DesignSystem.IconSize.lg)
      }
      .width(48)
      .height(48)
      .borderRadius(DesignSystem.BorderRadius.full)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .justifyContent(FlexAlign.Center)
      .shadow({
        radius: 4,
        color: this.isLightMode ? 'rgba(0,0,0,0.05)' : 'rgba(0,0,0,0.2)',
        offsetX: 0,
        offsetY: 2
      })

      Text(title)
        .fontSize(DesignSystem.Typography.size.xs)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ top: DesignSystem.Spacing.sm })
    }
    .onClick(action)
  }

  @Builder
  buildMenuSection() {
    Column() {
      Row() {
        Text($r('app.string.core_display'))
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)
      }
      .width('100%')
      .margin({ bottom: DesignSystem.Spacing.md })
      
      this.buildMenuGrid()
    }
    .width('100%')
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg
    })
  }

  @Builder
  buildMenuGrid() {
    Column({ space: DesignSystem.Spacing.md }) {
      ForEach(this.menuItems, (item: MenuItem) => {
        this.buildMenuItem(item)
      })
    }
    .width('100%')
  }

  @Builder
  buildMenuItem(item: MenuItem) {
    Row() {
      Row() {
        Text(item.icon)
          .fontSize(DesignSystem.IconSize.lg)
      }
      .width(48)
      .height(48)
      .borderRadius(DesignSystem.BorderRadius.lg)
      .linearGradient({
        angle: 135,
        colors: this.getGradientColors(item)
      })
      .justifyContent(FlexAlign.Center)
      .shadow({
        radius: 8,
        color: `${item.gradientStart}40`,
        offsetX: 0,
        offsetY: 4
      })
      .margin({ right: DesignSystem.Spacing.md })
      
      Column() {
        Text(item.title)
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.medium)
          .lineHeight(22)
        
        Text(item.desc)
          .fontSize(DesignSystem.Typography.size.xs)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .lineHeight(18)
          .margin({ top: DesignSystem.Spacing.xs })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      
      Row() {
        Text('›')
          .fontSize(DesignSystem.Typography.size.xl)
          .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
      }
      .width(32)
      .height(32)
      .borderRadius(DesignSystem.BorderRadius.md)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(72)
    .padding({
      left: DesignSystem.Spacing.md,
      right: DesignSystem.Spacing.md,
      top: DesignSystem.Spacing.sm,
      bottom: DesignSystem.Spacing.sm
    })
    .borderRadius(DesignSystem.BorderRadius.xl)
    .backgroundColor(this.pressedItemId === item.id ?
      DesignSystem.getActiveColor(this.isLightMode) :
      DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .shadow({
      radius: this.pressedItemId === item.id ? 2 : 4,
      color: this.isLightMode ? 'rgba(0,0,0,0.04)' : 'rgba(0,0,0,0.2)',
      offsetX: 0,
      offsetY: this.pressedItemId === item.id ? 1 : 2
    })
    .scale({
      x: this.pressedItemId === item.id ? 0.98 : 1,
      y: this.pressedItemId === item.id ? 0.98 : 1
    })
    .opacity(this.pressedItemId === item.id ? 0.9 : 1)
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      this.handleNavigation(item);
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedItemId = item.id;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedItemId = '';
      }
    })
  }

  @Builder
  buildFooter() {
    Column() {
      Text('Made with ❤️ for readers')
        .fontSize(DesignSystem.Typography.size.xs)
        .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
    }
    .width('100%')
    .padding(DesignSystem.Spacing.lg)
  }
}
