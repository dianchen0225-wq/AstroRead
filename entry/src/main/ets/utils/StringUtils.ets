/**
 * 字符串工具类
 * 提供字符串处理的通用函数
 */

export class StringUtils {
  /**
   * 检查字符串是否为空或空白
   */
  static isEmpty(str: string | null | undefined): boolean {
    return !str || str.trim().length === 0;
  }

  /**
   * 检查字符串是否不为空
   */
  static isNotEmpty(str: string | null | undefined): boolean {
    return !StringUtils.isEmpty(str);
  }

  static defaultIfEmpty(str: string | null | undefined, defaultValue: string): string {
    return StringUtils.isEmpty(str) ? defaultValue : str!;
  }

  /**
   * 截断字符串到指定长度
   */
  static truncate(str: string, maxLength: number, suffix: string = '...'): string {
    if (!str || str.length <= maxLength) {
      return str || '';
    }
    return str.substring(0, maxLength - suffix.length) + suffix;
  }

  /**
   * 去除字符串首尾空白并清理多余空格
   */
  static normalizeWhitespace(str: string): string {
    if (!str) return '';
    return str.replace(/\s+/g, ' ').trim();
  }

  /**
   * 将字符串转换为驼峰命名
   */
  static toCamelCase(str: string): string {
    if (!str) return '';
    return str
      .replace(/[-_\s]+(.)?/g, (_match: string, char: string): string => char ? char.toUpperCase() : '')
      .replace(/^[A-Z]/, (char: string): string => char.toLowerCase());
  }

  /**
   * 将字符串转换为帕斯卡命名
   */
  static toPascalCase(str: string): string {
    if (!str) return '';
    const camelCase = StringUtils.toCamelCase(str);
    return camelCase.charAt(0).toUpperCase() + camelCase.slice(1);
  }

  /**
   * 将字符串转换为下划线命名
   */
  static toSnakeCase(str: string): string {
    if (!str) return '';
    return str
      .replace(/([a-z])([A-Z])/g, '$1_$2')
      .replace(/[-\s]+/g, '_')
      .toLowerCase();
  }

  /**
   * 将字符串转换为短横线命名
   */
  static toKebabCase(str: string): string {
    if (!str) return '';
    return str
      .replace(/([a-z])([A-Z])/g, '$1-$2')
      .replace(/[_\s]+/g, '-')
      .toLowerCase();
  }

  /**
   * 生成指定长度的随机字符串
   */
  static randomString(length: number): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }

  /**
   * 生成UUID v4
   */
  static generateUUID(): string {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (char) => {
      const random = Math.random() * 16 | 0;
      const value = char === 'x' ? random : (random & 0x3 | 0x8);
      return value.toString(16);
    });
  }

  /**
   * 计算字符串的相似度（Levenshtein距离）
   * 返回0-1之间的值，1表示完全相同
   */
  static similarity(str1: string, str2: string): number {
    if (str1 === str2) return 1;
    if (!str1 || !str2) return 0;

    const len1 = str1.length;
    const len2 = str2.length;
    const matrix: number[][] = [];

    for (let i = 0; i <= len1; i++) {
      matrix[i] = [i];
    }
    for (let j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (let i = 1; i <= len1; i++) {
      for (let j = 1; j <= len2; j++) {
        const cost = str1[i - 1] === str2[j - 1] ? 0 : 1;
        matrix[i][j] = Math.min(
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost
        );
      }
    }

    const maxLen = Math.max(len1, len2);
    return 1 - matrix[len1][len2] / maxLen;
  }

  /**
   * 检查字符串是否包含中文字符
   */
  static containsChinese(str: string): boolean {
    if (!str) return false;
    return /[\u4e00-\u9fa5]/.test(str);
  }

  /**
   * 获取字符串字节长度（支持中文）
   */
  static byteLength(str: string): number {
    if (!str) return 0;
    let length = 0;
    for (let i = 0; i < str.length; i++) {
      const charCode = str.charCodeAt(i);
      length += charCode > 255 ? 2 : 1;
    }
    return length;
  }

  /**
   * 格式化数字为带单位的字符串
   */
  static formatNumber(num: number): string {
    if (num >= 100000000) {
      return (num / 100000000).toFixed(1) + '亿';
    }
    if (num >= 10000) {
      return (num / 10000).toFixed(1) + '万';
    }
    return num.toString();
  }

  /**
   * 格式化文件大小
   */
  static formatFileSize(bytes: number): string {
    if (bytes === 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    const k = 1024;
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + units[i];
  }

  /**
   * 格式化时间戳为相对时间
   */
  static formatRelativeTime(timestamp: number): string {
    const now = Date.now();
    const diff = now - timestamp;
    const minute = 60 * 1000;
    const hour = 60 * minute;
    const day = 24 * hour;
    const week = 7 * day;
    const month = 30 * day;
    const year = 365 * day;

    if (diff < minute) {
      return '刚刚';
    } else if (diff < hour) {
      return Math.floor(diff / minute) + '分钟前';
    } else if (diff < day) {
      return Math.floor(diff / hour) + '小时前';
    } else if (diff < week) {
      return Math.floor(diff / day) + '天前';
    } else if (diff < month) {
      return Math.floor(diff / week) + '周前';
    } else if (diff < year) {
      return Math.floor(diff / month) + '个月前';
    } else {
      return Math.floor(diff / year) + '年前';
    }
  }

  /**
   * 安全的JSON解析
   */
  static safeJsonParse<T>(json: string, defaultValue: T): T {
    try {
      return JSON.parse(json) as T;
    } catch {
      return defaultValue;
    }
  }

  /**
   * 安全的JSON字符串化
   */
  static safeJsonStringify(obj: Object | null | undefined, defaultValue: string = '{}'): string {
    try {
      return JSON.stringify(obj);
    } catch {
      return defaultValue;
    }
  }

  /**
   * 转义HTML特殊字符
   */
  static escapeHtml(str: string): string {
    if (!str) return '';
    const htmlEscapes: Record<string, string> = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;'
    };
    return str.replace(/[&<>"']/g, char => htmlEscapes[char] || char);
  }

  /**
   * 反转义HTML特殊字符
   */
  static unescapeHtml(str: string): string {
    if (!str) return '';
    const htmlUnescapes: Record<string, string> = {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'"
    };
    return str.replace(/&(?:amp|lt|gt|quot|#39);/g, entity => htmlUnescapes[entity] || entity);
  }

  /**
   * 移除字符串中的所有HTML标签
   */
  static stripHtmlTags(str: string): string {
    if (!str) return '';
    return str.replace(/<[^>]*>/g, '');
  }

  /**
   * 将字符串按行分割
   */
  static splitLines(str: string): string[] {
    if (!str) return [];
    return str.split(/\r\n|\r|\n/);
  }

  /**
   * 首字母大写
   */
  static capitalize(str: string): string {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1);
  }

  /**
   * 反转字符串
   */
  static reverse(str: string): string {
    if (!str) return '';
    return str.split('').reverse().join('');
  }

  /**
   * 计算字符串中某个子串出现的次数
   */
  static countOccurrences(str: string, substring: string): number {
    if (!str || !substring) return 0;
    let count = 0;
    let pos = str.indexOf(substring);
    while (pos !== -1) {
      count++;
      pos = str.indexOf(substring, pos + 1);
    }
    return count;
  }
}
