import { ParserResult } from "./IParser";
import { IParseResultCache, CacheStats } from "./interfaces/IUnifiedParseEngine";
import { LRUCache } from "../performance/LRUCache";
import { Logger } from "../performance/Logger";

export class ParseResultCache implements IParseResultCache {
  private static readonly TAG = 'ParseResultCache';
  private static readonly DEFAULT_CAPACITY = 500;
  private static readonly DEFAULT_TTL_MS = 5000;
  private static readonly MAX_MEMORY_BYTES = 64 * 1024 * 1024;

  private cache: LRUCache<string, ParserResult>;
  private currentMemoryBytes: number = 0;
  private hits: number = 0;
  private misses: number = 0;

  constructor(capacity: number = ParseResultCache.DEFAULT_CAPACITY, ttlMs: number = ParseResultCache.DEFAULT_TTL_MS) {
    this.cache = new LRUCache<string, ParserResult>(capacity, ttlMs);
  }

  get(contentHash: string, rule: string): ParserResult | null {
    const key = this.buildKey(contentHash, rule);
    const result = this.cache.get(key);
    if (result !== null) {
      this.hits++;
      Logger.debug(ParseResultCache.TAG, `Cache hit: ${key}`);
      return result;
    }
    this.misses++;
    return null;
  }

  set(contentHash: string, rule: string, result: ParserResult): void {
    const key = this.buildKey(contentHash, rule);
    const estimatedSize = this.estimateSize(result);

    if (this.currentMemoryBytes + estimatedSize > ParseResultCache.MAX_MEMORY_BYTES) {
      Logger.debug(ParseResultCache.TAG, `Memory limit reached, skipping cache set for ${key}`);
      return;
    }

    this.cache.set(key, result);
    this.currentMemoryBytes += estimatedSize;
  }

  invalidate(contentHash: string, rule: string): boolean {
    const key = this.buildKey(contentHash, rule);
    const existing = this.cache.get(key);
    if (existing !== null) {
      this.currentMemoryBytes -= this.estimateSize(existing);
    }
    return this.cache.delete(key);
  }

  clear(): void {
    this.cache.clear();
    this.currentMemoryBytes = 0;
    this.hits = 0;
    this.misses = 0;
  }

  getStats(): CacheStats {
    const baseStats = this.cache.getStats();
    return {
      hits: this.hits,
      misses: this.misses,
      hitRate: this.hits + this.misses > 0 ? this.hits / (this.hits + this.misses) : 0,
      size: baseStats.size,
      capacity: baseStats.capacity,
      memoryUsageBytes: this.currentMemoryBytes,
    };
  }

  private buildKey(contentHash: string, rule: string): string {
    return `${contentHash}::${rule}`;
  }

  private estimateSize(result: ParserResult): number {
    let size = 0;
    size += result.value.length * 2;
    for (const v of result.values) {
      size += v.length * 2;
    }
    size += 64;
    return size;
  }
}
