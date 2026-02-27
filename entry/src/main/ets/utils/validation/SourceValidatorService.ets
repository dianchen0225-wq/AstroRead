import { Book, SourceStatus, SourceValidationResult } from '../../models/Book';
import { BookSource } from '../../models/BookSource';
import { Logger } from '../performance/Logger';
import { enhancedSourceHealthManager } from '../EnhancedSourceHealthManager';
import { viewModelManager } from '../../viewmodel/ViewModelManager';
import { NetworkManager } from '../network/NetworkManager';
import { smartSourceSelector } from '../search/SmartSourceSelector';
import { errorHandlingService, ErrorType, ErrorContext } from '../error/ErrorHandlingService';

export interface BatchValidationProgress {
  total: number;
  completed: number;
  currentBook: string;
  validCount: number;
  invalidCount: number;
  checkingCount: number;
  errorCount: number;
}

export interface SourceValidationConfig {
  enableNetworkCheck: boolean;
  enableHealthCheck: boolean;
  enableContentCheck: boolean;
  timeout: number;
  maxConcurrent: number;
  retryCount: number;
}

export interface BooksGroupedByStatus {
  valid: Book[];
  invalid: Book[];
  unknown: Book[];
}

export interface ValidationStats {
  totalSources: number;
  validSources: number;
  invalidSources: number;
  unknownSources: number;
}

export type ValidationProgressCallback = (progress: BatchValidationProgress) => void;
export type BookStatusUpdateCallback = (bookId: string, status: SourceStatus) => void;

export class SourceValidatorService {
  private static instance: SourceValidatorService | null = null;
  private readonly TAG = 'SourceValidatorService';
  private sourceCache: Map<string, BookSource> = new Map();
  private validationCache: Map<string, SourceStatus> = new Map();
  private isValidationRunning: boolean = false;
  private validationConfig: SourceValidationConfig = {
    enableNetworkCheck: true,
    enableHealthCheck: true,
    enableContentCheck: false,
    timeout: 10000,
    maxConcurrent: 3,
    retryCount: 2
  };

  private constructor() {}

  static getInstance(): SourceValidatorService {
    if (!SourceValidatorService.instance) {
      SourceValidatorService.instance = new SourceValidatorService();
    }
    return SourceValidatorService.instance;
  }

  /**
   * 更新验证配置
   */
  updateConfig(config: Partial<SourceValidationConfig>): void {
    this.validationConfig = this.mergeValidationConfig(this.validationConfig, config);
    Logger.info(this.TAG, '验证配置已更新');
  }

  private mergeValidationConfig(base: SourceValidationConfig, update: Partial<SourceValidationConfig>): SourceValidationConfig {
    return {
      enableNetworkCheck: update.enableNetworkCheck !== undefined ? update.enableNetworkCheck : base.enableNetworkCheck,
      enableHealthCheck: update.enableHealthCheck !== undefined ? update.enableHealthCheck : base.enableHealthCheck,
      enableContentCheck: update.enableContentCheck !== undefined ? update.enableContentCheck : base.enableContentCheck,
      timeout: update.timeout !== undefined ? update.timeout : base.timeout,
      maxConcurrent: update.maxConcurrent !== undefined ? update.maxConcurrent : base.maxConcurrent,
      retryCount: update.retryCount !== undefined ? update.retryCount : base.retryCount
    };
  }

  private cloneProgress(progress: BatchValidationProgress): BatchValidationProgress {
    return {
      total: progress.total,
      completed: progress.completed,
      currentBook: progress.currentBook,
      validCount: progress.validCount,
      invalidCount: progress.invalidCount,
      checkingCount: progress.checkingCount,
      errorCount: progress.errorCount
    };
  }

  /**
   * 加载书源缓存
   */
  async loadSourceCache(): Promise<void> {
    try {
      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      const sources = await bookSourceViewModel.loadAllBookSources();

      this.sourceCache.clear();
      for (const source of sources) {
        this.sourceCache.set(source.id, source);
      }

      // 初始化智能书源选择器
      smartSourceSelector.initializeSources(sources);

      Logger.info(this.TAG, `已加载 ${this.sourceCache.size} 个书源到缓存`);
    } catch (error) {
      Logger.error(this.TAG, `加载书源缓存失败: ${error}`);
    }
  }

  getSourceById(sourceId: string): BookSource | undefined {
    return this.sourceCache.get(sourceId);
  }

  isSourceExists(sourceId: string): boolean {
    return this.sourceCache.has(sourceId);
  }

  getCachedStatus(sourceId: string): SourceStatus | undefined {
    return this.validationCache.get(sourceId);
  }

  /**
   * 验证单个书籍
   */
  async validateSingleBook(book: Book): Promise<SourceValidationResult> {
    const result: SourceValidationResult = {
      bookId: book.id,
      bookSourceId: book.bookSourceId,
      bookSourceName: book.bookSourceName,
      status: SourceStatus.UNKNOWN
    };

    if (!book.bookSourceId) {
      result.status = SourceStatus.INVALID;
      result.errorMessage = '书籍缺少书源ID';
      return result;
    }

    const source = this.sourceCache.get(book.bookSourceId);
    if (!source) {
      result.status = SourceStatus.INVALID;
      result.errorMessage = '书源不存在或已删除';
      return result;
    }

    if (!source.metadata.enabled) {
      result.status = SourceStatus.INVALID;
      result.errorMessage = '书源已禁用';
      return result;
    }

    // 健康度检查
    if (this.validationConfig.enableHealthCheck) {
      const healthScore = enhancedSourceHealthManager.getSourceScore(book.bookSourceId);
      if (healthScore < 10) {
        result.status = SourceStatus.INVALID;
        result.errorMessage = '书源健康度过低';
        return result;
      }
    }

    // 智能书源选择器检查
    const metrics = smartSourceSelector.getMetrics(book.bookSourceId);
    if (metrics && metrics.isBlacklisted) {
      result.status = SourceStatus.INVALID;
      result.errorMessage = '书源已被列入黑名单';
      return result;
    }

    // 网络可达性检查
    if (this.validationConfig.enableNetworkCheck) {
      const networkValid = await this.checkSourceNetwork(source);
      if (!networkValid) {
        result.status = SourceStatus.INVALID;
        result.errorMessage = '书源网络不可达';
        return result;
      }
    }

    result.status = SourceStatus.VALID;
    this.validationCache.set(book.bookSourceId, SourceStatus.VALID);

    return result;
  }

  /**
   * 检查书源网络可达性
   */
  private async checkSourceNetwork(source: BookSource): Promise<boolean> {
    try {
      const startTime = Date.now();
      const response = await NetworkManager.getInstance().get(source.url, undefined, 1024);
      const responseTime = Date.now() - startTime;

      // 记录成功
      smartSourceSelector.recordSuccess(source.id, responseTime);

      return true;
    } catch (error) {
      // 记录失败
      smartSourceSelector.recordFailure(source.id, error instanceof Error ? error.message : String(error));

      // 错误处理
      const errorContext: ErrorContext = {
        sourceId: source.id,
        sourceName: source.name,
        operation: 'network_check',
        retryCount: 0,
        maxRetries: this.validationConfig.retryCount
      };

      await errorHandlingService.handleError(
        error instanceof Error ? error : new Error(String(error)),
        errorContext
      );

      return false;
    }
  }

  /**
   * 批量验证书籍
   */
  async validateBooksBatch(
    books: Book[],
    progressCallback?: ValidationProgressCallback,
    statusUpdateCallback?: BookStatusUpdateCallback
  ): Promise<SourceValidationResult[]> {
    if (this.isValidationRunning) {
      Logger.warn(this.TAG, '验证任务正在进行中');
      return [];
    }

    this.isValidationRunning = true;
    const results: SourceValidationResult[] = [];

    const progress: BatchValidationProgress = {
      total: books.length,
      completed: 0,
      currentBook: '',
      validCount: 0,
      invalidCount: 0,
      checkingCount: 0,
      errorCount: 0
    };

    try {
      if (this.sourceCache.size === 0) {
        await this.loadSourceCache();
      }

      const uniqueSourceIds = new Set(books.map(b => b.bookSourceId));
      Logger.info(this.TAG, `开始验证 ${books.length} 本书, 涉及 ${uniqueSourceIds.size} 个书源`);

      // 并发验证
      const batchSize = this.validationConfig.maxConcurrent;
      for (let i = 0; i < books.length; i += batchSize) {
        const batch = books.slice(i, i + batchSize);

        const batchPromises = batch.map(async (book) => {
          progress.currentBook = book.name;
          progress.checkingCount++;

          if (statusUpdateCallback) {
            statusUpdateCallback(book.id, SourceStatus.CHECKING);
          }

          try {
            const result = await this.validateSingleBook(book);

            if (result.status === SourceStatus.VALID) {
              progress.validCount++;
            } else if (result.status === SourceStatus.INVALID) {
              progress.invalidCount++;
            }

            if (statusUpdateCallback) {
              statusUpdateCallback(book.id, result.status);
            }

            return result;
          } catch (error) {
            progress.errorCount++;

            const errorResult: SourceValidationResult = {
              bookId: book.id,
              bookSourceId: book.bookSourceId,
              bookSourceName: book.bookSourceName,
              status: SourceStatus.UNKNOWN,
              errorMessage: error instanceof Error ? error.message : String(error)
            };

            if (statusUpdateCallback) {
              statusUpdateCallback(book.id, SourceStatus.UNKNOWN);
            }

            return errorResult;
          } finally {
            progress.checkingCount--;
            progress.completed++;
          }
        });

        const batchResults = await Promise.all(batchPromises);
        results.push(...batchResults);

        if (progressCallback) {
          progressCallback(this.cloneProgress(progress));
        }
      }

      Logger.info(this.TAG,
        `验证完成: ${progress.validCount} 个有效, ${progress.invalidCount} 个无效, ${progress.errorCount} 个错误`
      );

    } finally {
      this.isValidationRunning = false;
    }

    return results;
  }

  /**
   * 验证书源本身
   */
  async validateSource(source: BookSource): Promise<SourceValidationResult> {
    const result: SourceValidationResult = {
      bookId: '',
      bookSourceId: source.id,
      bookSourceName: source.name,
      status: SourceStatus.UNKNOWN
    };

    if (!source.metadata.enabled) {
      result.status = SourceStatus.INVALID;
      result.errorMessage = '书源已禁用';
      return result;
    }

    if (this.validationConfig.enableNetworkCheck) {
      const networkValid = await this.checkSourceNetwork(source);
      if (!networkValid) {
        result.status = SourceStatus.INVALID;
        result.errorMessage = '书源网络不可达';
        return result;
      }
    }

    result.status = SourceStatus.VALID;
    this.validationCache.set(source.id, SourceStatus.VALID);

    return result;
  }

  /**
   * 批量验证书源
   */
  async validateSourcesBatch(
    sources: BookSource[],
    progressCallback?: (current: number, total: number) => void
  ): Promise<Map<string, SourceValidationResult>> {
    const results = new Map<string, SourceValidationResult>();

    for (let i = 0; i < sources.length; i++) {
      const source = sources[i];
      const result = await this.validateSource(source);
      results.set(source.id, result);

      if (progressCallback) {
        progressCallback(i + 1, sources.length);
      }
    }

    return results;
  }

  /**
   * 根据状态过滤书籍
   */
  filterBooksByStatus(books: Book[], showInvalid: boolean = true): Book[] {
    return books.filter(book => {
      if (!book.sourceStatus) {
        return true;
      }
      return showInvalid || book.sourceStatus !== SourceStatus.INVALID;
    });
  }

  /**
   * 按状态分组书籍
   */
  getBooksGroupedByStatus(books: Book[]): BooksGroupedByStatus {
    const valid: Book[] = [];
    const invalid: Book[] = [];
    const unknown: Book[] = [];

    for (const book of books) {
      switch (book.sourceStatus) {
        case SourceStatus.VALID:
          valid.push(book);
          break;
        case SourceStatus.INVALID:
          invalid.push(book);
          break;
        default:
          unknown.push(book);
      }
    }

    const result: BooksGroupedByStatus = {
      valid: valid,
      invalid: invalid,
      unknown: unknown
    };
    return result;
  }

  /**
   * 获取验证统计
   */
  getValidationStats(): ValidationStats {
    let validSources = 0;
    let invalidSources = 0;
    let unknownSources = 0;

    this.validationCache.forEach(status => {
      switch (status) {
        case SourceStatus.VALID:
          validSources++;
          break;
        case SourceStatus.INVALID:
          invalidSources++;
          break;
        default:
          unknownSources++;
      }
    });

    const stats: ValidationStats = {
      totalSources: this.sourceCache.size,
      validSources: validSources,
      invalidSources: invalidSources,
      unknownSources: unknownSources
    };
    return stats;
  }

  /**
   * 生成验证报告
   */
  generateReport(): string {
    const stats = this.getValidationStats();
    const smartStats = smartSourceSelector.getAllMetrics();

    let report = '=== 书源验证报告 ===\n\n';

    report += '【验证统计】\n';
    report += `总书源数: ${stats.totalSources}\n`;
    report += `有效书源: ${stats.validSources}\n`;
    report += `无效书源: ${stats.invalidSources}\n`;
    report += `未知状态: ${stats.unknownSources}\n\n`;

    report += '【智能选择器统计】\n';
    report += `健康书源: ${smartSourceSelector.getHealthySourceCount()}\n`;
    report += `黑名单书源: ${smartStats.filter(m => m.isBlacklisted).length}\n\n`;

    if (smartStats.length > 0) {
      report += '【书源性能排名】\n';
      const sorted = smartStats.sort((a, b) => b.score - a.score);
      sorted.slice(0, 10).forEach((m, index) => {
        report += `${index + 1}. ${m.sourceName}\n`;
        report += `   成功率: ${(m.successRate * 100).toFixed(1)}%\n`;
        report += `   平均响应: ${m.avgResponseTime.toFixed(0)}ms\n`;
        report += `   评分: ${m.score.toFixed(1)}\n`;
      });
    }

    return report;
  }

  /**
   * 清除缓存
   */
  clearCache(): void {
    this.sourceCache.clear();
    this.validationCache.clear();
    Logger.info(this.TAG, '已清空书源缓存');
  }

  /**
   * 是否正在验证
   */
  isValidating(): boolean {
    return this.isValidationRunning;
  }
}

export const sourceValidatorService = SourceValidatorService.getInstance();
