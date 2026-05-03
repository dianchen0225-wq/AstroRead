import { DesignSystem } from '../../common/DesignSystem';

export type CapsuleIconName =
  'home' | 'search' | 'bookshelf' | 'source' | 'settings' |
  'add' | 'catalog' | 'brightness' | 'fontsize' | 'nightmode';

const SYSTEM_SYMBOL_MAP: Record<CapsuleIconName, string> = {
  home: 'sys.symbol.house',
  search: 'sys.symbol.magnifyingglass',
  bookshelf: 'sys.symbol.books_vertical',
  source: 'sys.symbol.link',
  settings: 'sys.symbol.gear',
  add: 'sys.symbol.plus',
  catalog: 'sys.symbol.list_bullet',
  brightness: 'sys.symbol.sun_min',
  fontsize: 'sys.symbol.textformat_size',
  nightmode: 'sys.symbol.moon'
};

const SVG_RESOURCE_MAP: Record<CapsuleIconName, string> = {
  home: 'app.media.nav_home',
  search: 'app.media.nav_search',
  bookshelf: 'app.media.nav_bookshelf',
  source: 'app.media.nav_source',
  settings: 'app.media.nav_settings',
  add: 'app.media.nav_add',
  catalog: 'app.media.nav_catalog',
  brightness: 'app.media.nav_brightness',
  fontsize: 'app.media.nav_fontsize',
  nightmode: 'app.media.nav_nightmode'
};

const TEXT_LABEL_MAP: Record<CapsuleIconName, string> = {
  home: '首页',
  search: '搜索',
  bookshelf: '书架',
  source: '书源',
  settings: '设置',
  add: '添加',
  catalog: '目录',
  brightness: '亮度',
  fontsize: '字体',
  nightmode: '夜间'
};

@ComponentV2
export struct SVGIcon {
  @Param name: CapsuleIconName = 'home';
  @Param isActive: boolean = false;
  @Param isLightMode: boolean = true;
  @Param renderSize: number = DesignSystem.CapsuleSVGIcon.renderSize;
  @Param useSystemSymbol: boolean = true;

  private iconColor: string = '#333333';
  private currentRenderMode: number = 0;

  aboutToAppear(): void {
    this.updateIconColor();
  }

  private updateIconColor(): void {
    this.iconColor = this.isLightMode
      ? DesignSystem.CapsuleDayNight.dayIconColor
      : DesignSystem.CapsuleDayNight.nightIconColor;
  }

  build() {
    Row() {
      if (this.useSystemSymbol && this.currentRenderMode === 0) {
        SymbolGlyph($r(SYSTEM_SYMBOL_MAP[this.name]))
          .fontColor([this.iconColor])
          .fontSize(this.renderSize)
      } else if (this.currentRenderMode <= 1) {
        Image($r(SVG_RESOURCE_MAP[this.name]))
          .width(this.renderSize)
          .height(this.renderSize)
          .fillColor(this.iconColor)
          .objectFit(ImageFit.Contain)
      } else {
        Text(TEXT_LABEL_MAP[this.name])
          .fontSize(10)
          .fontColor(this.iconColor)
          .textAlign(TextAlign.Center)
      }
    }
    .width(this.renderSize + 4)
    .height(this.renderSize + 4)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.isActive ? `${this.iconColor}${Math.round(DesignSystem.CapsuleSVGIcon.activeFillOpacity * 255).toString(16).padStart(2, '0')}` : 'transparent')
    .borderRadius(DesignSystem.CapsuleSVGIcon.cornerRadius)
  }
}
