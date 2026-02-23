/**
 * SecurityUtils - 安全工具类
 * 统一处理路径安全、输入验证、编码安全等
 * 修复路径遍历、多重编码绕过等安全漏洞
 */

import { Logger } from "../performance/Logger";

export class SecurityUtils {
  private static readonly TAG = 'SecurityUtils';
  
  // 路径相关常量
  private static readonly MAX_PATH_LENGTH = 4096;
  private static readonly MAX_FILENAME_LENGTH = 255;
  private static readonly MAX_DECODE_ITERATIONS = 5;
  
  // 危险模式
  private static readonly PATH_TRAVERSAL_PATTERNS = [
    /\.\.\//g,                    // Unix: ../
    /\.\.\\/g,                   // Windows: ..\
    /%2e%2e%2f/gi,              // URL编码: %2e%2e%2f (../)
    /%2e%2e%5c/gi,              // URL编码: %2e%2e%5c (..\)
    /%252e%252e%252f/gi,        // 双重URL编码
    /%252e%252e%255c/gi,        // 双重URL编码
    /%c0%ae%c0%ae%c0%af/gi,     // UTF-8编码绕过
    /%c0%ae%c0%ae%c1%9c/gi,     // UTF-8编码绕过
    /\.{3,}/g,                  // 三个或更多点
    /\.\.\/\.\.\//g,           // 多重遍历
    /\.\.\\\.\.\\/g,           // 多重遍历
  ];
  
  // 危险字符
  private static readonly DANGEROUS_CHARS = /[\x00-\x1f\x7f<>"|?*]/g;
  
  // 允许的扩展名白名单
  private static readonly ALLOWED_EXTENSIONS = new Set([
    '.txt', '.json', '.xml', '.epub', '.pdf'
  ]);
  
  // 禁止的系统路径
  private static readonly FORBIDDEN_PATHS = [
    '/etc/', '/usr/', '/bin/', '/sbin/', '/lib/', '/lib64/',
    '/boot/', '/dev/', '/proc/', '/sys/', '/root/', '/home/',
    'c:/windows/', 'c:/program files/', 'c:/programdata/',
    '/system/', '/applications/', '/library/',
    'c:/users/', '/var/', '/opt/', '/tmp/',
  ];

  /**
   * 深度解码路径 - 防止多重编码绕过
   * @param path 原始路径
   * @returns 解码后的路径
   */
  static deepDecodePath(path: string): string {
    if (!path) return '';
    
    let decoded = path;
    let iterations = 0;
    
    while (iterations < SecurityUtils.MAX_DECODE_ITERATIONS) {
      let changed = false;
      
      // URL解码
      try {
        const urlDecoded = decodeURIComponent(decoded);
        if (urlDecoded !== decoded) {
          decoded = urlDecoded;
          changed = true;
        }
      } catch (e) {
        // 解码失败，继续
      }
      
      // HTML实体解码
      const htmlDecoded = SecurityUtils.decodeHtmlEntities(decoded);
      if (htmlDecoded !== decoded) {
        decoded = htmlDecoded;
        changed = true;
      }
      
      // Unicode规范化
      try {
        const normalized = decoded.normalize('NFC');
        if (normalized !== decoded) {
          decoded = normalized;
          changed = true;
        }
      } catch (e) {
        // 规范化失败，继续
      }
      
      if (!changed) break;
      iterations++;
    }
    
    return decoded;
  }

  /**
   * 规范化路径 - 统一处理不同系统的路径格式
   * @param path 原始路径
   * @returns 规范化后的路径
   */
  static normalizePath(path: string): string {
    if (!path) return '';
    
    // 统一使用正斜杠
    let normalized = path.replace(/\\/g, '/');
    
    // 移除多余的斜杠
    while (normalized.includes('//')) {
      normalized = normalized.replace(/\/\//g, '/');
    }
    
    // 移除当前目录引用
    normalized = normalized.replace(/\/\.\//g, '/');
    
    // 处理开头的 ./
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    
    // 处理结尾的 /
    if (normalized.endsWith('/') && normalized.length > 1) {
      normalized = normalized.slice(0, -1);
    }
    
    return normalized;
  }

  /**
   * 解析路径遍历 - 将路径中的 .. 和 . 解析为实际路径
   * @param path 原始路径
   * @returns 解析后的路径
   */
  static resolvePathTraversal(path: string): string {
    if (!path) return '';
    
    const parts = path.split('/');
    const resolved: string[] = [];
    
    for (const part of parts) {
      if (part === '..') {
        // 尝试返回上级目录
        if (resolved.length > 0 && resolved[resolved.length - 1] !== '..') {
          resolved.pop();
        } else {
          resolved.push('..');
        }
      } else if (part !== '.' && part !== '') {
        resolved.push(part);
      }
    }
    
    // 保留开头的 /
    const isAbsolute = path.startsWith('/');
    let result = resolved.join('/');
    if (isAbsolute && !result.startsWith('/')) {
      result = '/' + result;
    }
    
    return result;
  }

  /**
   * 检查路径是否安全 - 防止路径遍历攻击
   * @param path 要检查的路径
   * @param basePath 基础路径（沙盒根目录）
   * @returns 是否安全
   */
  static isSafePath(path: string, basePath: string): boolean {
    if (!path || !basePath) {
      Logger.warn(SecurityUtils.TAG, '路径或基础路径为空');
      return false;
    }
    
    // 长度检查
    if (path.length > SecurityUtils.MAX_PATH_LENGTH) {
      Logger.warn(SecurityUtils.TAG, `路径过长: ${path.length}`);
      return false;
    }
    
    // 空字节检查
    if (path.includes('\0') || path.includes('%00')) {
      Logger.warn(SecurityUtils.TAG, '路径包含空字节');
      return false;
    }
    
    // 深度解码
    let decodedPath = SecurityUtils.deepDecodePath(path);
    
    // 规范化
    decodedPath = SecurityUtils.normalizePath(decodedPath);
    
    // 解析路径遍历
    const resolvedPath = SecurityUtils.resolvePathTraversal(decodedPath);
    
    // 检查是否包含 ..（解析后仍然存在的表示试图跳出根目录）
    if (resolvedPath.includes('..')) {
      Logger.warn(SecurityUtils.TAG, '路径包含目录遍历');
      return false;
    }
    
    // 规范化基础路径
    const normalizedBase = SecurityUtils.normalizePath(basePath);
    
    // 确保最终路径在基础路径内
    // 如果路径不是以基础路径开头，则不安全
    const isWithinBase = resolvedPath.startsWith(normalizedBase) || 
                         (!resolvedPath.startsWith('/') && !resolvedPath.includes(':'));
    
    if (!isWithinBase) {
      Logger.warn(SecurityUtils.TAG, `路径不在安全范围内: ${resolvedPath}`);
      return false;
    }
    
    // 检查禁止路径
    const lowerPath = resolvedPath.toLowerCase();
    for (const forbidden of SecurityUtils.FORBIDDEN_PATHS) {
      if (lowerPath.startsWith(forbidden)) {
        Logger.warn(SecurityUtils.TAG, `路径指向禁止目录: ${forbidden}`);
        return false;
      }
    }
    
    return true;
  }

  /**
   * 清理文件名 - 移除危险字符
   * @param fileName 原始文件名
   * @returns 清理后的文件名
   */
  static sanitizeFileName(fileName: string): string {
    if (!fileName) return '';
    
    let sanitized = fileName.trim();
    
    // 移除危险字符
    sanitized = sanitized.replace(SecurityUtils.DANGEROUS_CHARS, '_');
    
    // 移除路径分隔符
    sanitized = sanitized.replace(/[\/]/g, '_');
    
    // 移除控制字符
    sanitized = sanitized.replace(/[\x00-\x1f\x7f]/g, '');
    
    // 处理以点开头的文件名（隐藏文件）
    if (sanitized.startsWith('.')) {
      sanitized = '_' + sanitized;
    }
    
    // 限制长度
    if (sanitized.length > SecurityUtils.MAX_FILENAME_LENGTH) {
      const lastDot = sanitized.lastIndexOf('.');
      if (lastDot > 0) {
        const ext = sanitized.substring(lastDot);
        const name = sanitized.substring(0, lastDot);
        sanitized = name.substring(0, SecurityUtils.MAX_FILENAME_LENGTH - ext.length) + ext;
      } else {
        sanitized = sanitized.substring(0, SecurityUtils.MAX_FILENAME_LENGTH);
      }
    }
    
    // 如果清理后为空，使用默认名
    if (!sanitized || sanitized.trim().length === 0) {
      sanitized = `file_${Date.now()}`;
    }
    
    return sanitized;
  }

  /**
   * 验证文件扩展名
   * @param fileName 文件名
   * @returns 是否允许
   */
  static isAllowedExtension(fileName: string): boolean {
    if (!fileName) return false;
    
    const lastDot = fileName.lastIndexOf('.');
    if (lastDot < 0) return false;
    
    const ext = fileName.substring(lastDot).toLowerCase();
    return SecurityUtils.ALLOWED_EXTENSIONS.has(ext);
  }

  /**
   * 解码HTML实体
   * @param text 包含HTML实体的文本
   * @returns 解码后的文本
   */
  static decodeHtmlEntities(text: string): string {
    if (!text) return '';
    
    const entities: Record<string, string> = {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&#x2f;': '/',
      '&#x2F;': '/',
      '&#47;': '/',
      '&apos;': "'",
    };
    
    let decoded = text;
    const entries: [string, string][] = Object.entries(entities);
    for (let i: number = 0; i < entries.length; i++) {
      const entry: [string, string] = entries[i];
      decoded = decoded.replace(new RegExp(entry[0], 'g'), entry[1]);
    }
    
    // 处理数字实体
    decoded = decoded.replace(/&#(\d+);/g, (match: string, code: string): string => {
      const num = parseInt(code, 10);
      return num >= 32 && num <= 126 ? String.fromCharCode(num) : match;
    });

    // 处理十六进制实体
    decoded = decoded.replace(/&#x([0-9a-fA-F]+);/g, (match: string, hex: string): string => {
      const num = parseInt(hex, 16);
      return num >= 32 && num <= 126 ? String.fromCharCode(num) : match;
    });
    
    return decoded;
  }

  /**
   * 转义正则表达式特殊字符
   * @param string 要转义的字符串
   * @returns 转义后的字符串
   */
  static escapeRegex(string: string): string {
    if (!string) return '';
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  /**
   * 安全地获取文件扩展名
   * @param fileName 文件名
   * @returns 扩展名（小写，包含点）
   */
  static getFileExtension(fileName: string): string {
    if (!fileName) return '';
    
    // 先清理文件名
    const sanitized = SecurityUtils.sanitizeFileName(fileName);
    
    const lastDot = sanitized.lastIndexOf('.');
    if (lastDot < 0 || lastDot === 0) return '';
    
    return sanitized.substring(lastDot).toLowerCase();
  }

  /**
   * 生成安全的路径
   * @param basePath 基础路径
   * @param fileName 文件名
   * @returns 完整的安全路径
   */
  static buildSafePath(basePath: string, fileName: string): string {
    if (!basePath) return '';
    
    const sanitizedName = SecurityUtils.sanitizeFileName(fileName);
    if (!sanitizedName) return '';
    
    const normalizedBase = SecurityUtils.normalizePath(basePath);
    const separator = normalizedBase.endsWith('/') ? '' : '/';
    
    return `${normalizedBase}${separator}${sanitizedName}`;
  }
}

export default SecurityUtils;
