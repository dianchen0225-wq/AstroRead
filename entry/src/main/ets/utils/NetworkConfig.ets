/**
 * NetworkConfig - 网络请求配置
 * 集中管理网络请求的超时、重试、降级等策略
 */

export interface RetryConfig {
  maxRetries: number;
  baseDelay: number;
  maxDelay: number;
  retryableStatusCodes: number[];
  retryableErrorTypes: string[];
}

export interface TimeoutConfig {
  connectTimeout: number;
  readTimeout: number;
  searchTimeout: number;
  chapterTimeout: number;
}

export interface RateLimitConfig {
  maxConcurrent: number;
  requestInterval: number;
  burstAllowance: number;
}

export interface DegradationConfig {
  fastFailThreshold: number;
  disableAfterConsecutiveFailures: number;
  recoveryCheckInterval: number;
  minHealthyScore: number;
}

export interface NetworkConfig {
  retry: RetryConfig;
  timeout: TimeoutConfig;
  rateLimit: RateLimitConfig;
  degradation: DegradationConfig;
}

/**
 * 默认网络配置
 */
export const DEFAULT_NETWORK_CONFIG: NetworkConfig = {
  retry: {
    maxRetries: 2,
    baseDelay: 500,
    maxDelay: 3000,
    retryableStatusCodes: [408, 429, 500, 502, 503, 504],
    retryableErrorTypes: ['timeout', 'network', 'dns']
  },
  timeout: {
    connectTimeout: 8000,
    readTimeout: 15000,
    searchTimeout: 30000,
    chapterTimeout: 20000
  },
  rateLimit: {
    maxConcurrent: 6,
    requestInterval: 300,
    burstAllowance: 3
  },
  degradation: {
    fastFailThreshold: 10000,
    disableAfterConsecutiveFailures: 3,
    recoveryCheckInterval: 300000,
    minHealthyScore: 30
  }
};

/**
 * 激进配置 - 用于快速搜索
 */
export const AGGRESSIVE_NETWORK_CONFIG: NetworkConfig = {
  retry: {
    maxRetries: 1,
    baseDelay: 300,
    maxDelay: 1500,
    retryableStatusCodes: [500, 502, 503],
    retryableErrorTypes: ['timeout']
  },
  timeout: {
    connectTimeout: 5000,
    readTimeout: 10000,
    searchTimeout: 20000,
    chapterTimeout: 15000
  },
  rateLimit: {
    maxConcurrent: 8,
    requestInterval: 200,
    burstAllowance: 5
  },
  degradation: {
    fastFailThreshold: 8000,
    disableAfterConsecutiveFailures: 2,
    recoveryCheckInterval: 600000,
    minHealthyScore: 40
  }
};

/**
 * 保守配置 - 用于高质量书源
 */
export const CONSERVATIVE_NETWORK_CONFIG: NetworkConfig = {
  retry: {
    maxRetries: 3,
    baseDelay: 1000,
    maxDelay: 5000,
    retryableStatusCodes: [408, 429, 500, 502, 503, 504],
    retryableErrorTypes: ['timeout', 'network', 'dns']
  },
  timeout: {
    connectTimeout: 10000,
    readTimeout: 20000,
    searchTimeout: 40000,
    chapterTimeout: 30000
  },
  rateLimit: {
    maxConcurrent: 4,
    requestInterval: 500,
    burstAllowance: 2
  },
  degradation: {
    fastFailThreshold: 15000,
    disableAfterConsecutiveFailures: 5,
    recoveryCheckInterval: 180000,
    minHealthyScore: 20
  }
};

export class NetworkConfigManager {
  private static instance: NetworkConfigManager | null = null;
  private currentConfig: NetworkConfig;

  private constructor() {
    this.currentConfig = DEFAULT_NETWORK_CONFIG;
  }

  static getInstance(): NetworkConfigManager {
    if (!NetworkConfigManager.instance) {
      NetworkConfigManager.instance = new NetworkConfigManager();
    }
    return NetworkConfigManager.instance;
  }

  setConfig(config: NetworkConfig): void {
    this.currentConfig = config;
  }

  getConfig(): NetworkConfig {
    return this.currentConfig;
  }

  getRetryConfig(): RetryConfig {
    return this.currentConfig.retry;
  }

  getTimeoutConfig(): TimeoutConfig {
    return this.currentConfig.timeout;
  }

  getRateLimitConfig(): RateLimitConfig {
    return this.currentConfig.rateLimit;
  }

  getDegradationConfig(): DegradationConfig {
    return this.currentConfig.degradation;
  }

  isRetryableError(errorType: string, statusCode?: number): boolean {
    const retryConfig = this.currentConfig.retry;
    
    if (statusCode && retryConfig.retryableStatusCodes.includes(statusCode)) {
      return true;
    }
    
    return retryConfig.retryableErrorTypes.includes(errorType);
  }
}

export const networkConfigManager = NetworkConfigManager.getInstance();
