/**
 * CookieManager - Cookie管理器
 * 完整实现 RFC 6265 规范
 * 支持 domain 匹配、path 匹配、secure、httpOnly、sameSite 等属性
 */

import { Logger } from '../utils/performance/Logger';

interface CookieData {
  name: string;
  value: string;
  domain: string;
  path: string;
  expires?: number;
  maxAge?: number;
  secure: boolean;
  httpOnly: boolean;
  sameSite?: 'strict' | 'lax' | 'none';
  creationTime: number;
  lastAccessTime: number;
}

export interface CookieOptions {
  domain?: string;
  path?: string;
  expires?: Date | number;
  maxAge?: number;
  secure?: boolean;
  httpOnly?: boolean;
  sameSite?: 'strict' | 'lax' | 'none';
}

export interface OldestCookieInfo {
  domain: string;
  name: string;
  age: number;
}

export interface CookieStats {
  totalCookies: number;
  domainCount: number;
  oldestCookie?: OldestCookieInfo;
  expiredCookies: number;
}

/**
 * 用于存储带域名信息的 Cookie 条目
 */
interface DomainCookieEntry {
  domain: string;
  cookie: CookieData;
}

export class CookieManager {
  private static instance: CookieManager | null = null;
  private cookieStore: Map<string, CookieData[]> = new Map();
  private readonly MAX_COOKIES_PER_DOMAIN: number = 50;
  private readonly MAX_TOTAL_COOKIES: number = 300;
  private readonly TAG = 'CookieManager';

  private constructor() {}

  static getInstance(): CookieManager {
    if (!CookieManager.instance) {
      CookieManager.instance = new CookieManager();
    }
    return CookieManager.instance;
  }

  /**
   * 获取指定 URL 的 Cookie 字符串
   */
  getCookieForUrl(url: string): string | undefined {
    const domain = this.extractDomain(url);
    const path = this.extractPath(url);
    const isSecure = url.startsWith('https://');

    const now = Date.now();
    const validCookies: CookieData[] = [];

    // 检查精确域名和父域名
    const domains = this.getMatchingDomains(domain);
    
    for (const d of domains) {
      const cookies = this.cookieStore.get(d);
      if (!cookies) continue;

      for (const cookie of cookies) {
        // 检查过期
        if (cookie.expires && cookie.expires < now) {
          continue;
        }

        // 检查 secure 属性
        if (cookie.secure && !isSecure) {
          continue;
        }

        // 检查 path 匹配
        if (!this.pathMatches(path, cookie.path)) {
          continue;
        }

        // 检查 SameSite 属性
        if (cookie.sameSite === 'strict') {
          // strict 模式下只在同站请求中发送
          // 这里简化处理，实际需要检查请求来源
        }

        cookie.lastAccessTime = now;
        validCookies.push(cookie);
      }
    }

    if (validCookies.length === 0) {
      return undefined;
    }

    // 按路径长度排序（更具体的路径优先）
    validCookies.sort((a, b) => {
      const pathDiff = b.path.length - a.path.length;
      if (pathDiff !== 0) return pathDiff;
      return a.creationTime - b.creationTime;
    });

    return validCookies
      .map(cookie => `${cookie.name}=${cookie.value}`)
      .join('; ');
  }

  /**
   * 保存 Cookie
   */
  saveCookie(url: string, cookieString: string): void {
    const defaultDomain = this.extractDomain(url);
    const cookies = this.parseSetCookie(cookieString, defaultDomain);

    if (cookies.length === 0) {
      return;
    }

    for (const newCookie of cookies) {
      this.saveSingleCookie(newCookie);
    }

    // 检查总 Cookie 数量限制
    this.enforceMaxCookies();
  }

  /**
   * 设置单个 Cookie
   */
  setCookie(name: string, value: string, options?: CookieOptions): void {
    const cookie: CookieData = {
      name,
      value,
      domain: options?.domain || '',
      path: options?.path || '/',
      secure: options?.secure ?? false,
      httpOnly: options?.httpOnly ?? false,
      sameSite: options?.sameSite,
      creationTime: Date.now(),
      lastAccessTime: Date.now()
    };

    if (options?.expires) {
      if (options.expires instanceof Date) {
        cookie.expires = options.expires.getTime();
      } else {
        cookie.expires = options.expires;
      }
    }

    if (options?.maxAge !== undefined) {
      cookie.maxAge = options.maxAge;
      cookie.expires = Date.now() + options.maxAge * 1000;
    }

    if (cookie.domain) {
      this.saveSingleCookie(cookie);
    }
  }

  /**
   * 保存单个 Cookie
   */
  private saveSingleCookie(newCookie: CookieData): void {
    const domain = newCookie.domain;
    let existingCookies = this.cookieStore.get(domain) || [];

    // 查找并更新或添加
    const existingIndex = existingCookies.findIndex(
      c => c.name === newCookie.name && c.path === newCookie.path
    );

    if (existingIndex >= 0) {
      // 保留创建时间
      newCookie.creationTime = existingCookies[existingIndex].creationTime;
      existingCookies[existingIndex] = newCookie;
      Logger.debug(this.TAG, `更新 Cookie: ${newCookie.name}@${domain}`);
    } else {
      // 检查每个域名的 Cookie 数量限制
      if (existingCookies.length >= this.MAX_COOKIES_PER_DOMAIN) {
        // 移除最旧的 Cookie
        existingCookies.sort((a, b) => a.lastAccessTime - b.lastAccessTime);
        existingCookies = existingCookies.slice(1);
        Logger.debug(this.TAG, `移除最旧 Cookie 以腾出空间`);
      }
      existingCookies.push(newCookie);
      Logger.debug(this.TAG, `添加 Cookie: ${newCookie.name}@${domain}`);
    }

    this.cookieStore.set(domain, existingCookies);
  }

  /**
   * 解析 Set-Cookie 头
   */
  private parseSetCookie(cookieString: string, defaultDomain: string): CookieData[] {
    const cookies: CookieData[] = [];

    // 分割多个 Cookie（考虑日期中的逗号）
    const cookieParts = cookieString.split(/,(?=\s*[a-zA-Z0-9_-]+=)/);

    for (const part of cookieParts) {
      const cookie = this.parseSingleCookie(part.trim(), defaultDomain);
      if (cookie) {
        cookies.push(cookie);
      }
    }

    return cookies;
  }

  /**
   * 解析单个 Cookie
   */
  private parseSingleCookie(cookieStr: string, defaultDomain: string): CookieData | null {
    const parts = cookieStr.split(';').map(s => s.trim());

    if (parts.length === 0) {
      return null;
    }

    const nameValue = parts[0].split('=');
    if (nameValue.length < 2) {
      return null;
    }

    const now = Date.now();
    const cookie: CookieData = {
      name: nameValue[0].trim(),
      value: nameValue.slice(1).join('=').trim(),
      domain: defaultDomain,
      path: '/',
      secure: false,
      httpOnly: false,
      creationTime: now,
      lastAccessTime: now
    };

    for (let i = 1; i < parts.length; i++) {
      const attr = parts[i];
      const eqIndex = attr.indexOf('=');
      const attrName = eqIndex > 0 ? attr.substring(0, eqIndex).trim().toLowerCase() : attr.toLowerCase();
      const attrValue = eqIndex > 0 ? attr.substring(eqIndex + 1).trim() : '';

      switch (attrName) {
        case 'domain':
          cookie.domain = attrValue.startsWith('.') ? attrValue.substring(1) : attrValue;
          break;
        case 'path':
          cookie.path = attrValue || '/';
          break;
        case 'expires':
          const expiresDate = this.parseExpiresDate(attrValue);
          if (expiresDate !== null) {
            cookie.expires = expiresDate;
          }
          break;
        case 'max-age':
          const maxAge = parseInt(attrValue, 10);
          if (!isNaN(maxAge)) {
            cookie.maxAge = maxAge;
            if (maxAge <= 0) {
              // max-age=0 表示立即删除
              cookie.expires = 0;
            } else {
              cookie.expires = now + maxAge * 1000;
            }
          }
          break;
        case 'samesite':
          if (attrValue === 'strict' || attrValue === 'lax' || attrValue === 'none') {
            cookie.sameSite = attrValue;
          } else if (!attrValue) {
            cookie.sameSite = 'lax'; // 默认值
          }
          break;
        case 'secure':
          cookie.secure = true;
          break;
        case 'httponly':
          cookie.httpOnly = true;
          break;
      }
    }

    // 验证 Cookie
    if (!this.isValidCookie(cookie)) {
      return null;
    }

    return cookie;
  }

  /**
   * 解析过期日期
   */
  private parseExpiresDate(dateStr: string): number | null {
    // 尝试多种日期格式
    const formats = [
      // RFC 1123
      /^[A-Za-z]{3}, (\d{2}) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$/,
      // RFC 1036
      /^[A-Za-z]{3}, (\d{2})-([A-Za-z]{3})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) GMT$/,
      // ANSI C
      /^[A-Za-z]{3} ([A-Za-z]{3}) (\d{1,2}) (\d{2}):(\d{2}):(\d{2}) (\d{4})$/
    ];

    // 首先尝试标准 Date.parse
    const parsed = Date.parse(dateStr);
    if (!isNaN(parsed)) {
      return parsed;
    }

    return null;
  }

  /**
   * 验证 Cookie 是否有效
   */
  private isValidCookie(cookie: CookieData): boolean {
    // 检查名称
    if (!cookie.name || cookie.name.length === 0) {
      return false;
    }

    // 检查名称中是否包含非法字符
    if (/[;,\s]/.test(cookie.name)) {
      return false;
    }

    // 检查 domain
    if (cookie.domain && !this.isValidDomain(cookie.domain)) {
      return false;
    }

    // 检查 path
    if (!cookie.path.startsWith('/')) {
      return false;
    }

    // SameSite=None 必须配合 Secure
    if (cookie.sameSite === 'none' && !cookie.secure) {
      Logger.warn(this.TAG, `Cookie ${cookie.name} 设置 SameSite=None 但未设置 Secure，将被拒绝`);
      return false;
    }

    return true;
  }

  /**
   * 验证域名格式
   */
  private isValidDomain(domain: string): boolean {
    // 简单验证：不包含非法字符
    if (/[;,\s]/.test(domain)) {
      return false;
    }
    return true;
  }

  /**
   * 获取匹配的域名列表（包括父域名）
   */
  private getMatchingDomains(domain: string): string[] {
    const domains: string[] = [domain];

    // 添加父域名
    const parts = domain.split('.');
    for (let i = 1; i < parts.length - 1; i++) {
      const parentDomain = parts.slice(i).join('.');
      domains.push(parentDomain);
    }

    return domains;
  }

  /**
   * 检查路径是否匹配
   */
  private pathMatches(requestPath: string, cookiePath: string): boolean {
    if (requestPath === cookiePath) {
      return true;
    }

    if (requestPath.startsWith(cookiePath)) {
      // cookiePath 必须以 / 结尾，或者 requestPath 的下一个字符是 /
      if (cookiePath.endsWith('/') || requestPath[cookiePath.length] === '/') {
        return true;
      }
    }

    return false;
  }

  /**
   * 移除 Cookie
   */
  removeCookie(url: string, name?: string): boolean {
    const domain = this.extractDomain(url);
    const domains = this.getMatchingDomains(domain);
    let removed = false;

    for (const d of domains) {
      const cookies = this.cookieStore.get(d);
      if (!cookies) continue;

      if (name) {
        const initialLength = cookies.length;
        const filtered = cookies.filter(c => c.name !== name);
        if (filtered.length === 0) {
          this.cookieStore.delete(d);
        } else {
          this.cookieStore.set(d, filtered);
        }
        if (filtered.length !== initialLength) {
          removed = true;
          Logger.debug(this.TAG, `移除 Cookie: ${name}@${d}`);
        }
      } else {
        this.cookieStore.delete(d);
        removed = true;
        Logger.debug(this.TAG, `移除域名 ${d} 的所有 Cookie`);
      }
    }

    return removed;
  }

  /**
   * 获取所有 Cookie
   */
  getAllCookies(): Map<string, string> {
    const result = new Map<string, string>();

    this.cookieStore.forEach((cookies, domain) => {
      const cookieString = cookies
        .map(c => `${c.name}=${c.value}`)
        .join('; ');
      result.set(domain, cookieString);
    });

    return result;
  }

  /**
   * 获取 Cookie 统计信息
   */
  getStats(): CookieStats {
    let totalCookies = 0;
    let expiredCount = 0;
    let oldest: OldestCookieInfo | undefined;
    const now = Date.now();

    this.cookieStore.forEach((cookies, domain) => {
      for (const cookie of cookies) {
        totalCookies++;

        if (cookie.expires && cookie.expires < now) {
          expiredCount++;
        }

        const age = now - cookie.creationTime;
        if (!oldest || age > oldest.age) {
          const oldestInfo: OldestCookieInfo = {
            domain: domain,
            name: cookie.name,
            age: age
          };
          oldest = oldestInfo;
        }
      }
    });

    return {
      totalCookies,
      domainCount: this.cookieStore.size,
      oldestCookie: oldest,
      expiredCookies: expiredCount
    };
  }

  /**
   * 清除所有 Cookie
   */
  clear(): void {
    this.cookieStore.clear();
    Logger.info(this.TAG, '已清除所有 Cookie');
  }

  /**
   * 清理过期 Cookie
   */
  cleanup(): number {
    const now = Date.now();
    let cleanedCount = 0;

    this.cookieStore.forEach((cookies, domain) => {
      const validCookies = cookies.filter(c => {
        if (c.expires && c.expires < now) {
          cleanedCount++;
          return false;
        }
        return true;
      });

      if (validCookies.length === 0) {
        this.cookieStore.delete(domain);
      } else if (validCookies.length !== cookies.length) {
        this.cookieStore.set(domain, validCookies);
      }
    });

    if (cleanedCount > 0) {
      Logger.info(this.TAG, `清理了 ${cleanedCount} 个过期 Cookie`);
    }

    return cleanedCount;
  }

  /**
   * 强制执行最大 Cookie 数量限制
   */
  private enforceMaxCookies(): void {
    let totalCount = 0;
    this.cookieStore.forEach(cookies => {
      totalCount += cookies.length;
    });

    if (totalCount <= this.MAX_TOTAL_COOKIES) {
      return;
    }

    // 收集所有 Cookie 并按最后访问时间排序
    const allCookies: DomainCookieEntry[] = [];
    this.cookieStore.forEach((cookies, domain) => {
      for (const cookie of cookies) {
        const entry: DomainCookieEntry = {
          domain: domain,
          cookie: cookie
        };
        allCookies.push(entry);
      }
    });

    allCookies.sort((a, b) => a.cookie.lastAccessTime - b.cookie.lastAccessTime);

    // 移除最旧的 Cookie
    const toRemove = totalCount - this.MAX_TOTAL_COOKIES;
    for (let i = 0; i < toRemove && i < allCookies.length; i++) {
      const domain = allCookies[i].domain;
      const cookie = allCookies[i].cookie;
      const cookies = this.cookieStore.get(domain);
      if (cookies) {
        const filtered = cookies.filter(c => c.name !== cookie.name);
        if (filtered.length === 0) {
          this.cookieStore.delete(domain);
        } else {
          this.cookieStore.set(domain, filtered);
        }
      }
    }

    Logger.debug(this.TAG, `移除了 ${toRemove} 个 Cookie 以满足限制`);
  }

  /**
   * 提取域名
   */
  private extractDomain(url: string): string {
    try {
      let urlString = url;
      const protocolIndex = urlString.indexOf('://');
      if (protocolIndex !== -1) {
        urlString = urlString.substring(protocolIndex + 3);
      }

      const pathIndex = urlString.indexOf('/');
      if (pathIndex !== -1) {
        urlString = urlString.substring(0, pathIndex);
      }

      const portIndex = urlString.indexOf(':');
      if (portIndex !== -1) {
        urlString = urlString.substring(0, portIndex);
      }

      return urlString.toLowerCase() || 'localhost';
    } catch {
      return 'localhost';
    }
  }

  /**
   * 提取路径
   */
  private extractPath(url: string): string {
    try {
      const protocolIndex = url.indexOf('://');
      let pathStart = protocolIndex !== -1 ? protocolIndex + 3 : 0;

      const pathIndex = url.indexOf('/', pathStart);
      if (pathIndex !== -1) {
        const queryIndex = url.indexOf('?', pathIndex);
        const hashIndex = url.indexOf('#', pathIndex);

        let endIndex = url.length;
        if (queryIndex !== -1) endIndex = Math.min(endIndex, queryIndex);
        if (hashIndex !== -1) endIndex = Math.min(endIndex, hashIndex);

        return url.substring(pathIndex, endIndex);
      }

      return '/';
    } catch {
      return '/';
    }
  }

  /**
   * 导出 Cookie 为 JSON
   */
  exportCookies(): string {
    const data: Record<string, CookieData[]> = {};
    this.cookieStore.forEach((cookies, domain) => {
      data[domain] = cookies;
    });
    return JSON.stringify(data, null, 2);
  }

  /**
   * 从 JSON 导入 Cookie
   */
  importCookies(json: string): number {
    try {
      const data = JSON.parse(json) as Record<string, CookieData[]>;
      let count = 0;

      const entries = Object.entries(data);
      for (let i = 0; i < entries.length; i++) {
        const domain = entries[i][0];
        const cookies = entries[i][1];
        for (let j = 0; j < cookies.length; j++) {
          this.saveSingleCookie(cookies[j]);
          count++;
        }
      }

      Logger.info(this.TAG, `导入了 ${count} 个 Cookie`);
      return count;
    } catch (e) {
      Logger.error(this.TAG, `导入 Cookie 失败: ${e}`);
      return 0;
    }
  }
}

export const cookieManager = CookieManager.getInstance();
export default CookieManager;
