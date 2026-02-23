/**
 * BookSourceTestRunner - 书源测试运行器
 * 提供统一的接口来测试所有书源的兼容性
 */

import { BookSource } from '../../models/BookSource';
import { BookSourceCompatibilityTester, CompatibilityReport, FailurePatternStat } from './BookSourceCompatibilityTester';
import { BookSourceRepository } from '../database/BookSourceRepository';
import { Logger } from '../performance/Logger';

export interface TestProgress {
  current: number;
  total: number;
  sourceName: string;
  success: boolean;
  bookCount: number;
}

export interface TestOptions {
  // 测试关键词
  keywords?: string[];
  // 是否只测试启用的书源
  onlyEnabled?: boolean;
  // 测试超时时间（毫秒）
  timeout?: number;
  // 并发数
  concurrent?: number;
}

export interface TestRunnerOptions {
  keywords: string[];
  onlyEnabled: boolean;
  timeout: number;
  concurrent: number;
}

export interface SingleSourceTestResult {
  success: boolean;
  bookCount: number;
  error?: string;
  responseTime: number;
}

export interface FailureAnalysisResult {
  pattern: string;
  count: number;
  percentage: string;
}

export class BookSourceTestRunner {
  private static instance: BookSourceTestRunner | null = null;
  private tester: BookSourceCompatibilityTester;
  private repository: BookSourceRepository | null = null;
  private readonly TAG = 'BookSourceTestRunner';

  private constructor() {
    this.tester = BookSourceCompatibilityTester.getInstance();
  }

  static getInstance(): BookSourceTestRunner {
    if (!BookSourceTestRunner.instance) {
      BookSourceTestRunner.instance = new BookSourceTestRunner();
    }
    return BookSourceTestRunner.instance;
  }

  /**
   * 设置书源仓库
   */
  setRepository(repository: BookSourceRepository): void {
    this.repository = repository;
  }

  /**
   * 运行完整测试
   */
  async runFullTest(
    onProgress?: (progress: TestProgress) => void,
    options: TestOptions = {}
  ): Promise<CompatibilityReport> {
    const opts: TestRunnerOptions = {
      keywords: options.keywords !== undefined ? options.keywords : ['诡秘之主', '斗破苍穹', '全职高手'],
      onlyEnabled: options.onlyEnabled !== undefined ? options.onlyEnabled : true,
      timeout: options.timeout !== undefined ? options.timeout : 30000,
      concurrent: options.concurrent !== undefined ? options.concurrent : 3
    };

    if (opts.keywords && opts.keywords.length > 0) {
      this.tester.setTestKeywords(opts.keywords);
    }

    // 获取书源列表
    let sources: BookSource[] = [];
    if (this.repository) {
      if (opts.onlyEnabled) {
        sources = await this.repository.getAllEnabledBookSources();
      } else {
        sources = await this.repository.getAllBookSources();
      }
    } else {
      Logger.error(this.TAG, '书源仓库未设置，无法获取书源列表');
      return this.createEmptyReport();
    }

    Logger.info(this.TAG, `开始测试 ${sources.length} 个书源`);

    // 运行测试
    const report = await this.tester.testAllEnabledSources(
      sources,
      (current, total, result) => {
        if (onProgress) {
          onProgress({
            current,
            total,
            sourceName: result.sourceName,
            success: result.success,
            bookCount: result.bookCount
          });
        }
      }
    );

    // 输出报告摘要
    const summary = this.tester.generateReportSummary(report);
    Logger.info(this.TAG, summary);

    return report;
  }

  /**
   * 测试单个书源
   */
  async testSingleSource(
    source: BookSource,
    keyword?: string
  ): Promise<SingleSourceTestResult> {
    const result = await this.tester.testSingleSource(source, keyword);
    return {
      success: result.success,
      bookCount: result.bookCount,
      error: result.errorMessage,
      responseTime: result.responseTime
    };
  }

  /**
   * 获取失败模式分析
   */
  analyzeFailures(report: CompatibilityReport): FailureAnalysisResult[] {
    const stats = this.tester.getFailurePatternStats(report.failurePatterns);
    const totalFailures = report.failureCount;

    const results: FailureAnalysisResult[] = [];
    for (const stat of stats) {
      const item: FailureAnalysisResult = {
        pattern: stat.pattern,
        count: stat.count,
        percentage: totalFailures > 0 ? ((stat.count / totalFailures) * 100).toFixed(1) + '%' : '0%'
      };
      results.push(item);
    }
    return results;
  }

  /**
   * 获取推荐修复方案
   */
  getRecommendations(report: CompatibilityReport): string[] {
    const recommendations: string[] = [];
    const failureStats = this.analyzeFailures(report);

    for (const stat of failureStats) {
      switch (stat.pattern) {
        case '网络超时':
          recommendations.push('建议增加请求超时时间或优化网络连接');
          break;
        case '访问被拒绝(403)':
          recommendations.push('部分书源可能需要设置User-Agent或其他请求头');
          break;
        case '解析失败':
          recommendations.push('书源规则可能需要更新，建议检查网站结构变化');
          break;
        case '结果为空':
          recommendations.push('搜索关键词可能不匹配，尝试更换测试关键词');
          break;
        case '需要验证码':
          recommendations.push('书源启用了反爬机制，可能需要降低请求频率');
          break;
      }
    }

    if (report.successRate < 50) {
      recommendations.push('整体成功率较低，建议检查网络连接或更新书源配置');
    }

    if (recommendations.length === 0 && report.successRate === 100) {
      recommendations.push('所有书源测试通过，系统运行正常！');
    }

    return recommendations;
  }

  /**
   * 生成详细报告
   */
  generateDetailedReport(report: CompatibilityReport): string {
    let detailed = this.tester.generateReportSummary(report);

    detailed += '\n=== 失败模式分析 ===\n';
    const failureAnalysis = this.analyzeFailures(report);
    for (const analysis of failureAnalysis) {
      detailed += `${analysis.pattern}: ${analysis.count}次 (${analysis.percentage})\n`;
    }

    detailed += '\n=== 修复建议 ===\n';
    const recommendations = this.getRecommendations(report);
    for (let i = 0; i < recommendations.length; i++) {
      detailed += `${i + 1}. ${recommendations[i]}\n`;
    }

    detailed += '\n=== 详细结果 ===\n';
    for (const result of report.results) {
      const status = result.success ? '✓' : '✗';
      detailed += `${status} ${result.sourceName}: ${result.bookCount}本书`;
      if (!result.success && result.errorMessage) {
        detailed += ` - ${result.errorMessage}`;
      }
      detailed += ` (${result.responseTime}ms)\n`;
    }

    return detailed;
  }

  /**
   * 创建空报告
   */
  private createEmptyReport(): CompatibilityReport {
    return {
      totalSources: 0,
      successCount: 0,
      failureCount: 0,
      successRate: 0,
      results: [],
      failurePatterns: new Map(),
      timestamp: Date.now()
    };
  }
}

export default BookSourceTestRunner.getInstance();
