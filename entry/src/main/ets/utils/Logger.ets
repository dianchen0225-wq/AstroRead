/**
 * 日志工具类 - 统一的日志管理
 */

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
    if (Logger.isDebugEnabled) {
      console.debug(`[DEBUG][${tag}] ${Logger.filterSensitiveInfo(message)}`);
    }
  }
  
  /**
   * 信息日志
   */
  static info(tag: string, message: string): void {
    console.info(`[INFO][${tag}] ${Logger.filterSensitiveInfo(message)}`);
  }
  
  /**
   * 警告日志
   */
  static warn(tag: string, message: string): void {
    console.warn(`[WARN][${tag}] ${Logger.filterSensitiveInfo(message)}`);
  }
  
  /**
   * 错误日志
   */
  static error(tag: string, message: string): void {
    console.error(`[ERROR][${tag}] ${Logger.filterSensitiveInfo(message)}`);
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
