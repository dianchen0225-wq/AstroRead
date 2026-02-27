/**
 * SearchFixer - 搜索功能修复工具
 * 集成所有修复方案,一键修复搜索功能
 */

import { Logger } from './performance/Logger';
import { sourceCleaner } from './SourceCleaner';
import { enhancedSourceHealthManager, HealthStatistics } from './EnhancedSourceHealthManager';
import { networkDiagnostics } from './NetworkDiagnostics';
import { BookSourceManager } from './validation/BookSourceManager';
import { BookSource } from '../models/BookSource';

export interface FixReport {
  timestamp: string;
  networkStatus: string;
  failedSourcesCount: number;
  disabledSourcesCount: number;
  recommendations: string[];
}

export class SearchFixer {
  private static instance: SearchFixer | null = null;
  private readonly TAG = 'SearchFixer';

  private constructor() {}

  static getInstance(): SearchFixer {
    if (!SearchFixer.instance) {
      SearchFixer.instance = new SearchFixer();
    }
    return SearchFixer.instance;
  }

  /**
   * 执行完整修复流程
   */
  async performFullFix(): Promise<FixReport> {
    Logger.info(this.TAG, '=== 开始执行搜索功能修复 ===');

    const report: FixReport = {
      timestamp: new Date().toLocaleString(),
      networkStatus: '',
      failedSourcesCount: 0,
      disabledSourcesCount: 0,
      recommendations: []
    };

    try {
      // 步骤1: 检测网络连接
      Logger.info(this.TAG, '步骤1: 检测网络连接...');
      const networkStatus = await networkDiagnostics.checkNetworkConnection();
      report.networkStatus = networkStatus.isConnected 
        ? `已连接 (延迟: ${networkStatus.latency}ms)` 
        : '未连接';

      if (!networkStatus.isConnected) {
        report.recommendations.push('❌ 网络未连接,请检查网络设置');
        Logger.error(this.TAG, '网络未连接,修复终止');
        return report;
      }

      // 步骤2: 同步书源数据到健康度管理器
      Logger.info(this.TAG, '步骤2: 同步书源数据...');
      const bookSourceManager = BookSourceManager.getInstance();
      const allSources = bookSourceManager.getAllSources();
      const enabledSources = bookSourceManager.getEnabledSources();

      Logger.info(this.TAG, `从 BookSourceManager 获取到 ${allSources.length} 个书源, 其中启用 ${enabledSources.length} 个`);

      // 将书源同步到健康度管理器
      for (const source of allSources) {
        enhancedSourceHealthManager.initializeSourceIfNeeded(source.id, source.name, source.url, source.metadata.enabled);
      }

      // 步骤3: 清理失效书源
      Logger.info(this.TAG, '步骤3: 清理失效书源...');
      await sourceCleaner.cleanupFailedSources();
      const failedSources = sourceCleaner.getFailedSourceNames();
      report.failedSourcesCount = failedSources.length;

      if (failedSources.length > 0) {
        report.recommendations.push(`⚠️ 已识别 ${failedSources.length} 个失效书源,建议禁用`);
        for (const sourceName of failedSources) {
          report.recommendations.push(`   - ${sourceName}`);
        }
      }

      // 步骤4: 更新书源健康度
      Logger.info(this.TAG, '步骤4: 更新书源健康度...');
      const healthStats = enhancedSourceHealthManager.getStatistics();
      report.disabledSourcesCount = healthStats.disabled;

      Logger.info(this.TAG, `书源统计: 总数=${healthStats.total}, 启用=${healthStats.enabled}, 禁用=${healthStats.disabled}, 永久禁用=${healthStats.permanentlyDisabled}`);

      // 如果统计为0但实际有书源，使用实际书源数量
      if (healthStats.total === 0 && allSources.length > 0) {
        Logger.warn(this.TAG, `健康度管理器统计为0,但实际有 ${allSources.length} 个书源,使用实际数量`);
        report.recommendations.push(`📊 书源总数: ${allSources.length} 个`);
        report.recommendations.push(`✅ 启用书源: ${enabledSources.length} 个`);
      }

      // 步骤5: 生成健康报告
      Logger.info(this.TAG, '步骤5: 生成健康报告...');
      const healthReport = enhancedSourceHealthManager.generateHealthReport();
      Logger.info(this.TAG, healthReport);

      // 步骤6: 生成建议
      Logger.info(this.TAG, '步骤6: 生成修复建议...');
      // 创建包含实际书源数量的统计
      const actualStats: HealthStatistics = healthStats.total === 0 && allSources.length > 0
        ? { total: allSources.length, enabled: enabledSources.length, disabled: allSources.length - enabledSources.length, permanentlyDisabled: 0, avgScore: 50 }
        : healthStats;
      this.generateRecommendations(report, actualStats);

      Logger.info(this.TAG, '=== 搜索功能修复完成 ===');

    } catch (error) {
      Logger.error(this.TAG, `修复过程出错: ${error}`);
      report.recommendations.push(`❌ 修复过程出错: ${error}`);
    }

    return report;
  }

  /**
   * 生成修复建议
   */
  private generateRecommendations(report: FixReport, healthStats: HealthStatistics): void {
    if (healthStats.enabled === 0) {
      report.recommendations.push('❌ 没有可用的书源,请导入新的书源');
    } else if (healthStats.enabled < 5) {
      report.recommendations.push(`⚠️ 可用书源较少(${healthStats.enabled}个),建议导入更多书源`);
    } else {
      report.recommendations.push(`✓ 有 ${healthStats.enabled} 个可用书源`);
    }

    if (healthStats.permanentlyDisabled > 0) {
      report.recommendations.push(`⚠️ 有 ${healthStats.permanentlyDisabled} 个书源被永久禁用,建议删除这些书源`);
    }

    if (healthStats.avgScore < 30) {
      report.recommendations.push('⚠️ 书源平均健康度较低,建议更新书源');
    } else if (healthStats.avgScore > 70) {
      report.recommendations.push('✓ 书源健康度良好');
    }
  }

  /**
   * 快速诊断
   */
  async quickDiagnosis(): Promise<string> {
    const report: string[] = [];

    report.push('=== 快速诊断 ===');

    // 检测网络
    const isConnected = await networkDiagnostics.quickNetworkCheck();
    report.push(`网络状态: ${isConnected ? '✓ 已连接' : '✗ 未连接'}`);

    // 检查书源 - 从 BookSourceManager 获取实际书源数量
    const bookSourceManager = BookSourceManager.getInstance();
    const allSources = bookSourceManager.getAllSources();
    const enabledSources = bookSourceManager.getEnabledSources();

    // 同步到健康度管理器
    for (const source of allSources) {
      enhancedSourceHealthManager.initializeSourceIfNeeded(source.id, source.name, source.url, source.metadata.enabled);
    }

    const stats = enhancedSourceHealthManager.getStatistics();
    const total = stats.total > 0 ? stats.total : allSources.length;
    const enabled = stats.enabled > 0 ? stats.enabled : enabledSources.length;
    report.push(`书源状态: ${enabled}/${total} 可用`);

    // 检查失效书源
    const failedSources = sourceCleaner.getFailedSourceNames();
    report.push(`失效书源: ${failedSources.length} 个`);

    return report.join('\n');
  }

  /**
   * 生成完整报告
   */
  async generateFullReport(): Promise<string> {
    const report: string[] = [];

    report.push('╔══════════════════════════════════════╗');
    report.push('║     搜索功能诊断与修复报告          ║');
    report.push('╚══════════════════════════════════════╝');
    report.push('');

    // 1. 网络诊断
    report.push('【网络诊断】');
    const networkReport = await networkDiagnostics.generateDiagnosticReport();
    report.push(networkReport);
    report.push('');

    // 2. 书源清理
    report.push('【书源清理】');
    const cleanupReport = sourceCleaner.generateCleanupReport();
    report.push(cleanupReport);
    report.push('');

    // 3. 健康度报告
    report.push('【健康度报告】');
    const healthReport = enhancedSourceHealthManager.generateHealthReport();
    report.push(healthReport);
    report.push('');

    // 4. 修复建议
    report.push('【修复建议】');
    const fixReport = await this.performFullFix();
    for (const recommendation of fixReport.recommendations) {
      report.push(recommendation);
    }
    report.push('');

    report.push(`报告生成时间: ${new Date().toLocaleString()}`);

    return report.join('\n');
  }
}

export const searchFixer = SearchFixer.getInstance();
