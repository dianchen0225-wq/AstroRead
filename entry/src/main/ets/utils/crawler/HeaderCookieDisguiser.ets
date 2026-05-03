import { IHeaderCookieDisguiser, DisguisedRequest } from "./interfaces/IAntiCrawl";
import { UserAgentPool } from "../../network/UserAgentPool";
import { CookieManager } from "../../network/CookieManager";
import { Logger } from "../performance/Logger";
export class HeaderCookieDisguiser implements IHeaderCookieDisguiser {
  private static readonly TAG = 'HeaderCookieDisguiser';

  private static readonly STANDARD_HEADERS: Map<string, string> = new Map([
    ['Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'],
    ['Accept-Language', 'zh-CN,zh;q=0.9,en;q=0.8'],
    ['Accept-Encoding', 'gzip, deflate, br'],
    ['Connection', 'keep-alive'],
    ['Upgrade-Insecure-Requests', '1'],
    ['Cache-Control', 'max-age=0'],
  ]);

  private userAgentPool: UserAgentPool;
  private cookieManager: CookieManager;

  constructor() {
    this.userAgentPool = UserAgentPool.getInstance();
    this.cookieManager = CookieManager.getInstance();
  }

  disguise(url: string, existingHeaders?: Map<string, string>): DisguisedRequest {
    const headers = new Map<string, string>();

    HeaderCookieDisguiser.STANDARD_HEADERS.forEach((value: string, key: string) => {
      headers.set(key, value);
    });

    const ua = this.userAgentPool.getRandomUserAgent();
    headers.set('User-Agent', ua);

    try {
      const urlObj = new URL(url);
      headers.set('Host', urlObj.hostname);
      headers.set('Referer', `${urlObj.protocol}//${urlObj.hostname}/`);
    } catch (_) {
      headers.set('Referer', url);
    }

    if (existingHeaders) {
      existingHeaders.forEach((value: string, key: string) => {
        headers.set(key, value);
      });
    }

    const shuffledHeaders = this.shuffleHeaders(headers);
    const cookie = this.getCookieForUrl(url);

    const result: DisguisedRequest = {
      url: url,
      headers: shuffledHeaders,
      cookie: cookie,
      proxyHost: '',
      proxyPort: 0,
    };
    return result;
  }

  updateCookies(url: string, setCookieHeader: string): void {
    if (!setCookieHeader) {
      return;
    }
    this.cookieManager.saveCookie(url, setCookieHeader);
    Logger.debug(HeaderCookieDisguiser.TAG, `Cookies updated for ${url}`);
  }

  clearDomainCookies(domain: string): void {
    const url = `https://${domain}`;
    this.cookieManager.removeCookie(url);
    Logger.debug(HeaderCookieDisguiser.TAG, `Cookies cleared for ${domain}`);
  }

  getDomainCookies(domain: string): string {
    const url = `https://${domain}`;
    const cookie = this.cookieManager.getCookieForUrl(url);
    return cookie ?? '';
  }

  private getCookieForUrl(url: string): string {
    const cookie = this.cookieManager.getCookieForUrl(url);
    return cookie ?? '';
  }

  private shuffleHeaders(headers: Map<string, string>): Map<string, string> {
    const entries = Array.from(headers.entries());

    for (let i = entries.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const temp = entries[i];
      entries[i] = entries[j];
      entries[j] = temp;
    }

    return new Map(entries);
  }
}
