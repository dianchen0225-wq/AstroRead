/**
 * 日志工具类 - 统一的日志管理
 */

class Logger {
  
  private static isDebugEnabled: boolean = true;
  
  /**
   * 设置调试模式
   */
  static setDebugEnabled(enabled: boolean): void {
    Logger.isDebugEnabled = enabled;
  }
  
  /**
   * 调试日志
   */
  static debug(tag: string, message: string): void {
    if (Logger.isDebugEnabled) {
      console.debug(`[DEBUG][${tag}] ${message}`);
    }
  }
  
  /**
   * 信息日志
   */
  static info(tag: string, message: string): void {
    console.info(`[INFO][${tag}] ${message}`);
  }
  
  /**
   * 警告日志
   */
  static warn(tag: string, message: string): void {
    console.warn(`[WARN][${tag}] ${message}`);
  }
  
  /**
   * 错误日志
   */
  static error(tag: string, message: string): void {
    console.error(`[ERROR][${tag}] ${message}`);
  }
  
  /**
   * 性能日志
   */
  static performance(tag: string, operation: string, duration: number): void {
    if (Logger.isDebugEnabled) {
      console.debug(`[PERF][${tag}] ${operation} 耗时: ${duration}ms`);
    }
  }
}

export { Logger };