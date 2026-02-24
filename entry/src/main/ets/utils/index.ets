/**
 * 工具类统一导出
 * 集中管理所有工具类，便于维护和导入
 */

// 基础工具类
export { StringUtils } from './StringUtils';
export { HtmlUtils } from './HtmlUtils';
export { TextCleaner } from '../core/utils/TextCleaner';
export { ContentPurifier } from './ContentPurifier';
export { DataValidator } from './DataValidator';

// 安全工具类
export { SecurityUtils } from './SecurityUtils';
export { SqlSecurityUtils } from './SqlSecurityUtils';
export { SafeRegex } from './SafeRegex';

// 网络和数据工具类
export { NetworkAdapter, NetworkType, NetworkRequestOptions, NetworkError } from './NetworkAdapter';
export { NetworkManager } from './NetworkManager';
export { FileManager } from './FileManager';

// 验证和解析工具类
export { default as SourceValidator } from './SourceValidator';
export { default as SourceImportManager } from './SourceImportManager';

// 日志和监控工具类
export { Logger } from './Logger';
export { LogCollector } from './LogCollector';
export { PerformanceMonitor } from './PerformanceMonitor';

// 缓存工具类
export { RegexCache, cachedReplace } from './RegexCache';
export { WeakRefCache } from './WeakRefCache';
export { SearchCache } from './SearchCache';

// 爬虫和内容处理工具类
export { CrawlerManager } from './CrawlerManager';

// 数据库工具类
export { DatabaseManager } from './DatabaseManager';
export { DatabaseSchema } from './database/DatabaseSchema';
export { BackupManager } from './BackupManager';

// 阅读器工具类
export { ThemeManager } from '../common/ThemeManager';

// 类型定义重新导出
export type { 
  ValidationRule, 
  ValidationResult as DataValidationResult, 
  CleaningOptions,
  MetadataRecord,
  BookDataValidation 
} from './DataValidator';

export type { 
  PurifyConfig, 
  PurifyResult, 
  RemoveAdsResult 
} from './ContentPurifier';

export type { 
  SanitizeOptions, 
  LinkInfo 
} from './HtmlUtils';
