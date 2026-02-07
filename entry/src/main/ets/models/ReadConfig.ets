/**
 * 页边距配置
 */
export interface MarginsConfig {
  top: number;
  bottom: number;
  left: number;
  right: number;
}

/**
 * 阅读配置数据模型
 */
export interface ReadConfig {
  fontSize: number;              // 字体大小（单位：sp）
  lineSpacing: number;           // 行间距（倍数）
  pageTurnMode: 'cover' | 'slide' | 'scroll' | 'simulation'; // 翻页模式
  backgroundColor: string;       // 背景颜色
  textColor: string;             // 文字颜色
  isNightMode: boolean;          // 是否夜间模式
  brightness: number;            // 亮度（0-1）
  autoScroll: boolean;           // 是否自动滚动
  scrollSpeed: number;           // 滚动速度
  fontFamily: string;            // 字体族
  margins: MarginsConfig;        // 页边距
}

/**
 * 默认页边距配置
 */
const DEFAULT_MARGINS: MarginsConfig = {
  top: 20,
  bottom: 20,
  left: 20,
  right: 20
};

/**
 * 默认阅读配置
 */
export const DEFAULT_READ_CONFIG: ReadConfig = {
  fontSize: 18,
  lineSpacing: 1.5,
  pageTurnMode: 'cover',
  backgroundColor: '#FFFFFF',
  textColor: '#333333',
  isNightMode: false,
  brightness: 0.5,
  autoScroll: false,
  scrollSpeed: 50,
  fontFamily: 'HarmonyOS Sans',
  margins: DEFAULT_MARGINS
};
