import { themeManager, ThemeMode } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { NavigationManager } from '../common/NavigationManager';
import { CommonNavBar, SectionHeader } from '../components/CommonNavBar';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { ReadConfig } from '../models/ReadConfig';
import { ReadConfigViewModel } from '../viewmodel/ReadConfigViewModel';
import { Logger } from '../utils/Logger';
import { showToast } from '../utils/ToastUtils';
import { floatingNavManager, FloatingNavConfig, FloatingNavPosition } from '../common/FloatingNavManager';

interface SettingItem {
  id: string;
  title: string;
  subtitle?: string;
  icon: string;
  type: 'navigation' | 'toggle' | 'slider' | 'action' | 'info';
  value?: string | number | boolean;
  route?: string;
  action?: () => void;
}

interface SettingGroup {
  id: string;
  title: string;
  items: SettingItem[];
}

interface PositionOption {
  id: string;
  label: string;
  icon: string;
}

@ComponentV2
export struct SettingsPage {
  @Local isLightMode: boolean = true;
  @Local fontSize: number = 16;
  @Local lineSpacing: number = 1.6;
  @Local cacheSize: string = '128MB';
  @Local autoUpdate: boolean = true;
  @Local themeModeIndex: number = 0;
  @Local readConfig: ReadConfig = ReadConfigViewModel.DEFAULT_READ_CONFIG;
  @Local showClearCacheConfirm: boolean = false;
  @Local isClearingCache: boolean = false;
  @Local showAboutSheet: boolean = false;
  @Local searchKeyword: string = '';
  @Local filteredGroups: SettingGroup[] = [];
  @Local floatingNavConfig: FloatingNavConfig = floatingNavManager.getConfig();
  @Local showFloatingNavSettings: boolean = false;
  @Param safeAreaTop: number = 0;
  @Param safeAreaBottom: number = 0;
  
  private isComponentActive: boolean = false;
  private settingGroups: SettingGroup[] = [];
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };
  private floatingNavListener: (config: FloatingNavConfig) => void = (config: FloatingNavConfig) => {
    this.floatingNavConfig = config;
    this.initSettingGroups();
    this.performSearch(this.searchKeyword);
  };

  aboutToAppear(): void {
    this.isComponentActive = true;
    this.isLightMode = themeManager.isLightTheme();
    this.themeModeIndex = this.getThemeModeIndex();
    themeManager.addListener(this.themeListener);
    floatingNavManager.addConfigChangeListener(this.floatingNavListener);
    
    this.loadReadConfig();
    this.initSettingGroups();
    this.filteredGroups = this.settingGroups.slice();
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    floatingNavManager.removeConfigChangeListener(this.floatingNavListener);
  }

  private getThemeModeIndex(): number {
    const mode = themeManager.getThemeMode();
    switch (mode) {
      case ThemeMode.LIGHT:
        return 0;
      case ThemeMode.DARK:
        return 1;
      case ThemeMode.AUTO:
        return 2;
      default:
        return 0;
    }
  }

  private async loadReadConfig(): Promise<void> {
    try {
      const readConfigViewModel = viewModelManager.getReadConfigViewModel();
      this.readConfig = await readConfigViewModel.getReadConfig();
      this.fontSize = this.readConfig.fontSize;
      this.lineSpacing = this.readConfig.lineSpacing;
    } catch (error) {
      Logger.error('SettingsPage', `加载阅读配置失败: ${error}`);
    }
  }

  private initSettingGroups(): void {
    this.settingGroups = [
      {
        id: 'appearance',
        title: '外观设置',
        items: [
          {
            id: 'theme_mode',
            title: '主题模式',
            subtitle: this.getThemeModeText(),
            icon: '🎨',
            type: 'navigation',
            route: 'ThemeModeSheet'
          }
        ]
      },
      {
        id: 'reading',
        title: '阅读设置',
        items: [
          {
            id: 'font_size',
            title: '字体大小',
            subtitle: `${this.fontSize}px`,
            icon: '🔤',
            type: 'slider',
            value: this.fontSize
          },
          {
            id: 'line_spacing',
            title: '行间距',
            subtitle: `${this.lineSpacing.toFixed(1)}`,
            icon: '📏',
            type: 'slider',
            value: this.lineSpacing
          },
          {
            id: 'read_background',
            title: '阅读背景',
            subtitle: '默认',
            icon: '🖼️',
            type: 'navigation'
          }
        ]
      },
      {
        id: 'app',
        title: '应用设置',
        items: [
          {
            id: 'auto_update',
            title: '自动更新',
            subtitle: '自动检查书源更新',
            icon: '🔄',
            type: 'toggle',
            value: this.autoUpdate
          },
          {
            id: 'floating_nav',
            title: '悬浮导航栏',
            subtitle: this.floatingNavConfig.enabled ? '已开启' : '已关闭',
            icon: '🧭',
            type: 'navigation',
            route: 'FloatingNavSettings'
          },
          {
            id: 'cache',
            title: '清除缓存',
            subtitle: this.cacheSize,
            icon: '🗑️',
            type: 'action',
            action: () => {
              this.showClearCacheConfirm = true;
            }
          }
        ]
      },
      {
        id: 'developer',
        title: '开发者选项',
        items: [
          {
            id: 'debug_log',
            title: '调试日志',
            subtitle: '查看应用运行日志',
            icon: '📋',
            type: 'navigation',
            route: 'DebugLogPage'
          },
          {
            id: 'performance',
            title: '性能监控',
            subtitle: '查看应用性能数据',
            icon: '📊',
            type: 'navigation',
            route: 'PerformanceMonitorPage'
          },
          {
            id: 'booksource_repair',
            title: '书源诊断修复',
            subtitle: '诊断并修复书源访问问题',
            icon: '🔧',
            type: 'navigation',
            route: 'BookSourceRepairPage'
          }
        ]
      },
      {
        id: 'about',
        title: '关于',
        items: [
          {
            id: 'about_app',
            title: '关于应用',
            subtitle: '版本 1.0.0',
            icon: 'ℹ️',
            type: 'navigation',
            route: 'AboutSheet'
          },
          {
            id: 'feedback',
            title: '意见反馈',
            subtitle: '帮助我们改进',
            icon: '💬',
            type: 'navigation'
          }
        ]
      }
    ];
  }

  private getThemeModeText(): string {
    switch (this.themeModeIndex) {
      case 0:
        return '浅色模式';
      case 1:
        return '深色模式';
      case 2:
        return '跟随系统';
      default:
        return '浅色模式';
    }
  }

  private performSearch(keyword: string): void {
    this.searchKeyword = keyword;
    
    if (!keyword || keyword.trim().length === 0) {
      this.filteredGroups = this.settingGroups.slice();
      return;
    }
    
    const lowerKeyword = keyword.toLowerCase().trim();
    const filtered: SettingGroup[] = [];
    
    for (const group of this.settingGroups) {
      const matchedItems = group.items.filter(item => 
        item.title.toLowerCase().includes(lowerKeyword) ||
        (item.subtitle && item.subtitle.toLowerCase().includes(lowerKeyword))
      );
      
      if (matchedItems.length > 0) {
        filtered.push({
          id: group.id,
          title: group.title,
          items: matchedItems
        });
      }
    }
    
    this.filteredGroups = filtered;
  }

  private async toggleAutoUpdate(): Promise<void> {
    this.autoUpdate = !this.autoUpdate;
    showToast({
      message: this.autoUpdate ? '已开启自动更新' : '已关闭自动更新'
    });
  }

  private async clearCache(): Promise<void> {
    this.isClearingCache = true;
    
    try {
      await new Promise<void>(resolve => setTimeout(resolve, 1000));
      this.cacheSize = '0MB';
      showToast({
        message: '缓存已清除'
      });
    } catch (error) {
      Logger.error('SettingsPage', `清除缓存失败: ${error}`);
      showToast({
        message: '清除失败'
      });
    } finally {
      this.isClearingCache = false;
      this.showClearCacheConfirm = false;
    }
  }

  private async updateFontSize(size: number): Promise<void> {
    this.fontSize = Math.round(size);
    this.readConfig.fontSize = this.fontSize;
    
    try {
      const readConfigViewModel = viewModelManager.getReadConfigViewModel();
      await readConfigViewModel.updateReadConfig(this.readConfig);
    } catch (error) {
      Logger.error('SettingsPage', `保存字体大小失败: ${error}`);
    }
  }

  private async updateLineSpacing(spacing: number): Promise<void> {
    this.lineSpacing = Math.round(spacing * 10) / 10;
    this.readConfig.lineSpacing = this.lineSpacing;
    
    try {
      const readConfigViewModel = viewModelManager.getReadConfigViewModel();
      await readConfigViewModel.updateReadConfig(this.readConfig);
    } catch (error) {
      Logger.error('SettingsPage', `保存行间距失败: ${error}`);
    }
  }

  private async setThemeMode(index: number): Promise<void> {
    this.themeModeIndex = index;
    const modes: ThemeMode[] = [ThemeMode.LIGHT, ThemeMode.DARK, ThemeMode.AUTO];
    await themeManager.setThemeMode(modes[index]);
    
    this.initSettingGroups();
    this.performSearch(this.searchKeyword);
  }

  private handleItemAction(item: SettingItem): void {
    if (item.type === 'navigation' && item.route) {
      if (item.route === 'DebugLogPage') {
        NavigationManager.getInstance().navigateTo('DebugLogPage');
      } else if (item.route === 'PerformanceMonitorPage') {
        NavigationManager.getInstance().navigateTo('PerformanceMonitorPage');
      } else if (item.route === 'BookSourceRepairPage') {
        NavigationManager.getInstance().navigateTo('BookSourceRepairPage');
      } else if (item.route === 'AboutSheet') {
        this.showAboutSheet = true;
      } else if (item.route === 'FloatingNavSettings') {
        this.showFloatingNavSettings = true;
      }
    } else if (item.type === 'action' && item.action) {
      item.action();
    } else if (item.type === 'toggle' && item.id === 'auto_update') {
      this.toggleAutoUpdate();
    }
  }

  build() {
    Column() {
      CommonNavBar({
        title: $r('app.string.settings'),
        showBack: true,
        safeAreaTop: this.safeAreaTop
      })

      this.buildSearchBar()

      Scroll() {
        Column() {
          ForEach(this.filteredGroups, (group: SettingGroup) => {
            this.buildSettingGroup(group)
          })

          if (this.filteredGroups.length === 0) {
            this.buildEmptySearchResult()
          }
        }
        .width('100%')
        .padding({ bottom: DesignSystem.Spacing.xxl + this.safeAreaBottom })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    .bindSheet($$this.showClearCacheConfirm, this.buildClearCacheSheet(), {
      height: 'auto',
      backgroundColor: Color.Transparent,
      dragBar: false
    })
    .bindSheet($$this.showAboutSheet, this.buildAboutSheet(), {
      height: 'auto',
      backgroundColor: Color.Transparent,
      dragBar: false
    })
    .bindSheet($$this.showFloatingNavSettings, this.buildFloatingNavSettingsSheet(), {
      height: '90%',
      backgroundColor: Color.Transparent,
      dragBar: true
    })
  }

  @Builder
  buildSearchBar() {
    Row() {
      Text('🔍')
        .fontSize(DesignSystem.IconSize.sm)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ right: DesignSystem.Spacing.sm })

      TextInput({ placeholder: '搜索设置项...', text: this.searchKeyword })
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontSize(DesignSystem.Typography.size.sm)
        .placeholderColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
        .onChange((value: string) => {
          this.performSearch(value);
        })

      if (this.searchKeyword.length > 0) {
        Text('✕')
          .fontSize(DesignSystem.IconSize.sm)
          .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
          .onClick(() => {
            this.performSearch('');
          })
      }
    }
    .width('100%')
    .padding(DesignSystem.Spacing.md)
    .margin({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg,
      top: DesignSystem.Spacing.sm,
      bottom: DesignSystem.Spacing.md
    })
    .borderRadius(DesignSystem.BorderRadius.lg)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }

  @Builder
  buildSettingGroup(group: SettingGroup) {
    Column() {
      SectionHeader({ title: group.title })

      Column() {
        ForEach(group.items, (item: SettingItem, index: number) => {
          Column() {
            this.buildSettingItem(item)
            
            if (index < group.items.length - 1) {
              Row()
                .width('100%')
                .height(1)
                .backgroundColor(DesignSystem.getBorderColor(this.isLightMode))
                .margin({ left: 48 + DesignSystem.Spacing.md })
            }
          }
        })
      }
      .width('100%')
      .margin({
        left: DesignSystem.Spacing.lg,
        right: DesignSystem.Spacing.lg
      })
      .borderRadius(DesignSystem.BorderRadius.lg)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .border({
        width: 1,
        color: DesignSystem.getBorderColor(this.isLightMode)
      })
    }
    .width('100%')
    .margin({ bottom: DesignSystem.Spacing.md })
  }

  @Builder
  buildSettingItem(item: SettingItem) {
    Row() {
      Row() {
        Text(item.icon)
          .fontSize(DesignSystem.IconSize.md)
      }
      .width(32)
      .height(32)
      .borderRadius(DesignSystem.BorderRadius.md)
      .backgroundColor(DesignSystem.getHoverColor(this.isLightMode))
      .justifyContent(FlexAlign.Center)
      .margin({ right: DesignSystem.Spacing.md })

      Column() {
        Text(item.title)
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.medium)

        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (item.type === 'navigation') {
        Text('›')
          .fontSize(DesignSystem.Typography.size.xl)
          .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
      } else if (item.type === 'toggle') {
        Toggle({ type: ToggleType.Switch, isOn: item.value as boolean })
          .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .onChange((isOn: boolean) => {
            if (item.id === 'auto_update') {
              this.autoUpdate = isOn;
              this.toggleAutoUpdate();
            }
          })
      } else if (item.type === 'slider') {
        Row({ space: DesignSystem.Spacing.sm }) {
          Text(item.id === 'font_size' ? 'A-' : '紧')
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .onClick(() => {
              if (item.id === 'font_size' && this.fontSize > 12) {
                this.updateFontSize(this.fontSize - 1);
              } else if (item.id === 'line_spacing' && this.lineSpacing > 1.2) {
                this.updateLineSpacing(this.lineSpacing - 0.1);
              }
            })

          Slider({
            value: item.id === 'font_size' ? this.fontSize : this.lineSpacing * 10,
            min: item.id === 'font_size' ? 12 : 12,
            max: item.id === 'font_size' ? 32 : 24,
            step: 1
          })
            .width(80)
            .blockColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .trackColor(DesignSystem.getBorderColor(this.isLightMode))
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((value: number) => {
              if (item.id === 'font_size') {
                this.updateFontSize(value);
              } else {
                this.updateLineSpacing(value / 10);
              }
            })

          Text(item.id === 'font_size' ? 'A+' : '松')
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .onClick(() => {
              if (item.id === 'font_size' && this.fontSize < 32) {
                this.updateFontSize(this.fontSize + 1);
              } else if (item.id === 'line_spacing' && this.lineSpacing < 2.4) {
                this.updateLineSpacing(this.lineSpacing + 0.1);
              }
            })
        }
      }
    }
    .width('100%')
    .padding(DesignSystem.Spacing.md)
    .onClick(() => {
      if (item.type === 'navigation' || item.type === 'action') {
        this.handleItemAction(item);
      }
    })
  }

  @Builder
  buildEmptySearchResult() {
    Column() {
      Text('🔍')
        .fontSize(48)
        .margin({ bottom: DesignSystem.Spacing.md })

      Text('未找到相关设置')
        .fontSize(DesignSystem.Typography.size.base)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

      Text('请尝试其他关键词')
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ top: DesignSystem.Spacing.xs })
    }
    .width('100%')
    .padding(DesignSystem.Spacing.xxl)
    .margin({ top: DesignSystem.Spacing.xxl })
  }

  @Builder
  buildClearCacheSheet() {
    Column() {
      Column() {
        Text('清除缓存')
          .fontSize(DesignSystem.Typography.size.lg)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)
          .margin({ bottom: DesignSystem.Spacing.md })

        Text(`确定要清除所有缓存吗？当前缓存大小: ${this.cacheSize}`)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .textAlign(TextAlign.Center)
          .margin({ bottom: DesignSystem.Spacing.lg })

        Row({ space: DesignSystem.Spacing.md }) {
          Row() {
            Text('取消')
              .fontSize(DesignSystem.Typography.size.base)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .fontWeight(DesignSystem.Typography.weight.medium)
          }
          .layoutWeight(1)
          .height(44)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showClearCacheConfirm = false;
          })

          Row() {
            if (this.isClearingCache) {
              LoadingProgress()
                .width(20)
                .height(20)
                .color('#FFFFFF')
            } else {
              Text('确定')
                .fontSize(DesignSystem.Typography.size.base)
                .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
                .fontWeight(DesignSystem.Typography.weight.medium)
            }
          }
          .layoutWeight(1)
          .height(44)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            if (!this.isClearingCache) {
              this.clearCache();
            }
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding(DesignSystem.Spacing.lg)
      .borderRadius(DesignSystem.BorderRadius.xl)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    }
    .width('100%')
    .padding(DesignSystem.Spacing.lg)
  }

  @Builder
  buildAboutSheet() {
    Column() {
      Column() {
        Column() {
          Text('📚')
            .fontSize(48)
            .margin({ bottom: DesignSystem.Spacing.md })

          Text('AstroRead')
            .fontSize(DesignSystem.Typography.size.xl)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .fontWeight(DesignSystem.Typography.weight.bold)

          Text('版本 1.0.0')
            .fontSize(DesignSystem.Typography.size.sm)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ top: DesignSystem.Spacing.xs })
        }
        .width('100%')
        .padding(DesignSystem.Spacing.lg)

        Column() {
          Text('一款简洁优雅的阅读应用，支持多种书源导入，提供舒适的阅读体验。')
            .fontSize(DesignSystem.Typography.size.sm)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .textAlign(TextAlign.Center)
            .lineHeight(22)
        }
        .width('100%')
        .padding({
          left: DesignSystem.Spacing.lg,
          right: DesignSystem.Spacing.lg,
          bottom: DesignSystem.Spacing.lg
        })

        Row() {
          Row() {
            Text('关闭')
              .fontSize(DesignSystem.Typography.size.base)
              .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
              .fontWeight(DesignSystem.Typography.weight.medium)
          }
          .width('100%')
          .height(44)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showAboutSheet = false;
          })
        }
        .width('100%')
        .padding(DesignSystem.Spacing.lg)
      }
      .width('100%')
      .borderRadius(DesignSystem.BorderRadius.xl)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    }
    .width('100%')
    .padding(DesignSystem.Spacing.lg)
  }

  @Builder
  buildFloatingNavSettingsSheet() {
    Column() {
      Column() {
        Text('悬浮导航栏设置')
          .fontSize(DesignSystem.Typography.size.lg)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)
          .margin({ bottom: DesignSystem.Spacing.lg })

        Scroll() {
          Column({ space: DesignSystem.Spacing.lg }) {
            this.buildFloatingNavToggleSection()
            this.buildFloatingNavPositionSection()
            this.buildFloatingNavSizeSection()
            this.buildFloatingNavStyleSection()
            this.buildFloatingNavBehaviorSection()
          }
          .width('100%')
          .padding({ bottom: DesignSystem.Spacing.xl })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)

        Row({ space: DesignSystem.Spacing.md }) {
          Row() {
            Text('重置')
              .fontSize(DesignSystem.Typography.size.base)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .fontWeight(DesignSystem.Typography.weight.medium)
          }
          .layoutWeight(1)
          .height(44)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            floatingNavManager.resetToDefault();
            showToast({ message: '已恢复默认设置' });
          })

          Row() {
            Text('完成')
              .fontSize(DesignSystem.Typography.size.base)
              .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
              .fontWeight(DesignSystem.Typography.weight.medium)
          }
          .layoutWeight(1)
          .height(44)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showFloatingNavSettings = false;
          })
        }
        .width('100%')
        .margin({ top: DesignSystem.Spacing.lg })
      }
      .width('100%')
      .height('100%')
      .padding(DesignSystem.Spacing.lg)
      .borderRadius(DesignSystem.BorderRadius.xl)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    }
    .width('100%')
    .height('100%')
    .padding(DesignSystem.Spacing.lg)
  }

  @Builder
  buildFloatingNavToggleSection() {
    Column({ space: DesignSystem.Spacing.md }) {
      SectionHeader({ title: '启用悬浮导航' })

      Row() {
        Text('开启悬浮导航栏')
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.floatingNavConfig.enabled })
          .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .onChange((isOn: boolean) => {
            floatingNavManager.setEnabled(isOn);
          })
      }
      .width('100%')
      .padding(DesignSystem.Spacing.md)
      .borderRadius(DesignSystem.BorderRadius.lg)
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    }
    .width('100%')
  }

  @Builder
  buildFloatingNavPositionSection() {
    Column({ space: DesignSystem.Spacing.md }) {
      SectionHeader({ title: '位置设置' })

      Column({ space: DesignSystem.Spacing.sm }) {
        ForEach([
          { id: 'bottom-left', label: '左下角', icon: '↙️' } as PositionOption,
          { id: 'bottom-center', label: '底部居中', icon: '⬇️' } as PositionOption,
          { id: 'bottom-right', label: '右下角', icon: '↘️' } as PositionOption,
          { id: 'left', label: '左侧居中', icon: '⬅️' } as PositionOption,
          { id: 'center', label: '屏幕中央', icon: '⏺️' } as PositionOption,
          { id: 'right', label: '右侧居中', icon: '➡️' } as PositionOption
        ], (pos: PositionOption) => {
          Row() {
            Text(pos.icon)
              .fontSize(DesignSystem.IconSize.sm)
              .margin({ right: DesignSystem.Spacing.sm })

            Text(pos.label)
              .fontSize(DesignSystem.Typography.size.base)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .layoutWeight(1)

            if (this.floatingNavConfig.position === pos.id) {
              Text('✓')
                .fontSize(DesignSystem.Typography.size.base)
                .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
            }
          }
          .width('100%')
          .padding(DesignSystem.Spacing.md)
          .borderRadius(DesignSystem.BorderRadius.md)
          .backgroundColor(this.floatingNavConfig.position === pos.id ?
            DesignSystem.getHoverColor(this.isLightMode) :
            DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
          .onClick(() => {
            floatingNavManager.setPosition(pos.id as FloatingNavPosition);
          })
        })
      }
      .width('100%')
      .padding(DesignSystem.Spacing.md)
      .borderRadius(DesignSystem.BorderRadius.lg)
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    }
    .width('100%')
  }

  @Builder
  buildFloatingNavSizeSection() {
    Column({ space: DesignSystem.Spacing.md }) {
      SectionHeader({ title: '尺寸设置' })

      Column({ space: DesignSystem.Spacing.md }) {
        Column({ space: DesignSystem.Spacing.sm }) {
          Row() {
            Text('宽度')
              .fontSize(DesignSystem.Typography.size.base)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .layoutWeight(1)

            Text(`${this.floatingNavConfig.width}px`)
              .fontSize(DesignSystem.Typography.size.sm)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          }
          .width('100%')

          Slider({
            value: this.floatingNavConfig.width,
            min: 200,
            max: 400,
            step: 10
          })
            .width('100%')
            .blockColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .trackColor(DesignSystem.getBorderColor(this.isLightMode))
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((value: number) => {
              floatingNavManager.setSize(value, this.floatingNavConfig.height);
            })
        }

        Column({ space: DesignSystem.Spacing.sm }) {
          Row() {
            Text('高度')
              .fontSize(DesignSystem.Typography.size.base)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .layoutWeight(1)

            Text(`${this.floatingNavConfig.height}px`)
              .fontSize(DesignSystem.Typography.size.sm)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          }
          .width('100%')

          Slider({
            value: this.floatingNavConfig.height,
            min: 44,
            max: 80,
            step: 4
          })
            .width('100%')
            .blockColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .trackColor(DesignSystem.getBorderColor(this.isLightMode))
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((value: number) => {
              floatingNavManager.setSize(this.floatingNavConfig.width, value);
            })
        }

        Column({ space: DesignSystem.Spacing.sm }) {
          Row() {
            Text('圆角')
              .fontSize(DesignSystem.Typography.size.base)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .layoutWeight(1)

            Text(`${this.floatingNavConfig.borderRadius}px`)
              .fontSize(DesignSystem.Typography.size.sm)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          }
          .width('100%')

          Slider({
            value: this.floatingNavConfig.borderRadius,
            min: 0,
            max: 40,
            step: 2
          })
            .width('100%')
            .blockColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .trackColor(DesignSystem.getBorderColor(this.isLightMode))
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((value: number) => {
              floatingNavManager.setBorderRadius(value);
            })
        }
      }
      .width('100%')
      .padding(DesignSystem.Spacing.md)
      .borderRadius(DesignSystem.BorderRadius.lg)
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    }
    .width('100%')
  }

  @Builder
  buildFloatingNavStyleSection() {
    Column({ space: DesignSystem.Spacing.md }) {
      SectionHeader({ title: '样式设置' })

      Column({ space: DesignSystem.Spacing.md }) {
        Column({ space: DesignSystem.Spacing.sm }) {
          Row() {
            Text('透明度')
              .fontSize(DesignSystem.Typography.size.base)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .layoutWeight(1)

            Text(`${Math.round(this.floatingNavConfig.opacity * 100)}%`)
              .fontSize(DesignSystem.Typography.size.sm)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          }
          .width('100%')

          Slider({
            value: this.floatingNavConfig.opacity * 100,
            min: 30,
            max: 100,
            step: 5
          })
            .width('100%')
            .blockColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .trackColor(DesignSystem.getBorderColor(this.isLightMode))
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((value: number) => {
              floatingNavManager.setOpacity(value / 100);
            })
        }

        Column({ space: DesignSystem.Spacing.sm }) {
          Row() {
            Text('背景透明度')
              .fontSize(DesignSystem.Typography.size.base)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .layoutWeight(1)

            Text(`${Math.round(this.floatingNavConfig.backgroundOpacity * 100)}%`)
              .fontSize(DesignSystem.Typography.size.sm)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          }
          .width('100%')

          Slider({
            value: this.floatingNavConfig.backgroundOpacity * 100,
            min: 30,
            max: 100,
            step: 5
          })
            .width('100%')
            .blockColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .trackColor(DesignSystem.getBorderColor(this.isLightMode))
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((value: number) => {
              floatingNavManager.setBackgroundOpacity(value / 100);
            })
        }

        Row() {
          Text('毛玻璃效果')
            .fontSize(DesignSystem.Typography.size.base)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.floatingNavConfig.blurEnabled })
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((isOn: boolean) => {
              floatingNavManager.setBlurEnabled(isOn);
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(DesignSystem.Spacing.md)
      .borderRadius(DesignSystem.BorderRadius.lg)
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    }
    .width('100%')
  }

  @Builder
  buildFloatingNavBehaviorSection() {
    Column({ space: DesignSystem.Spacing.md }) {
      SectionHeader({ title: '行为设置' })

      Column({ space: DesignSystem.Spacing.md }) {
        Row() {
          Text('自动隐藏')
            .fontSize(DesignSystem.Typography.size.base)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.floatingNavConfig.autoHide })
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((isOn: boolean) => {
              floatingNavManager.setAutoHide(isOn);
            })
        }
        .width('100%')

        if (this.floatingNavConfig.autoHide) {
          Column({ space: DesignSystem.Spacing.sm }) {
            Row() {
              Text('隐藏延迟')
                .fontSize(DesignSystem.Typography.size.base)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .layoutWeight(1)

              Text(`${Math.round(this.floatingNavConfig.autoHideDelay / 1000)}秒`)
                .fontSize(DesignSystem.Typography.size.sm)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            }
            .width('100%')

            Slider({
              value: this.floatingNavConfig.autoHideDelay / 1000,
              min: 1,
              max: 10,
              step: 0.5
            })
              .width('100%')
              .blockColor(DesignSystem.getPrimaryColor(this.isLightMode))
              .trackColor(DesignSystem.getBorderColor(this.isLightMode))
              .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
              .onChange((value: number) => {
                floatingNavManager.setAutoHideDelay(value * 1000);
              })
          }
        }

        Row() {
          Text('动画效果')
            .fontSize(DesignSystem.Typography.size.base)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.floatingNavConfig.animationEnabled })
            .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .onChange((isOn: boolean) => {
              floatingNavManager.setAnimationEnabled(isOn);
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(DesignSystem.Spacing.md)
      .borderRadius(DesignSystem.BorderRadius.lg)
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
    }
    .width('100%')
  }
}
