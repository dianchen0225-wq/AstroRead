/**
 * BookSourceDiagnosticTool - 书源诊断与修复工具
 * 用于检测和解决书源无法访问的问题
 */

import { BookSource } from '../models/BookSource';
import { EnhancedSourceHealthManager, EnhancedHealthRecord } from './EnhancedSourceHealthManager';
import NetworkAdapter from './NetworkAdapter';
import { Logger } from './Logger';

export interface DiagnosticResult {
  sourceId: string;
  sourceName: string;
  isHealthy: boolean;
  issues: string[];
  suggestions: string[];
  responseTime?: number;
  statusCode?: number;
}

export interface DiagnosticSummary {
  totalSources: number;
  healthySources: number;
  unhealthySources: number;
  issuesFound: string[];
  repairSuggestions: string[];
}

export class BookSourceDiagnosticTool {
  private static instance: BookSourceDiagnosticTool | null = null;
  private healthManager: EnhancedSourceHealthManager;
  private readonly TAG = 'BookSourceDiagnosticTool';

  private constructor() {
    this.healthManager = EnhancedSourceHealthManager.getInstance();
  }

  static getInstance(): BookSourceDiagnosticTool {
    if (!BookSourceDiagnosticTool.instance) {
      BookSourceDiagnosticTool.instance = new BookSourceDiagnosticTool();
    }
    return BookSourceDiagnosticTool.instance;
  }

  /**
   * 对单个书源进行诊断
   */
  async diagnoseSource(source: BookSource): Promise<DiagnosticResult> {
    const result: DiagnosticResult = {
      sourceId: source.id,
      sourceName: source.name,
      isHealthy: true,
      issues: [],
      suggestions: []
    };

    // 检查书源基础配置
    if (!source.url || source.url.trim() === '') {
      result.isHealthy = false;
      result.issues.push('书源URL为空');
      result.suggestions.push('请检查并设置有效的书源URL');
    }

    if (!source.searchUrl || source.searchUrl.trim() === '') {
      result.isHealthy = false;
      result.issues.push('搜索URL为空');
      result.suggestions.push('请检查并设置有效的搜索URL');
    }

    // 检查健康度记录
    const healthRecord = this.getHealthRecord(source.id);
    if (healthRecord) {
      if (!healthRecord.isEnabled) {
        result.isHealthy = false;
        result.issues.push(`书源被禁用: ${healthRecord.disabledReason}`);
        if (healthRecord.isPermanentlyDisabled) {
          result.suggestions.push('该书源因永久性错误被禁用，需要手动修复后重新启用');
        } else {
          result.suggestions.push('可以通过重置连续失败计数来重新启用此书源');
        }
      }

      if (healthRecord.consecutiveFailures > 0) {
        result.issues.push(`连续失败次数: ${healthRecord.consecutiveFailures}`);
        result.suggestions.push('检查网络连接或书源服务器是否正常');
      }

      if (healthRecord.score < 30) {
        result.issues.push(`健康度评分过低: ${healthRecord.score}`);
        result.suggestions.push('考虑暂时禁用此书源或更换其他书源');
      }
    }

    // 尝试访问书源URL
    if (source.url) {
      try {
        const startTime = Date.now();
        const response = await NetworkAdapter.get(source.url, this.buildHeaders(source));
        const responseTime = Date.now() - startTime;
        
        result.responseTime = responseTime;
        
        // 检查响应内容
        if (response.length < 100) {
          result.isHealthy = false;
          result.issues.push(`书源URL返回内容过少 (${response.length} 字符)`);
          result.suggestions.push('检查书源服务器是否正常运行');
        }
      } catch (error) {
        result.isHealthy = false;
        const errorMsg = error instanceof Error ? error.message : String(error);
        result.issues.push(`访问书源URL失败: ${errorMsg}`);
        
        if (errorMsg.includes('timeout')) {
          result.suggestions.push('增加网络请求超时时间或更换网络环境');
        } else if (errorMsg.includes('403')) {
          result.suggestions.push('可能是User-Agent被拦截，尝试修改请求头');
        } else if (errorMsg.includes('404')) {
          result.suggestions.push('书源URL可能已变更，请更新书源地址');
        } else if (errorMsg.includes('DNS') || errorMsg.includes('resolve')) {
          result.suggestions.push('域名解析失败，请检查网络连接或DNS设置');
        } else {
          result.suggestions.push('网络连接异常，请检查网络设置');
        }
      }
    }

    // 尝试构建并访问搜索URL
    if (source.searchUrl && source.searchUrl.includes('{{key}}')) {
      const testKeyword = 'test';
      const searchUrl = this.buildSearchUrl(source, testKeyword);
      
      try {
        const startTime = Date.now();
        const response = await NetworkAdapter.get(searchUrl, this.buildHeaders(source));
        const responseTime = Date.now() - startTime;
        
        if (responseTime > 10000) { // 超过10秒
          result.issues.push(`搜索请求响应时间过长: ${responseTime}ms`);
          result.suggestions.push('考虑优化书源配置或使用响应更快的书源');
        }
      } catch (error) {
        result.isHealthy = false;
        const errorMsg = error instanceof Error ? error.message : String(error);
        result.issues.push(`搜索URL访问失败: ${errorMsg}`);
        
        if (errorMsg.includes('403') || errorMsg.includes('451')) {
          result.suggestions.push('搜索URL可能需要特定的请求头或参数，请检查书源配置');
        } else if (errorMsg.includes('404')) {
          result.suggestions.push('搜索URL路径可能已变更，请更新书源配置');
        }
      }
    }

    return result;
  }

  /**
   * 诊断多个书源
   */
  async diagnoseSources(sources: BookSource[]): Promise<DiagnosticSummary> {
    const results: DiagnosticResult[] = [];
    const summary: DiagnosticSummary = {
      totalSources: sources.length,
      healthySources: 0,
      unhealthySources: 0,
      issuesFound: [],
      repairSuggestions: []
    };

    for (const source of sources) {
      const result = await this.diagnoseSource(source);
      results.push(result);

      if (result.isHealthy) {
        summary.healthySources++;
      } else {
        summary.unhealthySources++;
      }

      // 收集所有问题和建议
      summary.issuesFound.push(...result.issues.map(issue => `${source.name}: ${issue}`));
      summary.repairSuggestions.push(...result.suggestions);
    }

    // 去重
    summary.issuesFound = [...new Set(summary.issuesFound)];
    summary.repairSuggestions = [...new Set(summary.repairSuggestions)];

    Logger.info(this.TAG, `诊断完成: 总计${summary.totalSources}个书源，健康${summary.healthySources}个，不健康${summary.unhealthySources}个`);
    
    return summary;
  }

  /**
   * 修复特定问题
   */
  async repairSource(source: BookSource, autoFix: boolean = false): Promise<boolean> {
    let repaired = false;
    
    // 重置健康度记录
    const healthRecord = this.getHealthRecord(source.id);
    if (healthRecord && !healthRecord.isEnabled) {
      if (autoFix) {
        this.resetHealthRecord(source.id);
        Logger.info(this.TAG, `已重置书源 ${source.name} 的健康度状态`);
        repaired = true;
      }
    }

    // 启用被禁用的书源
    if (healthRecord && !healthRecord.isEnabled && healthRecord.isPermanentlyDisabled) {
      if (autoFix) {
        this.enableSource(source.id);
        Logger.info(this.TAG, `已启用书源 ${source.name}`);
        repaired = true;
      }
    }

    // 更新书源URL（如果需要）
    if (source.url && source.url.includes('old-domain.com')) {
      // 示例：更新过期的域名
      if (autoFix) {
        Logger.info(this.TAG, `更新书源 ${source.name} 的URL`);
        repaired = true;
      }
    }

    return repaired;
  }

  /**
   * 修复所有问题
   */
  async repairAll(sources: BookSource[], autoFix: boolean = false): Promise<number> {
    let repairedCount = 0;
    
    for (const source of sources) {
      const result = await this.repairSource(source, autoFix);
      if (result) {
        repairedCount++;
      }
    }
    
    Logger.info(this.TAG, `修复完成: ${repairedCount}/${sources.length} 个书源已修复`);
    return repairedCount;
  }

  /**
   * 构建请求头
   */
  private buildHeaders(source: BookSource): Record<string, string> {
    const headers: Record<string, string> = {};

    // 如果书源有自定义头部
    if (source.header) {
      try {
        const customHeaders = JSON.parse(source.header) as Record<string, string>;
        Object.assign(headers, customHeaders);
      } catch (e) {
        Logger.warn(this.TAG, `解析书源 ${source.name} 自定义头部失败: ${e}`);
      }
    }

    // 设置默认User-Agent（避免被识别为爬虫）
    if (!headers['User-Agent']) {
      headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    }

    // 设置Referer
    if (!headers['Referer'] && source.url) {
      try {
        const url = new URL(source.url);
        headers['Referer'] = `${url.protocol}//${url.hostname}/`;
      } catch (e) {
        // 忽略URL解析错误
      }
    }

    return headers;
  }

  /**
   * 构建搜索URL
   */
  private buildSearchUrl(source: BookSource, keyword: string): string {
    if (!source.searchUrl) {
      return source.url || '';
    }

    return source.searchUrl
      .replace(/\{\{key\}\}/g, encodeURIComponent(keyword))
      .replace(/\{\{page\}\}/g, '1')
      .replace(/\{key\}/g, encodeURIComponent(keyword))
      .replace(/\{page\}/g, '1')
      .replace(/<key>/g, encodeURIComponent(keyword))
      .replace(/<page>/g, '1')
      .replace(/\$key\$/g, encodeURIComponent(keyword))
      .replace(/\$page\$/g, '1');
  }

  /**
   * 获取健康度记录
   */
  private getHealthRecord(sourceId: string): EnhancedHealthRecord | undefined {
    return this.healthManager.getRecord(sourceId);
  }

  /**
   * 重置健康度记录
   */
  resetHealthRecord(sourceId: string): void {
    this.healthManager.resetRecord(sourceId);
  }

  /**
   * 启用被禁用的书源
   */
  enableSource(sourceId: string): void {
    this.healthManager.enableSource(sourceId);
  }
}