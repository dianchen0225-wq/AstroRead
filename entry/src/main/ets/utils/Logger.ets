/**
 * 日志工具类 - 统一的日志管理
 */

import { logCollector } from './LogCollector';

class Logger {
  
  private static isDebugEnabled: boolean = true;
  
  private static readonly SENSITIVE_KEYS: string[] = [
    'password', 'token', 'secret', 'key', 'auth', 'credential',
    'api_key', 'apikey', 'access_token', 'refresh_token',
    'private', 'session', 'cookie', 'authorization'
  ];
  
  private static readonly MASK = '******';
  
  /**
   * 设置调试模式
   */
  static setDebugEnabled(enabled: boolean): void {
    Logger.isDebugEnabled = enabled;
  }
  
  /**
   * 过滤敏感信息
   */
  private static filterSensitiveInfo(message: string): string {
    let filteredMessage = message;
    
    for (const key of Logger.SENSITIVE_KEYS) {
      const patterns = [
        new RegExp(`"${key}"\\s*:\\s*"[^"]*"`, 'gi'),
        new RegExp(`'${key}'\\s*:\\s*'[^']*'`, 'gi'),
        new RegExp(`${key}\\s*=\\s*[^\\s&]+`, 'gi'),
        new RegExp(`"${key}"\\s*:\\s*[^,}\\]]+`, 'gi'),
        new RegExp(`${key}[:：]\\s*\\S+`, 'gi')
      ];
      
      for (const pattern of patterns) {
        filteredMessage = filteredMessage.replace(pattern, `"${key}": "${Logger.MASK}"`);
      }
    }
    
    return filteredMessage;
  }
  
  /**
   * 调试日志
   */
  static debug(tag: string, message: string): void {
    const filteredMessage = Logger.filterSensitiveInfo(message);
    if (Logger.isDebugEnabled) {
      console.debug(`[DEBUG][${tag}] ${filteredMessage}`);
    }
    logCollector.addLog('debug', tag, filteredMessage);
  }

  /**
   * 信息日志
   */
  static info(tag: string, message: string): void {
    const filteredMessage = Logger.filterSensitiveInfo(message);
    console.info(`[INFO][${tag}] ${filteredMessage}`);
    logCollector.addLog('info', tag, filteredMessage);
  }

  /**
   * 警告日志
   */
  static warn(tag: string, message: string): void {
    const filteredMessage = Logger.filterSensitiveInfo(message);
    console.warn(`[WARN][${tag}] ${filteredMessage}`);
    logCollector.addLog('warn', tag, filteredMessage);
  }

  /**
   * 错误日志
   */
  static error(tag: string, message: string): void {
    const filteredMessage = Logger.filterSensitiveInfo(message);
    console.error(`[ERROR][${tag}] ${filteredMessage}`);
    logCollector.addLog('error', tag, filteredMessage);
  }
  
  /**
   * 性能日志
   */
  static performance(tag: string, operation: string, duration: number): void {
    if (Logger.isDebugEnabled) {
      console.debug(`[PERF][${tag}] ${operation} 耗时: ${duration}ms`);
    }
  }
  
  /**
   * 添加自定义敏感词
   */
  static addSensitiveKey(key: string): void {
    if (!Logger.SENSITIVE_KEYS.includes(key.toLowerCase())) {
      Logger.SENSITIVE_KEYS.push(key.toLowerCase());
    }
  }
}

export { Logger };
