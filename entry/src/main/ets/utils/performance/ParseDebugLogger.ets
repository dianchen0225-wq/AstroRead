/**
 * ParseDebugLogger - 解析调试日志器
 * 用于记录字段提取的详细过程，便于调试书源解析问题
 */

import { Logger } from "./Logger";

export interface FieldExtractionLog {
  timestamp: number;
  sourceName: string;
  sourceId: string;
  fieldName: string;
  rule: string;
  ruleType: 'css' | 'xpath' | 'jsonpath' | 'regex' | 'js';
  inputHtml: string;
  inputHtmlLength: number;
  extractedValue: string;
  extractionStatus: 'success' | 'failed' | 'empty' | 'error';
  processingTime: number;
  errorMessage?: string;
  matchedElements?: number;
  suggestions?: string[];
}

export interface BookListExtractionLog {
  timestamp: number;
  sourceName: string;
  sourceId: string;
  listRule: string;
  inputHtmlLength: number;
  matchedCount: number;
  extractionStatus: 'success' | 'failed' | 'empty';
  htmlPreview: string;
  errorMessage?: string;
  suggestions?: string[];
}

export interface ParseResultInfo {
  bookListFound: boolean;
  bookCount: number;
  successfulBooks: number;
  failedBooks: number;
}

export interface SearchDebugLog {
  timestamp: number;
  sourceName: string;
  sourceId: string;
  searchUrl: string;
  keyword: string;
  responseStatus: number;
  responseTime: number;
  responseLength: number;
  responsePreview: string;
  parseResult: ParseResultInfo;
  errors: ParseErrorInfo[];
  warnings: string[];
}

export interface ParseErrorInfo {
  type: ParseErrorType;
  fieldName: string;
  rule: string;
  message: string;
  htmlContext: string;
  lineNumber?: number;
  suggestions: string[];
}

export type ParseErrorType = 
  | 'rule_not_matched'
  | 'empty_result'
  | 'invalid_rule_syntax'
  | 'js_execution_error'
  | 'attribute_not_found'
  | 'text_extraction_failed'
  | 'url_resolution_failed'
  | 'encoding_error'
  | 'timeout_error'
  | 'network_error'
  | 'anti_crawler_detected'
  | 'dynamic_content';

export interface DebugLogConfig {
  enabled: boolean;
  maxLogsPerSession: number;
  maxHtmlPreviewLength: number;
  includeStackTrace: boolean;
  autoCleanup: boolean;
}

export interface FieldExtractionParams {
  sourceName: string;
  sourceId: string;
  fieldName: string;
  rule: string;
  ruleType: 'css' | 'xpath' | 'jsonpath' | 'regex' | 'js';
  inputHtml: string;
  inputHtmlLength: number;
  extractedValue: string;
  extractionStatus: 'success' | 'failed' | 'empty' | 'error';
  processingTime: number;
  errorMessage?: string;
  matchedElements?: number;
  suggestions?: string[];
}

export interface BookListExtractionParams {
  sourceName: string;
  sourceId: string;
  listRule: string;
  inputHtmlLength: number;
  matchedCount: number;
  extractionStatus: 'success' | 'failed' | 'empty';
  htmlPreview: string;
  errorMessage?: string;
  suggestions?: string[];
}

export interface SearchDebugParams {
  sourceName: string;
  sourceId: string;
  searchUrl: string;
  keyword: string;
  responseStatus: number;
  responseTime: number;
  responseLength: number;
  responsePreview: string;
  parseResult: ParseResultInfo;
  errors: ParseErrorInfo[];
  warnings: string[];
}

class ParseDebugLogger {
  private static instance: ParseDebugLogger | null = null;
  private readonly TAG = 'ParseDebugLogger';
  
  private config: DebugLogConfig = {
    enabled: true,
    maxLogsPerSession: 500,
    maxHtmlPreviewLength: 500,
    includeStackTrace: false,
    autoCleanup: true
  };
  private fieldLogs: FieldExtractionLog[] = [];
  private bookListLogs: BookListExtractionLog[] = [];
  private searchLogs: SearchDebugLog[] = [];
  private currentSessionId: string = '';
  private sessionStartTime: number = 0;

  private constructor() {}

  static getInstance(): ParseDebugLogger {
    if (!ParseDebugLogger.instance) {
      ParseDebugLogger.instance = new ParseDebugLogger();
    }
    return ParseDebugLogger.instance;
  }

  setConfig(config: Partial<DebugLogConfig>): void {
    if (config.enabled !== undefined) this.config.enabled = config.enabled;
    if (config.maxLogsPerSession !== undefined) this.config.maxLogsPerSession = config.maxLogsPerSession;
    if (config.maxHtmlPreviewLength !== undefined) this.config.maxHtmlPreviewLength = config.maxHtmlPreviewLength;
    if (config.includeStackTrace !== undefined) this.config.includeStackTrace = config.includeStackTrace;
    if (config.autoCleanup !== undefined) this.config.autoCleanup = config.autoCleanup;
  }

  startSession(sessionId: string): void {
    this.currentSessionId = sessionId;
    this.sessionStartTime = Date.now();
    Logger.info(this.TAG, `开始调试会话: ${sessionId}`);
  }

  endSession(): void {
    const duration = Date.now() - this.sessionStartTime;
    Logger.info(this.TAG, `调试会话结束: ${this.currentSessionId}, 耗时: ${duration}ms`);
    
    if (this.config.autoCleanup) {
      this.cleanupOldLogs();
    }
  }

  logFieldExtraction(params: FieldExtractionParams): void {
    if (!this.config.enabled) return;

    const fullLog: FieldExtractionLog = {
      timestamp: Date.now(),
      sourceName: params.sourceName,
      sourceId: params.sourceId,
      fieldName: params.fieldName,
      rule: params.rule,
      ruleType: params.ruleType,
      inputHtml: params.inputHtml,
      inputHtmlLength: params.inputHtmlLength,
      extractedValue: params.extractedValue,
      extractionStatus: params.extractionStatus,
      processingTime: params.processingTime,
      errorMessage: params.errorMessage,
      matchedElements: params.matchedElements,
      suggestions: params.suggestions
    };

    this.fieldLogs.push(fullLog);
    this.enforceLogLimit(this.fieldLogs);

    const statusIcon = this.getStatusIcon(params.extractionStatus);
    Logger.debug(this.TAG, 
      `${statusIcon} 字段提取 [${params.sourceName}] ${params.fieldName}: ` +
      `规则=${params.rule}, 状态=${params.extractionStatus}, 值=${params.extractedValue.substring(0, 50)}`
    );
  }

  logBookListExtraction(params: BookListExtractionParams): void {
    if (!this.config.enabled) return;

    const fullLog: BookListExtractionLog = {
      timestamp: Date.now(),
      sourceName: params.sourceName,
      sourceId: params.sourceId,
      listRule: params.listRule,
      inputHtmlLength: params.inputHtmlLength,
      matchedCount: params.matchedCount,
      extractionStatus: params.extractionStatus,
      htmlPreview: params.htmlPreview,
      errorMessage: params.errorMessage,
      suggestions: params.suggestions
    };

    this.bookListLogs.push(fullLog);
    this.enforceLogLimit(this.bookListLogs);

    const statusIcon = params.matchedCount > 0 ? '✓' : '✗';
    Logger.debug(this.TAG,
      `${statusIcon} 书籍列表提取 [${params.sourceName}]: ` +
      `规则=${params.listRule}, 匹配数=${params.matchedCount}`
    );
  }

  logSearchDebug(params: SearchDebugParams): void {
    if (!this.config.enabled) return;

    const fullLog: SearchDebugLog = {
      timestamp: Date.now(),
      sourceName: params.sourceName,
      sourceId: params.sourceId,
      searchUrl: params.searchUrl,
      keyword: params.keyword,
      responseStatus: params.responseStatus,
      responseTime: params.responseTime,
      responseLength: params.responseLength,
      responsePreview: params.responsePreview,
      parseResult: params.parseResult,
      errors: params.errors,
      warnings: params.warnings
    };

    this.searchLogs.push(fullLog);
    this.enforceLogLimit(this.searchLogs);

    Logger.debug(this.TAG,
      `搜索调试 [${params.sourceName}]: URL=${params.searchUrl}, ` +
      `响应=${params.responseStatus}, 书籍=${params.parseResult.bookCount}, ` +
      `成功=${params.parseResult.successfulBooks}/${params.parseResult.failedBooks}`
    );
  }

  private getStatusIcon(status: string): string {
    switch (status) {
      case 'success': return '✓';
      case 'failed': return '✗';
      case 'empty': return '○';
      case 'error': return '⚠';
      default: return '?';
    }
  }

  private enforceLogLimit<T>(logs: T[]): void {
    if (logs.length > this.config.maxLogsPerSession) {
      logs.splice(0, logs.length - this.config.maxLogsPerSession);
    }
  }

  private cleanupOldLogs(): void {
    const maxAge = 30 * 60 * 1000;
    const now = Date.now();

    this.fieldLogs = this.fieldLogs.filter((log: FieldExtractionLog) => now - log.timestamp < maxAge);
    this.bookListLogs = this.bookListLogs.filter((log: BookListExtractionLog) => now - log.timestamp < maxAge);
    this.searchLogs = this.searchLogs.filter((log: SearchDebugLog) => now - log.timestamp < maxAge);
  }

  getFieldExtractionLogs(sourceId?: string): FieldExtractionLog[] {
    if (sourceId) {
      return this.fieldLogs.filter((log: FieldExtractionLog) => log.sourceId === sourceId);
    }
    return this.fieldLogs.slice();
  }

  getBookListLogs(sourceId?: string): BookListExtractionLog[] {
    if (sourceId) {
      return this.bookListLogs.filter((log: BookListExtractionLog) => log.sourceId === sourceId);
    }
    return this.bookListLogs.slice();
  }

  getSearchLogs(sourceId?: string): SearchDebugLog[] {
    if (sourceId) {
      return this.searchLogs.filter((log: SearchDebugLog) => log.sourceId === sourceId);
    }
    return this.searchLogs.slice();
  }

  getFailedExtractions(sourceId?: string): FieldExtractionLog[] {
    return this.getFieldExtractionLogs(sourceId).filter(
      (log: FieldExtractionLog) => log.extractionStatus === 'failed' || log.extractionStatus === 'error'
    );
  }

  getEmptyResults(sourceId?: string): FieldExtractionLog[] {
    return this.getFieldExtractionLogs(sourceId).filter(
      (log: FieldExtractionLog) => log.extractionStatus === 'empty'
    );
  }

  generateDebugReport(sourceId: string): string {
    const fieldLogs = this.getFieldExtractionLogs(sourceId);
    const bookListLogs = this.getBookListLogs(sourceId);
    const searchLogs = this.getSearchLogs(sourceId);

    const lines: string[] = [];
    lines.push('=== 书源解析调试报告 ===');
    lines.push(`书源ID: ${sourceId}`);
    lines.push(`生成时间: ${new Date().toLocaleString()}`);
    lines.push('');

    if (searchLogs.length > 0) {
      lines.push('【搜索日志】');
      for (let i = 0; i < searchLogs.length; i++) {
        const log = searchLogs[i];
        lines.push(`  时间: ${new Date(log.timestamp).toLocaleTimeString()}`);
        lines.push(`  URL: ${log.searchUrl}`);
        lines.push(`  响应状态: ${log.responseStatus}`);
        lines.push(`  响应时间: ${log.responseTime}ms`);
        lines.push(`  书籍列表: ${log.parseResult.bookListFound ? '找到' : '未找到'}`);
        lines.push(`  成功解析: ${log.parseResult.successfulBooks}/${log.parseResult.bookCount}`);
        if (log.errors.length > 0) {
          lines.push(`  错误:`);
          for (let j = 0; j < log.errors.length; j++) {
            const err = log.errors[j];
            lines.push(`    - [${err.type}] ${err.fieldName}: ${err.message}`);
          }
        }
        lines.push('');
      }
    }

    if (bookListLogs.length > 0) {
      lines.push('【书籍列表提取】');
      for (let i = 0; i < bookListLogs.length; i++) {
        const log = bookListLogs[i];
        lines.push(`  规则: ${log.listRule}`);
        lines.push(`  匹配数: ${log.matchedCount}`);
        lines.push(`  状态: ${log.extractionStatus}`);
        if (log.errorMessage) {
          lines.push(`  错误: ${log.errorMessage}`);
        }
        if (log.suggestions && log.suggestions.length > 0) {
          lines.push(`  建议:`);
          for (let j = 0; j < log.suggestions.length; j++) {
            lines.push(`    - ${log.suggestions[j]}`);
          }
        }
        lines.push('');
      }
    }

    if (fieldLogs.length > 0) {
      lines.push('【字段提取详情】');
      for (let i = 0; i < fieldLogs.length; i++) {
        const log = fieldLogs[i];
        lines.push(`  字段: ${log.fieldName}`);
        lines.push(`  规则: ${log.rule} (${log.ruleType})`);
        lines.push(`  状态: ${log.extractionStatus}`);
        lines.push(`  提取值: ${log.extractedValue || '(空)'}`);
        lines.push(`  处理时间: ${log.processingTime}ms`);
        if (log.errorMessage) {
          lines.push(`  错误: ${log.errorMessage}`);
        }
        if (log.suggestions && log.suggestions.length > 0) {
          lines.push(`  建议:`);
          for (let j = 0; j < log.suggestions.length; j++) {
            lines.push(`    - ${log.suggestions[j]}`);
          }
        }
        lines.push('');
      }
    }

    let failedCount = 0;
    let emptyCount = 0;
    for (let i = 0; i < fieldLogs.length; i++) {
      const log = fieldLogs[i];
      if (log.extractionStatus === 'failed' || log.extractionStatus === 'error') {
        failedCount++;
      } else if (log.extractionStatus === 'empty') {
        emptyCount++;
      }
    }
    
    lines.push('【统计】');
    lines.push(`  字段提取总数: ${fieldLogs.length}`);
    lines.push(`  失败数: ${failedCount}`);
    lines.push(`  空结果数: ${emptyCount}`);
    lines.push(`  成功率: ${fieldLogs.length > 0 ? ((fieldLogs.length - failedCount - emptyCount) / fieldLogs.length * 100).toFixed(1) : 0}%`);

    return lines.join('\n');
  }

  clearLogs(): void {
    this.fieldLogs = [];
    this.bookListLogs = [];
    this.searchLogs = [];
    Logger.info(this.TAG, '调试日志已清空');
  }

  exportLogs(): string {
    const exportData: ExportData = {
      sessionId: this.currentSessionId,
      sessionStartTime: this.sessionStartTime,
      exportTime: Date.now(),
      fieldLogs: this.fieldLogs,
      bookListLogs: this.bookListLogs,
      searchLogs: this.searchLogs
    };
    return JSON.stringify(exportData, null, 2);
  }
}

interface ExportData {
  sessionId: string;
  sessionStartTime: number;
  exportTime: number;
  fieldLogs: FieldExtractionLog[];
  bookListLogs: BookListExtractionLog[];
  searchLogs: SearchDebugLog[];
}

export const parseDebugLogger = ParseDebugLogger.getInstance();
