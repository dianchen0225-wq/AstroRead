/**
 * CookieManager - Cookie管理器
 * 负责Cookie的存储、获取和管理
 */

/**
 * Cookie管理器
 */
export class CookieManager {
  private cookieStore: Map<string, string> = new Map();

  /**
   * 根据URL获取Cookie
   */
  getCookieForUrl(url: string): string | undefined {
    const domain = this.extractDomain(url);
    return this.cookieStore.get(domain);
  }

  /**
   * 保存Cookie
   */
  saveCookie(url: string, cookie: string): void {
    const domain = this.extractDomain(url);
    this.cookieStore.set(domain, cookie);
  }

  /**
   * 移除指定域名的Cookie
   */
  removeCookie(url: string): boolean {
    const domain = this.extractDomain(url);
    return this.cookieStore.delete(domain);
  }

  /**
   * 获取所有Cookie
   */
  getAllCookies(): Map<string, string> {
    return new Map(this.cookieStore);
  }

  /**
   * 清空所有Cookie
   */
  clear(): void {
    this.cookieStore.clear();
  }

  /**
   * 提取域名
   */
  private extractDomain(url: string): string {
    try {
      // 手动解析URL提取域名
      // 格式: protocol://hostname:port/path
      let urlString = url;

      // 移除协议部分
      const protocolIndex = urlString.indexOf('://');
      if (protocolIndex !== -1) {
        urlString = urlString.substring(protocolIndex + 3);
      }

      // 移除路径部分
      const pathIndex = urlString.indexOf('/');
      if (pathIndex !== -1) {
        urlString = urlString.substring(0, pathIndex);
      }

      // 移除端口部分
      const portIndex = urlString.indexOf(':');
      if (portIndex !== -1) {
        urlString = urlString.substring(0, portIndex);
      }

      return urlString || 'localhost';
    } catch {
      return 'localhost';
    }
  }
}

export default CookieManager;
