/**
 * 工具类统一导出
 * 集中管理所有工具类，便于维护和导入
 */

// 基础工具类
export { StringUtils } from './content/StringUtils';
export { HtmlUtils } from './content/HtmlUtils';
export { TextCleaner } from '../core/utils/TextCleaner';
export { ContentPurifier } from './content/ContentPurifier';
export { DataValidator } from './validation/DataValidator';
export { IdGenerator } from './content/IdGenerator';
export { showToast, ToastOptions } from './content/ToastUtils';

// 安全工具类
export { SecurityUtils } from './security/SecurityUtils';
export { SqlSecurityUtils } from './security/SqlSecurityUtils';
export { SafeRegex } from './security/SafeRegex';
export { SafeExpressionEngine } from './security/SafeExpressionEngine';
export { SourceSandbox } from './security/SourceSandbox';
export { JSSecurityConfig } from './security/JSSecurityConfig';

// 网络和数据工具类
export { NetworkAdapter, NetworkType, NetworkRequestOptions, NetworkError } from './network/NetworkAdapter';
export { NetworkManager } from './network/NetworkManager';
export { NetworkConfig } from './network/NetworkConfig';
export { FileManager } from './file/FileManager';

// 验证和解析工具类
export { default as SourceValidator } from './validation/SourceValidator';
export { default as SourceImportManager } from './validation/SourceImportManager';
export { SourceValidatorService, sourceValidatorService } from './validation/SourceValidatorService';
export { BookSourceManager } from './validation/BookSourceManager';
export { BookSourceDebugger } from './validation/BookSourceDebugger';
export { EnhancedSourceHealthManager, enhancedSourceHealthManager } from './EnhancedSourceHealthManager';

// 日志和监控工具类
export { Logger } from './performance/Logger';
export { LogCollector } from './performance/LogCollector';
export { PerformanceMonitor } from './performance/PerformanceMonitor';
export { debounce, throttle, SimpleCallback, ImageLoadConfig, AnimationConfig } from './performance/PerformanceUtils';
export { BackgroundTaskManager } from './performance/BackgroundTaskManager';
export { Semaphore } from './performance/Semaphore';

// 缓存工具类
export { RegexCache, cachedReplace } from './cache/RegexCache';
export { WeakRefCache } from './cache/WeakRefCache';
export { SearchCache } from './search/SearchCache';
export { ParseCache } from './cache/ParseCache';
export { PoolManager } from './cache/PoolManager';
export { ObjectPool } from './cache/ObjectPool';

// 爬虫和内容处理工具类
export { CrawlerManager } from './crawler/CrawlerManager';
export { CrawlerRequestHandler } from './crawler/CrawlerRequestHandler';
export { CrawlerMonitor } from './crawler/CrawlerMonitor';
export { RequestThrottler } from './crawler/RequestThrottler';
export { RequestEnhancer } from './crawler/RequestEnhancer';
export { ImageScraperService } from './crawler/ImageScraperService';
export { ImageScrapeManager } from './crawler/ImageScrapeManager';
export { ImageDetector } from './crawler/ImageDetector';

// 数据库工具类
export { DatabaseManager } from './file/DatabaseManager';
export { DatabaseSchema } from './database/DatabaseSchema';
export { BackupManager } from './file/BackupManager';

// 阅读器工具类
export { ThemeManager } from '../common/ThemeManager';

// 搜索工具类
export { BookSourceSearchEngine } from './search/BookSourceSearchEngine';
export { EnhancedBookSourceSearchEngine } from './search/EnhancedBookSourceSearchEngine';
export { default as SearchEnhancer } from './search/SearchEnhancer';
export { SearchQueryParser } from './search/SearchQueryParser';
export { SearchResultValidator } from './search/SearchResultValidator';
export { SearchImageEnhancer } from './search/SearchImageEnhancer';
export { SmartSourceSelector } from './search/SmartSourceSelector';

// JS引擎工具类
export { JSEngine } from './scripting/JSEngine';
export { EnhancedJSEngine } from './scripting/EnhancedJSEngine';
export { ScriptEngine } from './scripting/ScriptEngine';
export { AstroReadJSRuntime } from './scripting/AstroReadJSRuntime';

// 解析器工具类
export { BookSourceParser } from './parser/BookSourceParser';
export { ContentParser } from './parser/ContentParser';
export { CssSelectorParser } from './parser/CssSelectorParser';
export { HTMLParser } from './parser/HTMLParser';
export { EPUBParser } from './parser/EPUBParser';
export { TXTParser } from './parser/TXTParser';
export { LocalFileParser } from './parser/LocalFileParser';
export { FileParser } from './parser/FileParser';
export { ParserCore } from './parser/ParserCore';
export { IParser } from './parser/IParser';
export { RuleEngine } from './parser/RuleEngine';
export { AnalyzeRule } from './parser/AnalyzeRule';
export { SelectorCore } from './parser/SelectorCore';
export { XPathEngine } from './parser/XPathEngine';
export { AsyncChapterParser } from './parser/AsyncChapterParser';
export { AsyncContentParser } from './parser/AsyncContentParser';
export { AsyncCssSelectorParser } from './parser/AsyncCssSelectorParser';

// 内容处理工具类
export { ContentFilter } from './content/ContentFilter';
export { ContentProcessor } from './content/ContentProcessor';

// 类型定义重新导出
export type {
  ValidationRule,
  ValidationResult as DataValidationResult,
  CleaningOptions,
  MetadataRecord,
  BookDataValidation
} from './validation/DataValidator';

export type {
  PurifyConfig,
  PurifyResult,
  RemoveAdsResult
} from './content/ContentPurifier';

export type {
  SanitizeOptions,
  LinkInfo
} from './content/HtmlUtils';

// 其他工具类
export { AsyncTXTParser, asyncTXTParser, TXTParseResult, TXTChapter } from './AsyncTXTParser';
export { NetworkDiagnostics, networkDiagnostics, DiagnosticResult, NetworkStatus } from './NetworkDiagnostics';
export { SourceCleaner, sourceCleaner, FailedSource } from './SourceCleaner';
export { SearchFixer, searchFixer, FixReport } from './SearchFixer';
export { ErrorHandlingService, errorHandlingService, ErrorType, ErrorSeverity, DegradationStrategy, ErrorContext } from './ErrorHandlingService';
