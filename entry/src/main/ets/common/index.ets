/**
 * Common Module Index
 * 公共资源模块统一导出
 */

// 常量
export {
  TimeConstants, CacheConstants, SearchConstants, ContentConstants,
  HttpStatusCodes, DatabaseConstants, SecurityConstants, RetryConstants,
  NetworkConstants, FileConstants, LogConstants, PaginationConstants,
  BookSourceConstants
} from '../constants/AppConstants';

// 样式
export { AppTypography, AppSpacing, AppBorderRadius, AppShadows, AppAnimation } from '../styles/ComponentStyles';
export { ResponsiveUtils } from '../styles/ResponsiveUtils';

// 主题
export { ThemeManager } from './ThemeManager';
export { DesignSystem } from './DesignSystem';
export { HomeTokens } from './HomeTokens';

// 通用工具 - 从 utils 子目录导入
export { NavigationManager } from './NavigationManager';
export { showToast } from '../utils/content/ToastUtils';
export { StringUtils } from '../utils/content/StringUtils';
export { HtmlUtils } from '../utils/content/HtmlUtils';
export { IdGenerator } from '../utils/content/IdGenerator';
