/**
 * AppConfigManager - 统一配置管理器
 * 整合网络、数据库、缓存、UI 等所有配置
 */

import { NetworkConfigManager, DEFAULT_NETWORK_CONFIG, AGGRESSIVE_NETWORK_CONFIG, CONSERVATIVE_NETWORK_CONFIG } from '../utils/NetworkConfig';
import type { AppConfig as NetworkAppConfig } from '../utils/NetworkConfig';

// ========== 数据库配置 ==========
export interface DatabaseConfig {
  name: string;
  version: number;
  enableWAL: boolean;
  enableForeignKey: boolean;
  busyTimeout: number;
  poolSize: number;
}

export const DEFAULT_DATABASE_CONFIG: DatabaseConfig = {
  name: 'AstroRead.db',
  version: 1,
  enableWAL: true,
  enableForeignKey: true,
  busyTimeout: 5000,
  poolSize: 5
};

// ========== 缓存配置 ==========
export interface CacheConfig {
  parseCacheMaxSize: number;
  parseCacheTTL: number;
  imageCacheMaxSize: number;
  imageCacheTTL: number;
  requestCacheMaxSize: number;
  requestCacheTTL: number;
  regexCacheMaxSize: number;
}

export const DEFAULT_CACHE_CONFIG: CacheConfig = {
  parseCacheMaxSize: 100,
  parseCacheTTL: 30 * 60 * 1000, // 30 分钟
  imageCacheMaxSize: 50,
  imageCacheTTL: 24 * 60 * 60 * 1000, // 24 小时
  requestCacheMaxSize: 20,
  requestCacheTTL: 5 * 60 * 1000, // 5 分钟
  regexCacheMaxSize: 50
};

// ========== UI 配置 ==========
export interface UIConfig {
  theme: 'light' | 'dark' | 'auto';
  fontSize: number;
  lineHeight: number;
  pageMargin: number;
  animationEnabled: boolean;
  skeletonScreenEnabled: boolean;
  toastDuration: number;
}

export const DEFAULT_UI_CONFIG: UIConfig = {
  theme: 'auto',
  fontSize: 18,
  lineHeight: 1.8,
  pageMargin: 16,
  animationEnabled: true,
  skeletonScreenEnabled: true,
  toastDuration: 2000
};

// ========== 阅读配置 ==========
export interface ReadingConfig {
  fontSize: number;
  lineHeight: number;
  letterSpacing: number;
  paragraphSpacing: number;
  pageTurnAnimation: 'none' | 'slide' | 'cover' | 'simulation';
  keepScreenOn: boolean;
  volumeKeyPageTurn: boolean;
  tapToTurnPage: boolean;
  autoBrightness: boolean;
  brightness: number;
  backgroundColor: string;
  textColor: string;
}

export const DEFAULT_READING_CONFIG: ReadingConfig = {
  fontSize: 18,
  lineHeight: 1.8,
  letterSpacing: 0.5,
  paragraphSpacing: 12,
  pageTurnAnimation: 'slide',
  keepScreenOn: true,
  volumeKeyPageTurn: true,
  tapToTurnPage: true,
  autoBrightness: true,
  brightness: 0.5,
  backgroundColor: '#FFFFFF',
  textColor: '#333333'
};

// ========== 安全配置 ==========
export interface SecurityConfig {
  enableSSLVerification: boolean;
  enableContentSanitization: boolean;
  enableSourceValidation: boolean;
  maxRequestSize: number;
  maxResponseSize: number;
  enableSafeRegex: boolean;
  regexTimeout: number;
}

export const DEFAULT_SECURITY_CONFIG: SecurityConfig = {
  enableSSLVerification: false,
  enableContentSanitization: true,
  enableSourceValidation: true,
  maxRequestSize: 10 * 1024 * 1024,
  maxResponseSize: 10 * 1024 * 1024,
  enableSafeRegex: true,
  regexTimeout: 2000
};

// ========== 日志配置 ==========
export interface LogConfig {
  level: 'debug' | 'info' | 'warn' | 'error' | 'none';
  enableConsole: boolean;
  enableFile: boolean;
  maxFileSize: number;
  maxFileCount: number;
  sensitiveFields: string[];
}

export const DEFAULT_LOG_CONFIG: LogConfig = {
  level: 'info',
  enableConsole: true,
  enableFile: false,
  maxFileSize: 5 * 1024 * 1024,
  maxFileCount: 3,
  sensitiveFields: ['token', 'password', 'secret', 'key', 'auth']
};

// ========== 完整应用配置 ==========
export interface AppConfig {
  network: NetworkAppConfig;
  database: DatabaseConfig;
  cache: CacheConfig;
  ui: UIConfig;
  reading: ReadingConfig;
  security: SecurityConfig;
  log: LogConfig;
}

// ========== 预设配置 ==========
export const DEFAULT_APP_CONFIG: AppConfig = {
  network: DEFAULT_NETWORK_CONFIG,
  database: DEFAULT_DATABASE_CONFIG,
  cache: DEFAULT_CACHE_CONFIG,
  ui: DEFAULT_UI_CONFIG,
  reading: DEFAULT_READING_CONFIG,
  security: DEFAULT_SECURITY_CONFIG,
  log: DEFAULT_LOG_CONFIG
};

function createNetworkConfig(overrides: Partial<NetworkAppConfig>, base: NetworkAppConfig = DEFAULT_NETWORK_CONFIG): NetworkAppConfig {
  const config: NetworkAppConfig = {
    retry: overrides.retry ?? base.retry,
    timeout: overrides.timeout ?? base.timeout,
    rateLimit: overrides.rateLimit ?? base.rateLimit,
    degradation: overrides.degradation ?? base.degradation,
    imageScraper: overrides.imageScraper ?? base.imageScraper,
    search: overrides.search ?? base.search
  };
  return config;
}

function createDatabaseConfig(overrides: Partial<DatabaseConfig>, base: DatabaseConfig = DEFAULT_DATABASE_CONFIG): DatabaseConfig {
  const config: DatabaseConfig = {
    name: overrides.name ?? base.name,
    version: overrides.version ?? base.version,
    enableWAL: overrides.enableWAL ?? base.enableWAL,
    enableForeignKey: overrides.enableForeignKey ?? base.enableForeignKey,
    busyTimeout: overrides.busyTimeout ?? base.busyTimeout,
    poolSize: overrides.poolSize ?? base.poolSize
  };
  return config;
}

function createReadingConfig(overrides: Partial<ReadingConfig>, base: ReadingConfig = DEFAULT_READING_CONFIG): ReadingConfig {
  const config: ReadingConfig = {
    fontSize: overrides.fontSize ?? base.fontSize,
    lineHeight: overrides.lineHeight ?? base.lineHeight,
    letterSpacing: overrides.letterSpacing ?? base.letterSpacing,
    paragraphSpacing: overrides.paragraphSpacing ?? base.paragraphSpacing,
    pageTurnAnimation: overrides.pageTurnAnimation ?? base.pageTurnAnimation,
    keepScreenOn: overrides.keepScreenOn ?? base.keepScreenOn,
    volumeKeyPageTurn: overrides.volumeKeyPageTurn ?? base.volumeKeyPageTurn,
    tapToTurnPage: overrides.tapToTurnPage ?? base.tapToTurnPage,
    autoBrightness: overrides.autoBrightness ?? base.autoBrightness,
    brightness: overrides.brightness ?? base.brightness,
    backgroundColor: overrides.backgroundColor ?? base.backgroundColor,
    textColor: overrides.textColor ?? base.textColor
  };
  return config;
}

function createCacheConfig(overrides: Partial<CacheConfig>, base: CacheConfig = DEFAULT_CACHE_CONFIG): CacheConfig {
  const config: CacheConfig = {
    parseCacheMaxSize: overrides.parseCacheMaxSize ?? base.parseCacheMaxSize,
    parseCacheTTL: overrides.parseCacheTTL ?? base.parseCacheTTL,
    imageCacheMaxSize: overrides.imageCacheMaxSize ?? base.imageCacheMaxSize,
    imageCacheTTL: overrides.imageCacheTTL ?? base.imageCacheTTL,
    requestCacheMaxSize: overrides.requestCacheMaxSize ?? base.requestCacheMaxSize,
    requestCacheTTL: overrides.requestCacheTTL ?? base.requestCacheTTL,
    regexCacheMaxSize: overrides.regexCacheMaxSize ?? base.regexCacheMaxSize
  };
  return config;
}

function createUIConfig(overrides: Partial<UIConfig>, base: UIConfig = DEFAULT_UI_CONFIG): UIConfig {
  const config: UIConfig = {
    theme: overrides.theme ?? base.theme,
    fontSize: overrides.fontSize ?? base.fontSize,
    lineHeight: overrides.lineHeight ?? base.lineHeight,
    pageMargin: overrides.pageMargin ?? base.pageMargin,
    animationEnabled: overrides.animationEnabled ?? base.animationEnabled,
    skeletonScreenEnabled: overrides.skeletonScreenEnabled ?? base.skeletonScreenEnabled,
    toastDuration: overrides.toastDuration ?? base.toastDuration
  };
  return config;
}

function createSecurityConfig(overrides: Partial<SecurityConfig>, base: SecurityConfig = DEFAULT_SECURITY_CONFIG): SecurityConfig {
  const config: SecurityConfig = {
    enableSSLVerification: overrides.enableSSLVerification ?? base.enableSSLVerification,
    enableContentSanitization: overrides.enableContentSanitization ?? base.enableContentSanitization,
    enableSourceValidation: overrides.enableSourceValidation ?? base.enableSourceValidation,
    maxRequestSize: overrides.maxRequestSize ?? base.maxRequestSize,
    maxResponseSize: overrides.maxResponseSize ?? base.maxResponseSize,
    enableSafeRegex: overrides.enableSafeRegex ?? base.enableSafeRegex,
    regexTimeout: overrides.regexTimeout ?? base.regexTimeout
  };
  return config;
}

function createLogConfig(overrides: Partial<LogConfig>, base: LogConfig = DEFAULT_LOG_CONFIG): LogConfig {
  const config: LogConfig = {
    level: overrides.level ?? base.level,
    enableConsole: overrides.enableConsole ?? base.enableConsole,
    enableFile: overrides.enableFile ?? base.enableFile,
    maxFileSize: overrides.maxFileSize ?? base.maxFileSize,
    maxFileCount: overrides.maxFileCount ?? base.maxFileCount,
    sensitiveFields: overrides.sensitiveFields ?? base.sensitiveFields
  };
  return config;
}

export const PERFORMANCE_APP_CONFIG: AppConfig = {
  network: AGGRESSIVE_NETWORK_CONFIG,
  database: createDatabaseConfig({ poolSize: 8 }),
  cache: createCacheConfig({ parseCacheMaxSize: 200, regexCacheMaxSize: 100 }),
  ui: createUIConfig({ animationEnabled: false, skeletonScreenEnabled: false }),
  reading: DEFAULT_READING_CONFIG,
  security: DEFAULT_SECURITY_CONFIG,
  log: createLogConfig({ level: 'warn' })
};

export const SAFE_APP_CONFIG: AppConfig = {
  network: CONSERVATIVE_NETWORK_CONFIG,
  database: DEFAULT_DATABASE_CONFIG,
  cache: DEFAULT_CACHE_CONFIG,
  ui: DEFAULT_UI_CONFIG,
  reading: DEFAULT_READING_CONFIG,
  security: createSecurityConfig({
    enableSSLVerification: true,
    enableContentSanitization: true,
    enableSafeRegex: true
  }),
  log: createLogConfig({ level: 'debug' })
};

/**
 * 统一配置管理器
 */
export class AppConfigManager {
  private static instance: AppConfigManager | null = null;
  private config: AppConfig;
  private networkConfigManager: NetworkConfigManager;
  private listeners: Map<string, Set<(config: AppConfig) => void>> = new Map();

  private constructor() {
    this.config = DEFAULT_APP_CONFIG;
    this.networkConfigManager = NetworkConfigManager.getInstance();
  }

  static getInstance(): AppConfigManager {
    if (!AppConfigManager.instance) {
      AppConfigManager.instance = new AppConfigManager();
    }
    return AppConfigManager.instance;
  }

  /**
   * 获取完整配置
   */
  getConfig(): AppConfig {
    return this.config;
  }

  /**
   * 设置完整配置
   */
  setConfig(config: AppConfig): void {
    this.config = config;
    this.networkConfigManager.setConfig(config.network);
    this.notifyListeners('config');
  }

  /**
   * 获取网络配置
   */
  getNetworkConfig(): NetworkAppConfig {
    return this.config.network;
  }

  /**
   * 获取数据库配置
   */
  getDatabaseConfig(): DatabaseConfig {
    return this.config.database;
  }

  /**
   * 获取缓存配置
   */
  getCacheConfig(): CacheConfig {
    return this.config.cache;
  }

  /**
   * 获取 UI 配置
   */
  getUIConfig(): UIConfig {
    return this.config.ui;
  }

  /**
   * 获取阅读配置
   */
  getReadingConfig(): ReadingConfig {
    return this.config.reading;
  }

  /**
   * 获取安全配置
   */
  getSecurityConfig(): SecurityConfig {
    return this.config.security;
  }

  /**
   * 获取日志配置
   */
  getLogConfig(): LogConfig {
    return this.config.log;
  }

  /**
   * 更新网络配置
   */
  updateNetworkConfig(config: Partial<NetworkAppConfig>): void {
    this.config.network = createNetworkConfig(config, this.config.network);
    this.networkConfigManager.setConfig(this.config.network);
    this.notifyListeners('network');
  }

  /**
   * 更新数据库配置
   */
  updateDatabaseConfig(config: Partial<DatabaseConfig>): void {
    this.config.database = createDatabaseConfig(config, this.config.database);
    this.notifyListeners('database');
  }

  /**
   * 更新缓存配置
   */
  updateCacheConfig(config: Partial<CacheConfig>): void {
    this.config.cache = createCacheConfig(config, this.config.cache);
    this.notifyListeners('cache');
  }

  /**
   * 更新 UI 配置
   */
  updateUIConfig(config: Partial<UIConfig>): void {
    this.config.ui = createUIConfig(config, this.config.ui);
    this.notifyListeners('ui');
  }

  /**
   * 更新阅读配置
   */
  updateReadingConfig(config: Partial<ReadingConfig>): void {
    this.config.reading = createReadingConfig(config, this.config.reading);
    this.notifyListeners('reading');
  }

  /**
   * 更新安全配置
   */
  updateSecurityConfig(config: Partial<SecurityConfig>): void {
    this.config.security = createSecurityConfig(config, this.config.security);
    this.notifyListeners('security');
  }

  /**
   * 更新日志配置
   */
  updateLogConfig(config: Partial<LogConfig>): void {
    this.config.log = createLogConfig(config, this.config.log);
    this.notifyListeners('log');
  }

  /**
   * 使用预设配置
   */
  usePreset(preset: 'default' | 'performance' | 'safe'): void {
    switch (preset) {
      case 'performance':
        this.setConfig(PERFORMANCE_APP_CONFIG);
        break;
      case 'safe':
        this.setConfig(SAFE_APP_CONFIG);
        break;
      default:
        this.setConfig(DEFAULT_APP_CONFIG);
    }
  }

  /**
   * 监听配置变化
   */
  onChange(key: string, callback: (config: AppConfig) => void): () => void {
    if (!this.listeners.has(key)) {
      this.listeners.set(key, new Set());
    }
    this.listeners.get(key)!.add(callback);

    // 返回取消监听函数
    return () => {
      this.listeners.get(key)?.delete(callback);
    };
  }

  private notifyListeners(key: string): void {
    const listeners = this.listeners.get(key);
    if (listeners) {
      listeners.forEach(callback => callback(this.config));
    }
    // 通知全局监听器
    const globalListeners = this.listeners.get('config');
    if (globalListeners) {
      globalListeners.forEach(callback => callback(this.config));
    }
  }

  /**
   * 重置为默认配置
   */
  reset(): void {
    this.setConfig(DEFAULT_APP_CONFIG);
  }

  /**
   * 导出配置为 JSON
   */
  exportConfig(): string {
    return JSON.stringify(this.config, null, 2);
  }

  /**
   * 从 JSON 导入配置
   */
  importConfig(json: string): boolean {
    try {
      const config = JSON.parse(json) as AppConfig;
      this.setConfig(config);
      return true;
    } catch {
      return false;
    }
  }
}

export const appConfigManager = AppConfigManager.getInstance();
export default AppConfigManager;
