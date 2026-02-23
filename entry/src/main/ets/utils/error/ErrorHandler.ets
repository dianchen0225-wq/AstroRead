/**
 * 错误类型
 */
export enum ErrorType {
  NETWORK_ERROR = 'network_error',
  PARSE_ERROR = 'parse_error',
  DATABASE_ERROR = 'database_error',
  FILE_ERROR = 'file_error',
  PERMISSION_ERROR = 'permission_error',
  UNKNOWN_ERROR = 'unknown_error'
}

/**
 * 自定义错误类
 */
export class AppError extends Error {
  type: ErrorType;
  code: string;
  userMessage: string;

  constructor(
    type: ErrorType,
    message: string,
    code: string = '',
    userMessage: string = ''
  ) {
    super(message);
    this.type = type;
    this.code = code;
    this.userMessage = userMessage || this.getDefaultUserMessage(type);
  }

  private getDefaultUserMessage(type: ErrorType): string {
    const messages: Record<ErrorType, string> = {
      [ErrorType.NETWORK_ERROR]: '网络连接失败，请检查网络设置',
      [ErrorType.PARSE_ERROR]: '数据解析失败，请重试',
      [ErrorType.DATABASE_ERROR]: '数据库操作失败，请重试',
      [ErrorType.FILE_ERROR]: '文件操作失败，请检查文件权限',
      [ErrorType.PERMISSION_ERROR]: '权限不足，请在设置中授予相应权限',
      [ErrorType.UNKNOWN_ERROR]: '发生未知错误，请重试'
    };
    return messages[type] || messages[ErrorType.UNKNOWN_ERROR];
  }
}

/**
 * 错误处理器
 */
export class ErrorHandler {
  /**
   * 处理错误并返回用户友好的消息
   */
  static handleError(error: Error): string {
    if (error instanceof AppError) {
      return error.userMessage;
    }

    // 根据错误消息判断错误类型
    const message = error.message.toLowerCase();
    
    if (message.includes('network') || message.includes('http') || message.includes('fetch')) {
      return '网络连接失败，请检查网络设置';
    }
    
    if (message.includes('parse') || message.includes('json')) {
      return '数据解析失败，请重试';
    }
    
    if (message.includes('database') || message.includes('sql')) {
      return '数据库操作失败，请重试';
    }
    
    if (message.includes('file') || message.includes('permission')) {
      return '文件操作失败，请检查文件权限';
    }

    return '发生未知错误，请重试';
  }

  /**
   * 创建网络错误
   */
  static createNetworkError(message: string, code: string = ''): AppError {
    return new AppError(ErrorType.NETWORK_ERROR, message, code);
  }

  /**
   * 创建解析错误
   */
  static createParseError(message: string, code: string = ''): AppError {
    return new AppError(ErrorType.PARSE_ERROR, message, code);
  }

  /**
   * 创建数据库错误
   */
  static createDatabaseError(message: string, code: string = ''): AppError {
    return new AppError(ErrorType.DATABASE_ERROR, message, code);
  }
}
