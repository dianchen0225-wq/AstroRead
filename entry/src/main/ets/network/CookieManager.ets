/**
 * CookieManager - Cookie管理器
 * 负责Cookie的存储、获取和管理
 */

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
}

export class CookieManager {
  private cookieStore: Map<string, CookieData[]> = new Map();
  private readonly MAX_COOKIES_PER_DOMAIN: number = 50;

  getCookieForUrl(url: string): string | undefined {
    const domain = this.extractDomain(url);
    const path = this.extractPath(url);
    const cookies = this.cookieStore.get(domain);
    
    if (!cookies || cookies.length === 0) {
      return undefined;
    }

    const now = Date.now();
    const validCookies = cookies.filter((cookie: CookieData) => {
      if (cookie.expires && cookie.expires < now) {
        return false;
      }
      if (cookie.path && !path.startsWith(cookie.path)) {
        return false;
      }
      return true;
    });

    if (validCookies.length === 0) {
      return undefined;
    }

    return validCookies
      .map((cookie: CookieData) => `${cookie.name}=${cookie.value}`)
      .join('; ');
  }

  saveCookie(url: string, cookieString: string): void {
    const domain = this.extractDomain(url);
    const cookies = this.parseSetCookie(cookieString, domain);
    
    if (cookies.length === 0) {
      return;
    }

    let existingCookies = this.cookieStore.get(domain) || [];
    
    for (const newCookie of cookies) {
      const existingIndex = existingCookies.findIndex(
        (c: CookieData) => c.name === newCookie.name && c.path === newCookie.path
      );
      
      if (existingIndex >= 0) {
        existingCookies[existingIndex] = newCookie;
      } else {
        if (existingCookies.length >= this.MAX_COOKIES_PER_DOMAIN) {
          existingCookies = existingCookies.slice(-this.MAX_COOKIES_PER_DOMAIN + 1);
        }
        existingCookies.push(newCookie);
      }
    }

    this.cookieStore.set(domain, existingCookies);
  }

  private parseSetCookie(cookieString: string, defaultDomain: string): CookieData[] {
    const cookies: CookieData[] = [];
    
    const cookieParts = cookieString.split(/,(?=\s*[a-zA-Z0-9_-]+=)/);
    
    for (const part of cookieParts) {
      const cookie = this.parseSingleCookie(part.trim(), defaultDomain);
      if (cookie) {
        cookies.push(cookie);
      }
    }

    return cookies;
  }

  private parseSingleCookie(cookieStr: string, defaultDomain: string): CookieData | null {
    const parts = cookieStr.split(';').map((s: string) => s.trim());
    
    if (parts.length === 0) {
      return null;
    }

    const nameValue = parts[0].split('=');
    if (nameValue.length < 2) {
      return null;
    }

    const cookie: CookieData = {
      name: nameValue[0].trim(),
      value: nameValue.slice(1).join('=').trim(),
      domain: defaultDomain,
      path: '/',
      secure: false,
      httpOnly: false
    };

    for (let i = 1; i < parts.length; i++) {
      const attr = parts[i].toLowerCase();
      const eqIndex = attr.indexOf('=');
      
      if (eqIndex > 0) {
        const attrName = attr.substring(0, eqIndex).trim();
        const attrValue = attr.substring(eqIndex + 1).trim();
        
        switch (attrName) {
          case 'domain':
            cookie.domain = attrValue.startsWith('.') ? attrValue.substring(1) : attrValue;
            break;
          case 'path':
            cookie.path = attrValue;
            break;
          case 'expires':
            const expiresDate = Date.parse(attrValue);
            if (!isNaN(expiresDate)) {
              cookie.expires = expiresDate;
            }
            break;
          case 'max-age':
            const maxAge = parseInt(attrValue, 10);
            if (!isNaN(maxAge)) {
              cookie.maxAge = maxAge;
              cookie.expires = Date.now() + maxAge * 1000;
            }
            break;
          case 'samesite':
            if (attrValue === 'strict' || attrValue === 'lax' || attrValue === 'none') {
              cookie.sameSite = attrValue;
            }
            break;
        }
      } else {
        if (attr === 'secure') {
          cookie.secure = true;
        } else if (attr === 'httponly') {
          cookie.httpOnly = true;
        }
      }
    }

    return cookie;
  }

  removeCookie(url: string, name?: string): boolean {
    const domain = this.extractDomain(url);
    const cookies = this.cookieStore.get(domain);
    
    if (!cookies) {
      return false;
    }

    if (name) {
      const initialLength = cookies.length;
      const filtered = cookies.filter((c: CookieData) => c.name !== name);
      if (filtered.length === 0) {
        this.cookieStore.delete(domain);
      } else {
        this.cookieStore.set(domain, filtered);
      }
      return filtered.length !== initialLength;
    } else {
      this.cookieStore.delete(domain);
      return true;
    }
  }

  getAllCookies(): Map<string, string> {
    const result = new Map<string, string>();
    
    this.cookieStore.forEach((cookies: CookieData[], domain: string) => {
      const cookieString = cookies
        .map((c: CookieData) => `${c.name}=${c.value}`)
        .join('; ');
      result.set(domain, cookieString);
    });

    return result;
  }

  clear(): void {
    this.cookieStore.clear();
  }

  cleanup(): void {
    const now = Date.now();
    
    this.cookieStore.forEach((cookies: CookieData[], domain: string) => {
      const validCookies = cookies.filter((c: CookieData) => {
        return !c.expires || c.expires > now;
      });
      
      if (validCookies.length === 0) {
        this.cookieStore.delete(domain);
      } else if (validCookies.length !== cookies.length) {
        this.cookieStore.set(domain, validCookies);
      }
    });
  }

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

      return urlString || 'localhost';
    } catch {
      return 'localhost';
    }
  }

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
}

export default CookieManager;
