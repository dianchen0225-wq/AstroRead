/**
 * 日志工具类 - 统一的日志管理
 * 增强版敏感信息过滤
 */

import { logCollector } from './LogCollector';

class Logger {

  private static isDebugEnabled: boolean = true;

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
    'phone', 'mobile', 'email', 'address'
  ];

  private static readonly SENSITIVE_HEADERS: string[] = [
    'authorization', 'cookie', 'set-cookie', 'x-auth-token',
    'x-api-key', 'x-access-token', 'x-refresh-token',
    'x-session-id', 'x-csrf-token', 'x-xsrf-token',
    'www-authenticate', 'proxy-authorization',
    'x-api-secret', 'x-client-secret', 'x-user-token'
  ];

  private static readonly SENSITIVE_URL_PARAMS: string[] = [
    'token', 'access_token', 'refresh_token', 'auth', 'key',
    'api_key', 'apikey', 'secret', 'session', 'session_id',
    'password', 'passwd', 'pwd', 'private_key', 'signature',
    'sign', 'code', 'authorization_code', 'state'
  ];

  private static readonly MASK = '******';
  private static readonly MAX_LOG_LENGTH = 10000;

  /**
   * 设置调试模式
   */
  static setDebugEnabled(enabled: boolean): void {
    Logger.isDebugEnabled = enabled;
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

    return filteredMessage;
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
   */
  static safeStringify(obj: object, depth: number = 3): string {
    try {
      return JSON.stringify(obj, (key: string, value: object) => {
        if (depth <= 0) return '[MAX_DEPTH]';

        const lowerKey = key.toLowerCase();
        for (const sensitiveKey of Logger.SENSITIVE_KEYS) {
          if (lowerKey.includes(sensitiveKey)) {
            return Logger.MASK;
          }
        }

        if (typeof value === 'string') {
          if (value.length > 100) {
            return value.substring(0, 100) + '...[truncated]';
          }
        }

        return value;
      }, 2);
    } catch (error) {
      return '[OBJECT_SERIALIZATION_ERROR]';
    }
  }
}

export { Logger };
