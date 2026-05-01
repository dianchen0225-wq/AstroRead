/**
 * FeatureMenuList - 首页功能菜单列表业务组件
 * 渲染四个核心功能菜单项：我的书架、搜索书籍、书源管理、设置
 * 使用 HomeTokens 低饱和渐变色配置
 */

import { DesignSystem } from '../common/DesignSystem';
import { FeatureListItem, MenuItemData } from './FeatureListItem';

@ComponentV2
export struct FeatureMenuList {
  @Param isLightMode: boolean = true;
  @Param onMenuClick: (tabIndex: number) => void = () => {};

  private menuItems: MenuItemData[] = [
    {
      id: 'bookshelf',
      title: $r('app.string.my_bookshelf'),
      desc: $r('app.string.my_bookshelf_desc'),
      icon: $r('app.string.icon_bookshelf'),
      gradientKey: 'bookshelf',
      route: 'BookshelfPage',
      tabIndex: 2
    },
    {
      id: 'search',
      title: $r('app.string.search_books'),
      desc: $r('app.string.search_books_desc'),
      icon: $r('app.string.icon_search_books'),
      gradientKey: 'search',
      route: 'SearchPage',
      tabIndex: 1
    },
    {
      id: 'source',
      title: $r('app.string.source_management'),
      desc: $r('app.string.source_management_desc'),
      icon: $r('app.string.icon_source_management'),
      gradientKey: 'source',
      route: 'SourcePage',
      tabIndex: 3
    },
    {
      id: 'settings',
      title: $r('app.string.settings'),
      desc: $r('app.string.settings_desc'),
      icon: $r('app.string.icon_settings'),
      gradientKey: 'settings',
      route: 'SettingsPage',
      tabIndex: 4
    }
  ];

  build() {
    Column() {
      // 区块标题
      Row() {
        Text($r('app.string.core_display'))
          .fontSize(DesignSystem.Typography.size.base)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.semibold)
      }
      .width('100%')
      .margin({ bottom: DesignSystem.Spacing.md })

      // 菜单列表
      this.buildMenuList()
    }
    .width('100%')
    .padding({
      left: DesignSystem.Spacing.lg,
      right: DesignSystem.Spacing.lg
    })
  }

  @Builder
  buildMenuList() {
    Column({ space: DesignSystem.Spacing.md }) {
      ForEach(this.menuItems, (item: MenuItemData) => {
        FeatureListItem({
          isLightMode: this.isLightMode,
          item: item,
          onItemClick: (clickedItem: MenuItemData) => {
            if (clickedItem.tabIndex !== undefined) {
              this.onMenuClick(clickedItem.tabIndex);
            }
          }
        })
      })
    }
    .width('100%')
  }
}
