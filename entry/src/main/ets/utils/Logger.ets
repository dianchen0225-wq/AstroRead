/**
 * 日志工具类 - 统一的日志管理
 * 增强版敏感信息过滤
 * 支持日志级别控制，生产环境自动禁用debug日志
 */

import { logCollector } from './LogCollector';

/**
 * 日志级别枚举
 */
export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  NONE = 4  // 禁用所有日志
}

/**
 * 日志配置接口
 */
export interface LogConfig {
  level: LogLevel;
  enableConsole: boolean;
  enableCollector: boolean;
  isProduction: boolean;
}

class Logger {

  // 默认配置
  private static config: LogConfig = {
    level: LogLevel.DEBUG,
    enableConsole: true,
    enableCollector: true,
    isProduction: false
  };

  // 敏感信息键名列表 - 扩展版
  private static readonly SENSITIVE_KEYS: string[] = [
    'password', 'token', 'secret', 'key', 'auth', 'credential',
    'api_key', 'apikey', 'access_token', 'refresh_token',
    'private', 'session', 'cookie', 'authorization',
    'passwd', 'pwd', 'pass', 'pin', 'otp', 'totp',
    'private_key', 'privatekey', 'secret_key', 'secretkey',
    'bearer', 'jwt', 'id_token', 'identity_token',
    'client_secret', 'clientsecret', 'client_id', 'clientid',
    'user_secret', 'usersecret', 'user_token', 'usertoken',
    'session_id', 'sessionid', 'session_key', 'sessionkey',
    'csrf_token', 'csrftoken', 'xsrf_token', 'xsrftoken',
    'api_secret', 'apisecret', 'api_token', 'apitoken',
    'access_key', 'accesskey', 'secret_access_key',
    'aws_access_key_id', 'aws_secret_access_key',
    'aws_session_token', 'security_token',
    'private_key_data', 'key_data', 'encryption_key',
    'card_number', 'cardnumber', 'cvv', 'cvc', 'expiry',
    'ssn', 'social_security', 'tax_id',
    'phone', 'mobile', 'email', 'address',
    // OAuth 和常见敏感字段
    'oauth_token', 'oauth_secret', 'oauth_consumer_key', 'oauth_consumer_secret',
    'grant_type', 'code_verifier', 'code_challenge',
    'device_code', 'user_code', 'registration_token',
    'firebase_token', 'push_token', 'fcm_token',
    'apikey', 'app_key', 'app_secret', 'appkey', 'appsecret',
    'consumer_key', 'consumer_secret', 'oauth_token_secret',
    'idtoken', 'accesstoken', 'refreshtoken',
    'account_id', 'accountid', 'user_id', 'userid',
    'bank_account', 'bankaccount', 'iban', 'routing_number',
    'passport', 'license', 'dob', 'birthdate', 'birth_date',
    'mother_maiden', 'maiden_name', 'first_pet', 'favorite_color',
    // 新增：更多敏感字段
    'credit_card', 'creditcard', 'debit_card', 'debitcard',
    'security_answer', 'security_question', 'recovery_code',
    'backup_code', 'verification_code', 'verify_code',
    'reset_token', 'activate_token', 'invite_code', 'invitation_code',
    'api_sign', 'signature', 'sign', 'checksum', 'hash',
    'salt', 'iv', 'nonce', 'encrypted', 'cipher'
  ];

  private static readonly SENSITIVE_HEADERS: string[] = [
    'authorization', 'cookie', 'set-cookie', 'x-auth-token',
    'x-api-key', 'x-access-token', 'x-refresh-token',
    'x-session-id', 'x-csrf-token', 'x-xsrf-token',
    'www-authenticate', 'proxy-authorization',
    'x-api-secret', 'x-client-secret', 'x-user-token',
    'x-api-sign', 'x-signature', 'x-request-signature'
  ];

  private static readonly SENSITIVE_URL_PARAMS: string[] = [
    'token', 'access_token', 'refresh_token', 'auth', 'key',
    'api_key', 'apikey', 'secret', 'session', 'session_id',
    'password', 'passwd', 'pwd', 'private_key', 'signature',
    'sign', 'code', 'authorization_code', 'state',
    'verify_code', 'verification_code', 'reset_token'
  ];

  private static readonly MASK = '******';
  private static readonly MAX_LOG_LENGTH = 10000;
  
  // 敏感值模式（正则表达式）
  private static readonly SENSITIVE_VALUE_PATTERNS: RegExp[] = [
    // JWT Token
    /\beyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*/g,
    // 长Base64字符串（可能是密钥）
    /\b[A-Za-z0-9+/]{40,}={0,2}\b/g,
    // 长十六进制字符串（可能是密钥）
    /\b[a-fA-F0-9]{32,}\b/g,
    // 长数字序列（可能是卡号）
    /\b\d{13,19}\b/g,
    // UUID格式的token
    /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi
  ];

  /**
   * 初始化日志配置
   */
  static init(config: Partial<LogConfig>): void {
    if (config.level !== undefined) Logger.config.level = config.level;
    if (config.enableConsole !== undefined) Logger.config.enableConsole = config.enableConsole;
    if (config.enableCollector !== undefined) Logger.config.enableCollector = config.enableCollector;
    if (config.isProduction !== undefined) Logger.config.isProduction = config.isProduction;
    
    // 生产环境自动设置日志级别
    if (Logger.config.isProduction) {
      Logger.config.level = LogLevel.WARN;
    }
  }

  /**
   * 设置日志级别
   */
  static setLogLevel(level: LogLevel): void {
    Logger.config.level = level;
  }

  /**
   * 设置是否为生产环境
   */
  static setProductionMode(isProduction: boolean): void {
    Logger.config.isProduction = isProduction;
    if (isProduction) {
      Logger.config.level = LogLevel.WARN;
    }
  }

  /**
   * 检查是否应该输出指定级别的日志
   */
  private static shouldLog(level: LogLevel): boolean {
    return level >= Logger.config.level;
  }

  /**
   * 过滤敏感信息 - 增强版
   */
  private static filterSensitiveInfo(message: string): string {
    if (!message) return '';

    let filteredMessage = message;

    if (filteredMessage.length > Logger.MAX_LOG_LENGTH) {
      filteredMessage = filteredMessage.substring(0, Logger.MAX_LOG_LENGTH) + '...[truncated]';
    }

    filteredMessage = Logger.filterUrlParams(filteredMessage);
    filteredMessage = Logger.filterHeaders(filteredMessage);
    filteredMessage = Logger.filterJsonKeys(filteredMessage);
    filteredMessage = Logger.filterKeyValuePairs(filteredMessage);
    filteredMessage = Logger.filterBase64Sensitive(filteredMessage);
    filteredMessage = Logger.filterEmailAndPhone(filteredMessage);
    filteredMessage = Logger.filterSensitiveValuePatterns(filteredMessage);

    return filteredMessage;
  }
  
  /**
   * 过滤敏感值模式（JWT、Base64密钥等）
   */
  private static filterSensitiveValuePatterns(message: string): string {
    let filtered = message;
    
    for (const pattern of Logger.SENSITIVE_VALUE_PATTERNS) {
      filtered = filtered.replace(pattern, (match: string) => {
        if (match.startsWith('eyJ')) {
          return '[JWT_TOKEN]';
        }
        if (/^[A-Za-z0-9+/]+=*$/.test(match) && match.length > 40) {
          return `[BASE64_KEY:${match.length}chars]`;
        }
        if (/^[a-fA-F0-9]+$/.test(match) && match.length >= 32) {
          return `[HEX_KEY:${match.length}chars]`;
        }
        if (/^\d+$/.test(match) && match.length >= 13) {
          return '[CARD_NUMBER]';
        }
        if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(match)) {
          return '[UUID_TOKEN]';
        }
        return '[SENSITIVE_VALUE]';
      });
    }
    
    return filtered;
  }

  /**
   * 过滤 URL 查询参数中的敏感信息
   */
  private static filterUrlParams(message: string): string {
    let filtered = message;

    for (const param of Logger.SENSITIVE_URL_PARAMS) {
      const patterns = [
        new RegExp(`[?&]${param}=([^&\\s]+)`, 'gi'),
        new RegExp(`${param}=([^&\\s]+)`, 'gi'),
      ];

      for (const pattern of patterns) {
        filtered = filtered.replace(pattern, (match: string, value: string) => {
          return match.replace(value, Logger.MASK);
        });
      }
    }

    return filtered;
  }

  /**
   * 过滤请求头中的敏感信息
   */
  private static filterHeaders(message: string): string {
    let filtered = message;

    for (const header of Logger.SENSITIVE_HEADERS) {
      const patterns = [
        new RegExp(`"${header}"\\s*:\\s*"[^"]*"`, 'gi'),
        new RegExp(`'${header}'\\s*:\\s*'[^']*'`, 'gi'),
        new RegExp(`${header}\\s*:\\s*[^\\s,\\n]+`, 'gi'),
        new RegExp(`${header}\\s*=\\s*[^\\s,\\n]+`, 'gi'),
        new RegExp(`\\b${header}\\b\\s*[:=]\\s*\\S+`, 'gi'),
      ];

      for (const pattern of patterns) {
        filtered = filtered.replace(pattern, `"${header}": "${Logger.MASK}"`);
      }
    }

    return filtered;
  }

  /**
   * 过滤 JSON 键值对中的敏感信息
   */
  private static filterJsonKeys(message: string): string {
    let filtered = message;

    for (const key of Logger.SENSITIVE_KEYS) {
      const patterns = [
        new RegExp(`"${key}"\\s*:\\s*"[^"]*"`, 'gi'),
        new RegExp(`'${key}'\\s*:\\s*'[^']*'`, 'gi'),
        new RegExp(`"${key}"\\s*:\\s*[^,}\\]]+`, 'gi'),
        new RegExp(`'${key}'\\s*:\\s*[^,}\\]]+`, 'gi'),
        new RegExp(`"${key}"\\s*:\\s*\\d+`, 'gi'),
      ];

      for (const pattern of patterns) {
        filtered = filtered.replace(pattern, `"${key}": "${Logger.MASK}"`);
      }
    }

    return filtered;
  }

  /**
   * 过滤键值对形式的敏感信息
   */
  private static filterKeyValuePairs(message: string): string {
    let filtered = message;

    for (const key of Logger.SENSITIVE_KEYS) {
      const patterns = [
        new RegExp(`${key}\\s*=\\s*[^\\s&]+`, 'gi'),
        new RegExp(`${key}[:：]\\s*\\S+`, 'gi'),
        new RegExp(`\\b${key}\\b\\s*=\\s*"[^"]*"`, 'gi'),
        new RegExp(`\\b${key}\\b\\s*=\\s*'[^']*'`, 'gi'),
      ];

      for (const pattern of patterns) {
        filtered = filtered.replace(pattern, `${key}=${Logger.MASK}`);
      }
    }

    return filtered;
  }

  /**
   * 过滤可能包含敏感信息的 Base64 编码字符串
   */
  private static filterBase64Sensitive(message: string): string {
    let filtered = message;

    const base64Pattern = /\b([A-Za-z0-9+/]{40,}={0,2})\b/g;

    filtered = filtered.replace(base64Pattern, (match: string) => {
      if (match.length > 40) {
        return `[BASE64:${match.length}chars]`;
      }
      return match;
    });

    const jwtPattern = /\beyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*/g;
    filtered = filtered.replace(jwtPattern, '[JWT_TOKEN]');

    return filtered;
  }

  /**
   * 过滤邮箱和手机号
   */
  private static filterEmailAndPhone(message: string): string {
    let filtered = message;

    const emailPattern = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g;
    filtered = filtered.replace(emailPattern, '[EMAIL]');

    const phonePattern = /\b(?:\+?86)?1[3-9]\d{9}\b/g;
    filtered = filtered.replace(phonePattern, '[PHONE]');

    const idCardPattern = /\b\d{17}[\dXx]\b/g;
    filtered = filtered.replace(idCardPattern, '[ID_CARD]');

    const bankCardPattern = /\b\d{16,19}\b/g;
    filtered = filtered.replace(bankCardPattern, (match: string) => {
      if (/^\d{16,19}$/.test(match) && !/^1[3-9]\d{9}$/.test(match)) {
        return '[CARD_NUMBER]';
      }
      return match;
    });

    return filtered;
  }

  /**
   * 调试日志
   * 生产环境自动禁用
   */
  static debug(tag: string, message: string): void {
    if (!Logger.shouldLog(LogLevel.DEBUG)) {
      return;
    }
    
    const filteredMessage = Logger.filterSensitiveInfo(message);
    
    if (Logger.config.enableConsole) {
      console.debug(`[DEBUG][${tag}] ${filteredMessage}`);
    }
    
    if (Logger.config.enableCollector) {
      logCollector.addLog('debug', tag, filteredMessage);
    }
  }

  /**
   * 信息日志
   */
  static info(tag: string, message: string): void {
    if (!Logger.shouldLog(LogLevel.INFO)) {
      return;
    }
    
    const filteredMessage = Logger.filterSensitiveInfo(message);
    
    if (Logger.config.enableConsole) {
      console.info(`[INFO][${tag}] ${filteredMessage}`);
    }
    
    if (Logger.config.enableCollector) {
      logCollector.addLog('info', tag, filteredMessage);
    }
  }

  /**
   * 警告日志
   */
  static warn(tag: string, message: string): void {
    if (!Logger.shouldLog(LogLevel.WARN)) {
      return;
    }
    
    const filteredMessage = Logger.filterSensitiveInfo(message);
    
    if (Logger.config.enableConsole) {
      console.warn(`[WARN][${tag}] ${filteredMessage}`);
    }
    
    if (Logger.config.enableCollector) {
      logCollector.addLog('warn', tag, filteredMessage);
    }
  }

  /**
   * 错误日志
   */
  static error(tag: string, message: string): void {
    if (!Logger.shouldLog(LogLevel.ERROR)) {
      return;
    }
    
    const filteredMessage = Logger.filterSensitiveInfo(message);
    
    if (Logger.config.enableConsole) {
      console.error(`[ERROR][${tag}] ${filteredMessage}`);
    }
    
    if (Logger.config.enableCollector) {
      logCollector.addLog('error', tag, filteredMessage);
    }
  }

  /**
   * 性能日志
   * 生产环境自动禁用
   */
  static performance(tag: string, operation: string, duration: number): void {
    if (!Logger.shouldLog(LogLevel.DEBUG)) {
      return;
    }
    
    if (Logger.config.enableConsole) {
      console.debug(`[PERF][${tag}] ${operation} 耗时: ${duration}ms`);
    }
  }

  /**
   * 设置调试模式（向后兼容方法）
   * @deprecated 请使用 setLogLevel 或 setProductionMode
   */
  static setDebugEnabled(enabled: boolean): void {
    Logger.config.level = enabled ? LogLevel.DEBUG : LogLevel.WARN;
  }
  
  /**
   * 获取当前日志级别
   */
  static getLogLevel(): LogLevel {
    return Logger.config.level;
  }
  
  /**
   * 检查是否为生产环境
   */
  static isProduction(): boolean {
    return Logger.config.isProduction;
  }
  
  /**
   * 添加自定义敏感词
   */
  static addSensitiveKey(key: string): void {
    const lowerKey = key.toLowerCase();
    if (!Logger.SENSITIVE_KEYS.includes(lowerKey)) {
      Logger.SENSITIVE_KEYS.push(lowerKey);
    }
  }

  /**
   * 添加自定义敏感请求头
   */
  static addSensitiveHeader(header: string): void {
    const lowerHeader = header.toLowerCase();
    if (!Logger.SENSITIVE_HEADERS.includes(lowerHeader)) {
      Logger.SENSITIVE_HEADERS.push(lowerHeader);
    }
  }

  /**
   * 添加自定义敏感 URL 参数
   */
  static addSensitiveUrlParam(param: string): void {
    const lowerParam = param.toLowerCase();
    if (!Logger.SENSITIVE_URL_PARAMS.includes(lowerParam)) {
      Logger.SENSITIVE_URL_PARAMS.push(lowerParam);
    }
  }

  /**
   * 安全记录对象（深度过滤敏感字段）
   * 增强版：递归检查嵌套对象，限制序列化深度和大小
   */
  static safeStringify(obj: object, depth: number = 3, maxSize: number = 50000): string {
    try {
      const seen = new WeakSet<object>();
      
      const result: string = JSON.stringify(obj, (key: string, value: Object | null | string | number | boolean) => {
        if (depth <= 0) return '[MAX_DEPTH]';
        
        const lowerKey: string = key.toLowerCase();
        for (const sensitiveKey of Logger.SENSITIVE_KEYS) {
          if (lowerKey.includes(sensitiveKey)) {
            return Logger.MASK;
          }
        }
        
        if (value !== null && typeof value === 'object') {
          if (seen.has(value as object)) {
            return '[CIRCULAR_REFERENCE]';
          }
          seen.add(value as object);
          
          if (Array.isArray(value)) {
            if (value.length > 100) {
              const truncated: (Object | null | string | number | boolean)[] = value.slice(0, 100);
              truncated.push(`[${value.length - 100} more items...]`);
              return truncated;
            }
          } else {
            const filteredObj: Record<string, Object | null | string | number | boolean> = {};
            const entries: [string, Object | null | string | number | boolean][] = Object.entries(value);
            for (let i: number = 0; i < entries.length; i++) {
              const entry: [string, Object | null | string | number | boolean] = entries[i];
              const k: string = entry[0];
              const v: Object | null | string | number | boolean = entry[1];
              const lowerK: string = k.toLowerCase();
              let isSensitive: boolean = false;
              for (const sensitiveKey of Logger.SENSITIVE_KEYS) {
                if (lowerK.includes(sensitiveKey)) {
                  filteredObj[k] = Logger.MASK;
                  isSensitive = true;
                  break;
                }
              }
              if (!isSensitive) {
                filteredObj[k] = v;
              }
            }
            return filteredObj;
          }
        }
        
        if (typeof value === 'string') {
          for (const sensitiveKey of Logger.SENSITIVE_KEYS) {
            if (lowerKey.includes(sensitiveKey)) {
              return Logger.MASK;
            }
          }
          const strValue: string = value as string;
          if (strValue.length > 500) {
            return strValue.substring(0, 500) + '...[truncated]';
          }
        }
        
        return value;
      }, 2);
      
      if (result.length > maxSize) {
        return result.substring(0, maxSize) + '\n...[OUTPUT_TRUNCATED]';
      }
      
      return result;
    } catch (error) {
      return '[OBJECT_SERIALIZATION_ERROR]';
    }
  }
  
  /**
   * 递归过滤对象中的所有敏感字段
   * 用于深度清理对象，确保没有敏感信息泄露
   */
  static deepFilterSensitive(obj: Object | null, depth: number = 5): Object | null {
    if (depth <= 0) return '[MAX_DEPTH]';
    
    if (obj === null) {
      return null;
    }
    
    if (typeof obj === 'string') {
      // 检查字符串是否包含敏感模式
      let filtered: string = obj as string;
      for (const key of Logger.SENSITIVE_KEYS) {
        // 匹配 key=value 或 key: value 模式
        const pattern: RegExp = new RegExp(`(${key})[=:]\\s*\\S+`, 'gi');
        filtered = filtered.replace(pattern, `$1=${Logger.MASK}`);
      }
      return filtered;
    }
    
    if (typeof obj !== 'object') {
      return obj;
    }
    
    if (Array.isArray(obj)) {
      const arr: Object[] = obj as Object[];
      return arr.map((item: Object) => Logger.deepFilterSensitive(item, depth - 1));
    }
    
    // 处理普通对象
    const result: Record<string, Object | null> = {};
    const entries: [string, Object][] = Object.entries(obj);
    for (let i: number = 0; i < entries.length; i++) {
      const entry: [string, Object] = entries[i];
      const key: string = entry[0];
      const value: Object = entry[1];
      const lowerKey: string = key.toLowerCase();
      let isSensitive: boolean = false;
      
      // 检查键名是否敏感
      for (const sensitiveKey of Logger.SENSITIVE_KEYS) {
        if (lowerKey.includes(sensitiveKey)) {
          result[key] = Logger.MASK;
          isSensitive = true;
          break;
        }
      }
      
      if (!isSensitive) {
        result[key] = Logger.deepFilterSensitive(value, depth - 1);
      }
    }
    
    return result;
  }
}

export { Logger };
