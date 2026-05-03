import { Result, ErrorCode } from "../../core/Result";
import { IProxyRotator, ProxyEntry, ProxyStrategy } from "./interfaces/IAntiCrawl";
import { CrawlErrorCode, CrawlError } from "./models/CrawlError";
import { Logger } from "../performance/Logger";

export class ProxyRotator implements IProxyRotator {
  private static readonly TAG = 'ProxyRotator';
  private static readonly FAILURE_THRESHOLD = 3;
  private static readonly RECOVERY_MS = 5 * 60 * 1000;

  private proxies: ProxyEntry[] = [];
  private strategy: ProxyStrategy;
  private currentIndex: number = 0;
  private highAntiCrawlDomains: Set<string> = new Set();

  constructor(strategy: ProxyStrategy = ProxyStrategy.ROUND_ROBIN) {
    this.strategy = strategy;
  }

  getNext(): Result<ProxyEntry> {
    const available = this.getAvailableProxies();
    if (available.length === 0) {
      const errorMsg = CrawlError.create(CrawlErrorCode.PROXY_EXHAUSTED, '所有代理不可用').getLocalizedMessage();
      return Result.err(ErrorCode.NETWORK_ERROR, errorMsg);
    }

    let selected: ProxyEntry;
    switch (this.strategy) {
      case ProxyStrategy.ROUND_ROBIN:
        selected = this.roundRobin(available);
        break;
      case ProxyStrategy.RANDOM:
        selected = this.random(available);
        break;
      case ProxyStrategy.LEAST_FAILURES:
        selected = this.leastFailures(available);
        break;
      default:
        selected = this.roundRobin(available);
    }

    selected.lastUsed = Date.now();
    return Result.ok(selected);
  }

  reportSuccess(proxyId: string): void {
    const proxy = this.findProxy(proxyId);
    if (proxy) {
      proxy.successCount++;
      proxy.failCount = Math.max(0, proxy.failCount - 1);
      if (!proxy.available && proxy.failCount < ProxyRotator.FAILURE_THRESHOLD) {
        proxy.available = true;
        Logger.info(ProxyRotator.TAG, `Proxy ${proxyId} recovered`);
      }
    }
  }

  reportFailure(proxyId: string): void {
    const proxy = this.findProxy(proxyId);
    if (proxy) {
      proxy.failCount++;
      proxy.lastFailed = Date.now();

      if (proxy.failCount >= ProxyRotator.FAILURE_THRESHOLD) {
        proxy.available = false;
        Logger.warn(ProxyRotator.TAG, `Proxy ${proxyId} marked unavailable (${proxy.failCount} failures)`);
      }
    }
  }

  updateProxyList(proxies: ProxyEntry[]): void {
    this.proxies = [...proxies];
    this.currentIndex = 0;
    Logger.info(ProxyRotator.TAG, `Proxy list updated: ${proxies.length} proxies`);
  }

  removeProxy(proxyId: string): boolean {
    const idx = this.proxies.findIndex((p: ProxyEntry) => p.id === proxyId);
    if (idx >= 0) {
      this.proxies.splice(idx, 1);
      Logger.debug(ProxyRotator.TAG, `Proxy ${proxyId} removed`);
      return true;
    }
    return false;
  }

  isAvailable(): boolean {
    return this.getAvailableProxies().length > 0;
  }

  getAvailableCount(): number {
    return this.getAvailableProxies().length;
  }

  setHighAntiCrawlDomains(domains: string[]): void {
    this.highAntiCrawlDomains = new Set(domains);
  }

  isHighAntiCrawlDomain(domain: string): boolean {
    return this.highAntiCrawlDomains.has(domain);
  }

  requireProxyForDomain(domain: string): Result<void> {
    if (this.highAntiCrawlDomains.has(domain) && this.proxies.length === 0) {
      const errorMsg = CrawlError.create(CrawlErrorCode.PROXY_REQUIRED, `域名${domain}需要代理访问`).getLocalizedMessage();
      return Result.err(ErrorCode.NETWORK_ERROR, errorMsg);
    }
    return Result.ok(undefined);
  }

  private getAvailableProxies(): ProxyEntry[] {
    const now = Date.now();
    return this.proxies.filter((p: ProxyEntry) => {
      if (!p.available) {
        if (now - p.lastFailed > ProxyRotator.RECOVERY_MS) {
          p.available = true;
          p.failCount = 0;
          Logger.info(ProxyRotator.TAG, `Proxy ${p.id} auto-recovered after ${ProxyRotator.RECOVERY_MS / 1000}s`);
          return true;
        }
        return false;
      }
      return true;
    });
  }

  private findProxy(proxyId: string): ProxyEntry | undefined {
    return this.proxies.find((p: ProxyEntry) => p.id === proxyId);
  }

  private roundRobin(available: ProxyEntry[]): ProxyEntry {
    const proxy = available[this.currentIndex % available.length];
    this.currentIndex = (this.currentIndex + 1) % available.length;
    return proxy;
  }

  private random(available: ProxyEntry[]): ProxyEntry {
    const idx = Math.floor(Math.random() * available.length);
    return available[idx];
  }

  private leastFailures(available: ProxyEntry[]): ProxyEntry {
    let best = available[0];
    let bestScore = this.getScore(best);
    for (let i = 1; i < available.length; i++) {
      const score = this.getScore(available[i]);
      if (score > bestScore) {
        bestScore = score;
        best = available[i];
      }
    }
    return best;
  }

  private getScore(proxy: ProxyEntry): number {
    const total = proxy.successCount + proxy.failCount;
    if (total === 0) return 0.5;
    return proxy.successCount / total;
  }
}
