/**
 * SourceCleaner - 书源清理工具
 * 用于自动禁用失效的书源
 */

import { Logger } from './Logger';
import { sourceHealthManager } from './SourceHealthManager';

export interface FailedSource {
  name: string;
  errorType: 'dns' | 'ssl' | 'http' | 'timeout' | 'unknown';
  errorMessage: string;
}

export class SourceCleaner {
  private static instance: SourceCleaner | null = null;
  private readonly TAG = 'SourceCleaner';

  // 已知的失效书源列表(根据日志分析)
  private readonly PERMANENTLY_FAILED_SOURCES: FailedSource[] = [
    { name: '黑岩阅读网', errorType: 'dns', errorMessage: '域名解析失败' },
    { name: '入殓师', errorType: 'dns', errorMessage: '域名解析失败' },
    { name: '巅峰小说', errorType: 'ssl', errorMessage: 'SSL内部错误' },
    { name: '笔趣阁⑤', errorType: 'unknown', errorMessage: '数据接收失败' }
  ];

  // 需要优化反爬策略的书源
  private readonly ANTI_SCRAPING_SOURCES: FailedSource[] = [
    { name: '新笔趣塔', errorType: 'http', errorMessage: '访问被拒绝(403)' },
    { name: '红人小说', errorType: 'http', errorMessage: '访问被拒绝(403)' },
    { name: '肉色漫画', errorType: 'http', errorMessage: '访问被拒绝(403)' }
  ];

  // SSL证书问题的书源
  private readonly SSL_PROBLEMATIC_SOURCES: FailedSource[] = [
    { name: '速读谷吧', errorType: 'ssl', errorMessage: 'SSL证书错误' },
    { name: '🎉 天域小说', errorType: 'ssl', errorMessage: 'SSL证书错误' }
  ];

  private constructor() {}

  static getInstance(): SourceCleaner {
    if (!SourceCleaner.instance) {
      SourceCleaner.instance = new SourceCleaner();
    }
    return SourceCleaner.instance;
  }

  /**
   * 获取所有需要禁用的书源名称
   */
  getFailedSourceNames(): string[] {
    const failedSources: string[] = [];
    
    for (const source of this.PERMANENTLY_FAILED_SOURCES) {
      failedSources.push(source.name);
    }
    
    return failedSources;
  }

  /**
   * 获取所有失效书源的详细信息
   */
  getAllFailedSources(): FailedSource[] {
    const allFailed: FailedSource[] = [];
    
    for (const source of this.PERMANENTLY_FAILED_SOURCES) {
      allFailed.push(source);
    }
    
    for (const source of this.SSL_PROBLEMATIC_SOURCES) {
      allFailed.push(source);
    }
    
    return allFailed;
  }

  /**
   * 记录失效书源到健康度管理器
   */
  recordFailedSources(): void {
    const allFailed = this.getAllFailedSources();
    
    for (const failed of allFailed) {
      // 使用书源名称作为临时ID
      const tempId = `failed_${failed.name}`;
      sourceHealthManager.recordFailure(
        tempId,
        failed.name,
        '',
        failed.errorType,
        failed.errorMessage
      );
      
      Logger.info(this.TAG, `已记录失效书源: ${failed.name}, 错误类型: ${failed.errorType}`);
    }
    
    Logger.info(this.TAG, `共记录 ${allFailed.length} 个失效书源`);
  }

  /**
   * 获取需要优化反爬策略的书源
   */
  getAntiScrapingSourceNames(): string[] {
    const sources: string[] = [];
    
    for (const source of this.ANTI_SCRAPING_SOURCES) {
      sources.push(source.name);
    }
    
    return sources;
  }

  /**
   * 生成书源清理报告
   */
  generateCleanupReport(): string {
    const report: string[] = [];
    
    report.push('=== 书源清理报告 ===');
    report.push('');
    report.push(`永久失效书源 (${this.PERMANENTLY_FAILED_SOURCES.length}个):`);
    for (const source of this.PERMANENTLY_FAILED_SOURCES) {
      report.push(`  - ${source.name}: ${source.errorMessage}`);
    }
    
    report.push('');
    report.push(`SSL证书问题书源 (${this.SSL_PROBLEMATIC_SOURCES.length}个):`);
    for (const source of this.SSL_PROBLEMATIC_SOURCES) {
      report.push(`  - ${source.name}: ${source.errorMessage}`);
    }
    
    report.push('');
    report.push(`需要优化反爬策略的书源 (${this.ANTI_SCRAPING_SOURCES.length}个):`);
    for (const source of this.ANTI_SCRAPING_SOURCES) {
      report.push(`  - ${source.name}: ${source.errorMessage}`);
    }
    
    report.push('');
    report.push(`总计: ${this.getAllFailedSources().length} 个书源需要处理`);
    
    return report.join('\n');
  }

  /**
   * 清理所有失效书源
   */
  async cleanupFailedSources(): Promise<void> {
    Logger.info(this.TAG, '开始清理失效书源...');
    
    // 记录失效书源到健康度管理器
    this.recordFailedSources();
    
    // 生成清理报告
    const report = this.generateCleanupReport();
    Logger.info(this.TAG, report);
    
    Logger.info(this.TAG, '失效书源清理完成');
  }
}

export const sourceCleaner = SourceCleaner.getInstance();
