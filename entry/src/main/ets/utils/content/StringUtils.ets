export class StringUtils {
  private static readonly TAG = 'StringUtils';

  static escapeRegex(str: string): string {
    if (!str) return '';
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  static isEmpty(str: string | null | undefined): boolean {
    return str === null || str === undefined || str.trim().length === 0;
  }

  static isNotEmpty(str: string | null | undefined): boolean {
    return !StringUtils.isEmpty(str);
  }

  static truncate(str: string, maxLength: number, suffix: string = '...'): string {
    if (!str || str.length <= maxLength) {
      return str || '';
    }
    return str.substring(0, maxLength - suffix.length) + suffix;
  }

  static sanitize(str: string): string {
    if (!str) return '';
    return str
      .replace(/[\x00-\x1F\x7F]/g, '')
      .replace(/[\r\n]/g, ' ')
      .trim();
  }

  static hashCode(str: string): number {
    if (!str) return 0;
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return hash;
  }

  static formatBytes(bytes: number, decimals: number = 2): string {
    if (!Number.isFinite(bytes) || bytes < 0) return '0 B';
    if (bytes === 0) return '0 B';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    const safeIndex = Math.min(i, sizes.length - 1);
    return parseFloat((bytes / Math.pow(k, safeIndex)).toFixed(dm)) + ' ' + sizes[safeIndex];
  }

  static capitalize(str: string): string {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
  }

  static removeHtmlTags(str: string): string {
    if (!str) return '';
    return str.replace(/<[^>]*>/g, '');
  }

  static normalizeWhitespace(str: string): string {
    if (!str) return '';
    return str.replace(/\s+/g, ' ').trim();
  }

  static isValidUrl(url: string): boolean {
    if (!url || typeof url !== 'string') return false;
    try {
      return url.startsWith('http://') || url.startsWith('https://');
    } catch {
      return false;
    }
  }

  static resolveUrl(baseUrl: string, relativeUrl: string): string {
    if (!relativeUrl) return '';
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }
    if (relativeUrl.startsWith('//')) {
      const protocol = baseUrl.startsWith('https') ? 'https:' : 'http:';
      return protocol + relativeUrl;
    }
    if (!baseUrl) return relativeUrl;

    try {
      const protocolEnd = baseUrl.indexOf('://');
      if (protocolEnd === -1) return relativeUrl;

      const protocol = baseUrl.substring(0, protocolEnd + 3);
      const hostStart = protocolEnd + 3;
      const pathStart = baseUrl.indexOf('/', hostStart);
      const host = pathStart === -1 ? baseUrl.substring(hostStart) : baseUrl.substring(hostStart, pathStart);

      if (relativeUrl.startsWith('/')) {
        return `${protocol}${host}${relativeUrl}`;
      }

      const path = pathStart === -1 ? '/' : baseUrl.substring(pathStart);
      const lastSlash = path.lastIndexOf('/');
      const basePath = lastSlash === -1 ? '/' : path.substring(0, lastSlash + 1);

      return `${protocol}${host}${basePath}${relativeUrl}`;
    } catch {
      return relativeUrl;
    }
  }
}

export default StringUtils;
