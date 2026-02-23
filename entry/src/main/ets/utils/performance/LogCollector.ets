/**
 * LogCollector - 日志收集器
 * 用于收集和导出应用日志，方便调试
 */

import { Logger } from "./Logger";

export interface LogEntry {
  timestamp: number;
  level: 'debug' | 'info' | 'warn' | 'error';
  tag: string;
  message: string;
}

export class LogCollector {
  private static instance: LogCollector | null = null;
  private logs: LogEntry[] = [];
  private maxLogs: number = 1000;
  private isCollecting: boolean = true;
  private readonly TAG = 'LogCollector';

  private constructor() {}

  static getInstance(): LogCollector {
    if (!LogCollector.instance) {
      LogCollector.instance = new LogCollector();
    }
    return LogCollector.instance;
  }

  /**
   * 添加日志条目
   */
  addLog(level: 'debug' | 'info' | 'warn' | 'error', tag: string, message: string): void {
    if (!this.isCollecting) {
      return;
    }

    const entry: LogEntry = {
      timestamp: Date.now(),
      level,
      tag,
      message
    };

    this.logs.push(entry);

    // 限制日志数量
    if (this.logs.length > this.maxLogs) {
      this.logs.shift();
    }
  }

  /**
   * 获取所有日志
   */
  getAllLogs(): LogEntry[] {
    return this.logs.slice();
  }

  /**
   * 按标签过滤日志
   */
  getLogsByTag(tag: string): LogEntry[] {
    return this.logs.filter(log => log.tag.includes(tag));
  }

  /**
   * 按级别过滤日志
   */
  getLogsByLevel(level: 'debug' | 'info' | 'warn' | 'error'): LogEntry[] {
    return this.logs.filter(log => log.level === level);
  }

  /**
   * 获取最近的日志
   */
  getRecentLogs(count: number = 50): LogEntry[] {
    return this.logs.slice(-count);
  }

  /**
   * 清空日志
   */
  clearLogs(): void {
    this.logs = [];
    Logger.info(this.TAG, '日志已清空');
  }

  /**
   * 导出日志为字符串
   */
  exportLogs(): string {
    const lines: string[] = [];
    lines.push('=== AstroRead 应用日志 ===');
    lines.push(`导出时间: ${new Date().toLocaleString()}`);
    lines.push(`日志条目数: ${this.logs.length}`);
    lines.push('');

    for (const log of this.logs) {
      const time = new Date(log.timestamp).toLocaleTimeString();
      lines.push(`[${time}][${log.level.toUpperCase()}][${log.tag}] ${log.message}`);
    }

    return lines.join('\n');
  }

  /**
   * 导出特定标签的日志
   */
  exportLogsByTag(tag: string): string {
    const filteredLogs = this.getLogsByTag(tag);
    const lines: string[] = [];
    lines.push(`=== ${tag} 日志 ===`);
    lines.push(`导出时间: ${new Date().toLocaleString()}`);
    lines.push(`日志条目数: ${filteredLogs.length}`);
    lines.push('');

    for (const log of filteredLogs) {
      const time = new Date(log.timestamp).toLocaleTimeString();
      lines.push(`[${time}][${log.level.toUpperCase()}] ${log.message}`);
    }

    return lines.join('\n');
  }

  /**
   * 暂停收集
   */
  pauseCollecting(): void {
    this.isCollecting = false;
  }

  /**
   * 恢复收集
   */
  resumeCollecting(): void {
    this.isCollecting = true;
  }

  /**
   * 设置最大日志数量
   */
  setMaxLogs(max: number): void {
    this.maxLogs = max;
    // 立即裁剪
    if (this.logs.length > max) {
      this.logs = this.logs.slice(-max);
    }
  }
}

// 全局日志收集器实例
export const logCollector = LogCollector.getInstance();
