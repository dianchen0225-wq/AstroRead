/**
 * BookSourceCompatibilityTester - 书源兼容性测试器
 * 用于测试所有书源的解析成功率，识别失败模式
 */

import { BookSource } from '../../models/BookSource';
import { BookSourceSearchEngine } from '../search/BookSourceSearchEngine';
import { Logger } from '../performance/Logger';
import NetworkAdapter from '../network/NetworkAdapter';
import { SearchResult } from '../../core/interfaces/ISearchEngine';

export interface SourceTestResult {
  sourceId: string;
  sourceName: string;
  success: boolean;
  responseTime: number;
  bookCount: number;
  errorMessage?: string;
  responseLength: number;
  parsedElements: number;
}

export interface CompatibilityReport {
  totalSources: number;
  successCount: number;
  failureCount: number;
  successRate: number;
  results: SourceTestResult[];
  failurePatterns: Map<string, number>;
  timestamp: number;
}

export interface FailurePatternStat {
  pattern: string;
  count: number;
}

export class BookSourceCompatibilityTester {
  private static instance: BookSourceCompatibilityTester | null = null;
  private searchEngine: BookSourceSearchEngine;
  private readonly TAG = 'BookSourceCompatibilityTester';
  private testKeywords: string[] = [
    '诡秘之主',
    '斗破苍穹',
    '全职高手',
    '庆余年',
    '凡人修仙传'
  ];

  private constructor() {
    this.searchEngine = BookSourceSearchEngine.getInstance();
  }

  static getInstance(): BookSourceCompatibilityTester {
    if (!BookSourceCompatibilityTester.instance) {
      BookSourceCompatibilityTester.instance = new BookSourceCompatibilityTester();
    }
    return BookSourceCompatibilityTester.instance;
  }

  /**
   * 设置测试关键词
   */
  setTestKeywords(keywords: string[]): void {
    this.testKeywords = keywords;
  }

  /**
   * 测试单个书源
   */
  async testSingleSource(source: BookSource, keyword?: string): Promise<SourceTestResult> {
    const testKeyword = keyword || this.testKeywords[0];
    const startTime = Date.now();

    try {
      Logger.info(this.TAG, `测试书源: ${source.name}, 关键词: ${testKeyword}`);

      const result: SearchResult = await this.searchEngine.searchSingleSource(source, testKeyword, 1);
      const responseTime = Date.now() - startTime;

      return {
        sourceId: source.id,
        sourceName: source.name,
        success: result.success && result.books.length > 0,
        responseTime,
        bookCount: result.books.length,
        errorMessage: result.error,
        responseLength: 0,
        parsedElements: result.books.length
      };
    } catch (error) {
      const responseTime = Date.now() - startTime;
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(this.TAG, `书源测试失败: ${source.name}, 错误: ${errorMsg}`);

      return {
        sourceId: source.id,
        sourceName: source.name,
        success: false,
        responseTime,
        bookCount: 0,
        errorMessage: errorMsg,
        responseLength: 0,
        parsedElements: 0
      };
    }
  }

  /**
   * 测试多个书源
   */
  async testMultipleSources(
    sources: BookSource[],
    onProgress?: (current: number, total: number, result: SourceTestResult) => void
  ): Promise<CompatibilityReport> {
    const results: SourceTestResult[] = [];
    const failurePatterns = new Map<string, number>();

    for (let i = 0; i < sources.length; i++) {
      const source = sources[i];
      if (!source.metadata.enabled) {
        continue;
      }

      const result = await this.testSingleSource(source);
      results.push(result);

      if (!result.success && result.errorMessage) {
        const pattern = this.identifyFailurePattern(result.errorMessage);
        failurePatterns.set(pattern, (failurePatterns.get(pattern) || 0) + 1);
      }

      if (onProgress) {
        onProgress(i + 1, sources.length, result);
      }

      await new Promise<void>(resolve => setTimeout(resolve, 500));
    }

    const successCount = results.filter(r => r.success).length;
    const totalSources = results.length;

    return {
      totalSources,
      successCount,
      failureCount: totalSources - successCount,
      successRate: totalSources > 0 ? (successCount / totalSources) * 100 : 0,
      results,
      failurePatterns,
      timestamp: Date.now()
    };
  }

  /**
   * 测试所有启用的书源
   */
  async testAllEnabledSources(
    enabledSources: BookSource[],
    onProgress?: (current: number, total: number, result: SourceTestResult) => void
  ): Promise<CompatibilityReport> {
    Logger.info(this.TAG, `开始测试 ${enabledSources.length} 个启用的书源`);
    const report = await this.testMultipleSources(enabledSources, onProgress);

    Logger.info(this.TAG,
      `测试完成: 成功 ${report.successCount}/${report.totalSources} ` +
      `(${report.successRate.toFixed(1)}%)`
    );

    return report;
  }

  /**
   * 识别失败模式
   */
  private identifyFailurePattern(errorMessage: string): string {
    const lowerMsg = errorMessage.toLowerCase();

    if (lowerMsg.includes('timeout') || lowerMsg.includes('超时')) {
      return '网络超时';
    }
    if (lowerMsg.includes('network') || lowerMsg.includes('网络')) {
      return '网络错误';
    }
    if (lowerMsg.includes('403') || lowerMsg.includes('forbidden')) {
      return '访问被拒绝(403)';
    }
    if (lowerMsg.includes('404') || lowerMsg.includes('not found')) {
      return '页面不存在(404)';
    }
    if (lowerMsg.includes('parse') || lowerMsg.includes('解析')) {
      return '解析失败';
    }
    if (lowerMsg.includes('empty') || lowerMsg.includes('空')) {
      return '结果为空';
    }
    if (lowerMsg.includes('captcha') || lowerMsg.includes('验证') || lowerMsg.includes('验证码')) {
      return '需要验证码';
    }

    return '未知错误';
  }

  /**
   * 测试书源网络连接性
   */
  async testSourceConnectivity(source: BookSource): Promise<boolean> {
    try {
      const html = await NetworkAdapter.get(source.url, {});
      return html.length > 0;
    } catch (error) {
      return false;
    }
  }

  /**
   * 获取失败模式统计
   */
  getFailurePatternStats(failurePatterns: Map<string, number>): FailurePatternStat[] {
    const stats: FailurePatternStat[] = [];
    failurePatterns.forEach((count: number, pattern: string) => {
      stats.push({ pattern: pattern, count: count });
    });
    return stats.sort((a: FailurePatternStat, b: FailurePatternStat) => b.count - a.count);
  }

  /**
   * 生成兼容性报告摘要
   */
  generateReportSummary(report: CompatibilityReport): string {
    const patternStats = this.getFailurePatternStats(report.failurePatterns);

    let summary = `=== 书源兼容性测试报告 ===\n`;
    summary += `测试时间: ${new Date(report.timestamp).toLocaleString()}\n`;
    summary += `总书源数: ${report.totalSources}\n`;
    summary += `成功: ${report.successCount}\n`;
    summary += `失败: ${report.failureCount}\n`;
    summary += `成功率: ${report.successRate.toFixed(1)}%\n\n`;

    if (patternStats.length > 0) {
      summary += `失败模式分析:\n`;
      for (const stat of patternStats) {
        summary += `  - ${stat.pattern}: ${stat.count}次\n`;
      }
    }

    return summary;
  }
}

export default BookSourceCompatibilityTester.getInstance();
