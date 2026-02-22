import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { Logger } from './Logger';
import { RequestThrottler } from './RequestThrottler';
import { NetworkManager } from './NetworkManager';
import { Book } from '../models/Book';
import { util } from '@kit.ArkTS';

export interface ImageInfo {
  url: string;
  format: ImageFormat;
  width: number;
  height: number;
  size: number;
  isValid: boolean;
  errorMessage?: string;
}

export interface ImageDownloadResult {
  success: boolean;
  localPath?: string;
  url: string;
  bookId: string;
  format?: ImageFormat;
  size?: number;
  width?: number;
  height?: number;
  errorMessage?: string;
  retryCount?: number;
}

export interface ImageScrapeConfig {
  maxConcurrentDownloads: number;
  downloadTimeout: number;
  maxRetries: number;
  retryDelay: number;
  minImageSize: number;
  maxImageSize: number;
  preferredFormats: ImageFormat[];
  userAgent: string;
  referer: string;
  enableCache: boolean;
  cacheTTL: number;
  skipSSLVerification: boolean;
  rateLimitPerSecond: number;
}

export interface ImageScrapeStats {
  totalProcessed: number;
  successful: number;
  failed: number;
  skipped: number;
  totalBytes: number;
  averageTime: number;
  cacheHits: number;
  cacheMisses: number;
}

export type ImageFormat = 'jpeg' | 'png' | 'webp' | 'gif' | 'bmp' | 'svg' | 'unknown';

export type ImageQuality = 'original' | 'high' | 'medium' | 'low';

interface StorageUsageResult {
  totalSize: number;
  imageCount: number;
  bookCount: number;
}

interface ImageCacheEntry {
  url: string;
  localPath: string;
  timestamp: number;
  size: number;
  format: ImageFormat;
}

interface AntiScrapingDetection {
  isBlocked: boolean;
  blockType: 'captcha' | 'rate_limit' | 'forbidden' | 'cloudflare' | 'unknown';
  waitTime: number;
  message: string;
}

interface ScrapeOptions {
  includeCover: boolean;
  includeInterior: boolean;
  quality: ImageQuality;
}

interface ImageValidationResult {
  isValid: boolean;
  format: ImageFormat;
  width: number;
  height: number;
  errorMessage?: string;
}

interface ImageDimensions {
  width: number;
  height: number;
}

const DEFAULT_CONFIG: ImageScrapeConfig = {
  maxConcurrentDownloads: 3,
  downloadTimeout: 30000,
  maxRetries: 3,
  retryDelay: 1000,
  minImageSize: 1024,
  maxImageSize: 10 * 1024 * 1024,
  preferredFormats: ['jpeg', 'png', 'webp'],
  userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  referer: '',
  enableCache: true,
  cacheTTL: 7 * 24 * 60 * 60 * 1000,
  skipSSLVerification: true,
  rateLimitPerSecond: 2
};

const IMAGE_SIGNATURES: Map<string, number[]> = new Map([
  ['jpeg', [0xFF, 0xD8, 0xFF]],
  ['png', [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]],
  ['gif', [0x47, 0x49, 0x46, 0x38]],
  ['webp', [0x52, 0x49, 0x46, 0x46]],
  ['bmp', [0x42, 0x4D]]
]);

export class ImageScraperService {
  private static instance: ImageScraperService | null = null;
  private config: ImageScrapeConfig;
  private context: common.UIAbilityContext | null = null;
  private imageCache: Map<string, ImageCacheEntry> = new Map();
  private stats: ImageScrapeStats;
  private throttler: RequestThrottler;
  private downloadQueue: Map<string, Promise<ImageDownloadResult>> = new Map();
  private readonly TAG = 'ImageScraperService';

  private constructor(config?: Partial<ImageScrapeConfig>) {
    this.config = this.mergeConfig(DEFAULT_CONFIG, config);
    this.throttler = RequestThrottler.getInstance({
      maxRequestsPerSecond: this.config.rateLimitPerSecond,
      maxConcurrentRequests: this.config.maxConcurrentDownloads,
      minInterval: 500,
      maxInterval: 5000,
      burstSize: 3,
      adaptiveMode: true,
      backoffOnBlock: true,
      maxBackoffMultiplier: 5
    });
    this.stats = this.initStats();
  }

  private mergeConfig(base: ImageScrapeConfig, update?: Partial<ImageScrapeConfig>): ImageScrapeConfig {
    if (!update) return base;
    const result: ImageScrapeConfig = {
      maxConcurrentDownloads: update.maxConcurrentDownloads ?? base.maxConcurrentDownloads,
      downloadTimeout: update.downloadTimeout ?? base.downloadTimeout,
      maxRetries: update.maxRetries ?? base.maxRetries,
      retryDelay: update.retryDelay ?? base.retryDelay,
      minImageSize: update.minImageSize ?? base.minImageSize,
      maxImageSize: update.maxImageSize ?? base.maxImageSize,
      preferredFormats: update.preferredFormats ?? base.preferredFormats,
      userAgent: update.userAgent ?? base.userAgent,
      referer: update.referer ?? base.referer,
      enableCache: update.enableCache ?? base.enableCache,
      cacheTTL: update.cacheTTL ?? base.cacheTTL,
      skipSSLVerification: update.skipSSLVerification ?? base.skipSSLVerification,
      rateLimitPerSecond: update.rateLimitPerSecond ?? base.rateLimitPerSecond
    };
    return result;
  }

  static getInstance(config?: Partial<ImageScrapeConfig>): ImageScraperService {
    if (!ImageScraperService.instance) {
      ImageScraperService.instance = new ImageScraperService(config);
    }
    return ImageScraperService.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  updateConfig(config: Partial<ImageScrapeConfig>): void {
    this.config = this.mergeConfig(this.config, config);
    Logger.info(this.TAG, 'Image scraper config updated');
  }

  getConfig(): ImageScrapeConfig {
    return this.cloneConfig(this.config);
  }

  getStats(): ImageScrapeStats {
    return this.cloneStats(this.stats);
  }

  private cloneConfig(config: ImageScrapeConfig): ImageScrapeConfig {
    const result: ImageScrapeConfig = {
      maxConcurrentDownloads: config.maxConcurrentDownloads,
      downloadTimeout: config.downloadTimeout,
      maxRetries: config.maxRetries,
      retryDelay: config.retryDelay,
      minImageSize: config.minImageSize,
      maxImageSize: config.maxImageSize,
      preferredFormats: config.preferredFormats,
      userAgent: config.userAgent,
      referer: config.referer,
      enableCache: config.enableCache,
      cacheTTL: config.cacheTTL,
      skipSSLVerification: config.skipSSLVerification,
      rateLimitPerSecond: config.rateLimitPerSecond
    };
    return result;
  }

  private cloneStats(stats: ImageScrapeStats): ImageScrapeStats {
    const result: ImageScrapeStats = {
      totalProcessed: stats.totalProcessed,
      successful: stats.successful,
      failed: stats.failed,
      skipped: stats.skipped,
      totalBytes: stats.totalBytes,
      averageTime: stats.averageTime,
      cacheHits: stats.cacheHits,
      cacheMisses: stats.cacheMisses
    };
    return result;
  }

  resetStats(): void {
    this.stats = this.initStats();
  }

  private initStats(): ImageScrapeStats {
    return {
      totalProcessed: 0,
      successful: 0,
      failed: 0,
      skipped: 0,
      totalBytes: 0,
      averageTime: 0,
      cacheHits: 0,
      cacheMisses: 0
    };
  }

  async scrapeBookImages(book: Book, options?: Partial<ScrapeOptions>): Promise<ImageDownloadResult[]> {
    const results: ImageDownloadResult[] = [];
    const opts: ScrapeOptions = {
      includeCover: options?.includeCover ?? true,
      includeInterior: options?.includeInterior ?? false,
      quality: options?.quality ?? 'original'
    };

    if (opts.includeCover && book.cover) {
      const coverResult = await this.downloadImage(book.cover, book.id, 'cover');
      results.push(coverResult);
    }

    return results;
  }

  async downloadImage(
    imageUrl: string,
    bookId: string,
    imageType: 'cover' | 'interior' | 'thumbnail' = 'cover'
  ): Promise<ImageDownloadResult> {
    const startTime = Date.now();
    this.stats.totalProcessed++;

    if (!imageUrl || !this.isValidImageUrl(imageUrl)) {
      this.stats.failed++;
      return {
        success: false,
        url: imageUrl,
        bookId,
        errorMessage: 'Invalid image URL'
      };
    }

    const cachedEntry = this.checkCache(imageUrl);
    if (cachedEntry) {
      this.stats.cacheHits++;
      this.stats.successful++;
      return {
        success: true,
        localPath: cachedEntry.localPath,
        url: imageUrl,
        bookId,
        format: cachedEntry.format,
        size: cachedEntry.size
      };
    }

    this.stats.cacheMisses++;

    const existingDownload = this.downloadQueue.get(imageUrl);
    if (existingDownload) {
      Logger.debug(this.TAG, `Waiting for existing download: ${imageUrl}`);
      return existingDownload;
    }

    const downloadPromise = this.executeDownload(imageUrl, bookId, imageType);
    this.downloadQueue.set(imageUrl, downloadPromise);

    try {
      const result = await downloadPromise;
      const elapsed = Date.now() - startTime;
      this.stats.averageTime = (this.stats.averageTime * (this.stats.totalProcessed - 1) + elapsed) / this.stats.totalProcessed;

      if (result.success) {
        this.stats.successful++;
        if (result.size) {
          this.stats.totalBytes += result.size;
        }
      } else {
        this.stats.failed++;
      }

      return result;
    } finally {
      this.downloadQueue.delete(imageUrl);
    }
  }

  private async executeDownload(
    imageUrl: string,
    bookId: string,
    imageType: string
  ): Promise<ImageDownloadResult> {
    let lastError: string | undefined;
    let retryCount = 0;

    for (let attempt = 0; attempt <= this.config.maxRetries; attempt++) {
      if (attempt > 0) {
        const delay = this.calculateBackoffDelay(attempt);
        Logger.info(this.TAG, `Retry attempt ${attempt}/${this.config.maxRetries}, waiting ${delay}ms`);
        await this.sleep(delay);
        retryCount = attempt;
      }

      await this.throttler.acquire(imageUrl);

      try {
        const result = await this.downloadSingleImage(imageUrl, bookId, imageType);
        if (result.success) {
          result.retryCount = retryCount;
          return result;
        }
        lastError = result.errorMessage;

        const detection = this.detectAntiScraping(result.errorMessage || '');
        if (detection.isBlocked) {
          Logger.warn(this.TAG, `Anti-scraping detected: ${detection.blockType}`);
          if (detection.blockType === 'captcha') {
            return {
              success: false,
              url: imageUrl,
              bookId,
              errorMessage: 'CAPTCHA detected, manual intervention required',
              retryCount
            };
          }
          await this.sleep(detection.waitTime);
        }
      } catch (error) {
        lastError = error instanceof Error ? error.message : String(error);
        Logger.error(this.TAG, `Download attempt ${attempt + 1} failed: ${lastError}`);
      }
    }

    return {
      success: false,
      url: imageUrl,
      bookId,
      errorMessage: lastError || 'Max retries exceeded',
      retryCount
    };
  }

  private async downloadSingleImage(
    imageUrl: string,
    bookId: string,
    imageType: string
  ): Promise<ImageDownloadResult> {
    if (!this.context) {
      return {
        success: false,
        url: imageUrl,
        bookId,
        errorMessage: 'Context not initialized'
      };
    }

    try {
      const httpRequest = http.createHttp();

      const headers: Record<string, string> = {
        'User-Agent': this.config.userAgent,
        'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache'
      };

      if (this.config.referer) {
        headers['Referer'] = this.config.referer;
      }

      const response = await httpRequest.request(imageUrl, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: this.config.downloadTimeout,
        readTimeout: this.config.downloadTimeout,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });

      if (response.responseCode === 200 || response.responseCode === 202) {
        const arrayBuffer = response.result as ArrayBuffer;
        const uint8Data = new Uint8Array(arrayBuffer);

        const validation = this.validateImageData(uint8Data);
        if (!validation.isValid) {
          httpRequest.destroy();
          return {
            success: false,
            url: imageUrl,
            bookId,
            errorMessage: validation.errorMessage
          };
        }

        const localPath = await this.saveImage(uint8Data, bookId, imageType, validation.format);

        this.addToCache(imageUrl, localPath, uint8Data.length, validation.format);

        httpRequest.destroy();

        return {
          success: true,
          localPath,
          url: imageUrl,
          bookId,
          format: validation.format,
          size: uint8Data.length,
          width: validation.width,
          height: validation.height
        };
      } else if (response.responseCode === 301 || response.responseCode === 302) {
        const location = this.getHeaderValue(response.header, 'Location') ||
          this.getHeaderValue(response.header, 'location');
        httpRequest.destroy();

        if (location) {
          const redirectUrl = this.resolveUrl(imageUrl, location);
          Logger.info(this.TAG, `Redirecting to: ${redirectUrl}`);
          return this.downloadSingleImage(redirectUrl, bookId, imageType);
        }

        return {
          success: false,
          url: imageUrl,
          bookId,
          errorMessage: `HTTP ${response.responseCode}: No redirect location`
        };
      } else if (response.responseCode === 403) {
        httpRequest.destroy();
        return {
          success: false,
          url: imageUrl,
          bookId,
          errorMessage: 'HTTP 403: Access forbidden (possible anti-scraping)'
        };
      } else if (response.responseCode === 429) {
        httpRequest.destroy();
        return {
          success: false,
          url: imageUrl,
          bookId,
          errorMessage: 'HTTP 429: Rate limited'
        };
      } else {
        httpRequest.destroy();
        return {
          success: false,
          url: imageUrl,
          bookId,
          errorMessage: `HTTP ${response.responseCode}`
        };
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      Logger.error(this.TAG, `Download error: ${errorMessage}`);
      return {
        success: false,
        url: imageUrl,
        bookId,
        errorMessage
      };
    }
  }

  private validateImageData(data: Uint8Array): ImageValidationResult {
    if (data.length < this.config.minImageSize) {
      const result: ImageValidationResult = {
        isValid: false,
        format: 'unknown',
        width: 0,
        height: 0,
        errorMessage: `Image too small: ${data.length} bytes (min: ${this.config.minImageSize})`
      };
      return result;
    }

    if (data.length > this.config.maxImageSize) {
      const result: ImageValidationResult = {
        isValid: false,
        format: 'unknown',
        width: 0,
        height: 0,
        errorMessage: `Image too large: ${data.length} bytes (max: ${this.config.maxImageSize})`
      };
      return result;
    }

    const format = this.detectImageFormat(data);
    if (format === 'unknown') {
      const result: ImageValidationResult = {
        isValid: false,
        format: 'unknown',
        width: 0,
        height: 0,
        errorMessage: 'Unknown image format'
      };
      return result;
    }

    const dimensions = this.extractImageDimensions(data, format);

    const result: ImageValidationResult = {
      isValid: true,
      format: format,
      width: dimensions.width,
      height: dimensions.height
    };
    return result;
  }

  detectImageFormat(data: Uint8Array): ImageFormat {
    const entries = Array.from(IMAGE_SIGNATURES.entries());
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const format = entry[0];
      const signature = entry[1];
      if (this.matchesSignature(data, signature)) {
        if (format === 'webp') {
          if (data.length > 11 &&
            String.fromCharCode(data[8], data[9], data[10], data[11]) === 'WEBP') {
            return 'webp';
          }
          continue;
        }
        return format as ImageFormat;
      }
    }

    if (data.length > 4) {
      const header = String.fromCharCode(...Array.from(data.slice(0, 4)).map(b => b as number));
      if (header === '<svg' || header === '<?xml') {
        return 'svg';
      }
    }

    return 'unknown';
  }

  private matchesSignature(data: Uint8Array, signature: number[]): boolean {
    if (data.length < signature.length) {
      return false;
    }
    for (let i = 0; i < signature.length; i++) {
      if (data[i] !== signature[i]) {
        return false;
      }
    }
    return true;
  }

  private extractImageDimensions(data: Uint8Array, format: ImageFormat): ImageDimensions {
    try {
      switch (format) {
        case 'png':
          return this.extractPngDimensions(data);
        case 'jpeg':
          return this.extractJpegDimensions(data);
        case 'gif':
          return this.extractGifDimensions(data);
        case 'webp':
          return this.extractWebpDimensions(data);
        case 'bmp':
          return this.extractBmpDimensions(data);
        default:
          const defaultResult: ImageDimensions = { width: 0, height: 0 };
          return defaultResult;
      }
    } catch (error) {
      Logger.warn(this.TAG, `Failed to extract dimensions: ${error}`);
      const errorResult: ImageDimensions = { width: 0, height: 0 };
      return errorResult;
    }
  }

  private extractPngDimensions(data: Uint8Array): ImageDimensions {
    if (data.length < 24) {
      const result: ImageDimensions = { width: 0, height: 0 };
      return result;
    }
    const view = new DataView(data.buffer, 16, 8);
    const result: ImageDimensions = {
      width: view.getUint32(0, false),
      height: view.getUint32(4, false)
    };
    return result;
  }

  private extractJpegDimensions(data: Uint8Array): ImageDimensions {
    let offset = 2;
    while (offset < data.length - 4) {
      if (data[offset] !== 0xFF) {
        offset++;
        continue;
      }

      const marker = data[offset + 1];

      if (marker === 0xC0 || marker === 0xC1 || marker === 0xC2 ||
        marker === 0xC3 || marker === 0xC5 || marker === 0xC6 ||
        marker === 0xC7 || marker === 0xC9 || marker === 0xCA ||
        marker === 0xCB || marker === 0xCD || marker === 0xCE ||
        marker === 0xCF) {
        if (offset + 9 > data.length) break;
        const view = new DataView(data.buffer, offset + 5, 4);
        const result: ImageDimensions = {
          height: view.getUint16(0, false),
          width: view.getUint16(2, false)
        };
        return result;
      }

      if (marker === 0xD8 || marker === 0xD9) {
        offset += 2;
        continue;
      }

      if (offset + 4 > data.length) break;
      const length = (data[offset + 2] << 8) | data[offset + 3];
      offset += 2 + length;
    }
    const result: ImageDimensions = { width: 0, height: 0 };
    return result;
  }

  private extractGifDimensions(data: Uint8Array): ImageDimensions {
    if (data.length < 10) {
      const result: ImageDimensions = { width: 0, height: 0 };
      return result;
    }
    const result: ImageDimensions = {
      width: data[6] | (data[7] << 8),
      height: data[8] | (data[9] << 8)
    };
    return result;
  }

  private extractWebpDimensions(data: Uint8Array): ImageDimensions {
    if (data.length < 30) {
      const result: ImageDimensions = { width: 0, height: 0 };
      return result;
    }

    const riff = String.fromCharCode(data[0], data[1], data[2], data[3]);
    const webp = String.fromCharCode(data[8], data[9], data[10], data[11]);

    if (riff !== 'RIFF' || webp !== 'WEBP') {
      const result: ImageDimensions = { width: 0, height: 0 };
      return result;
    }

    const chunkType = String.fromCharCode(data[12], data[13], data[14], data[15]);
    if (chunkType === 'VP8 ') {
      if (data.length < 30) {
        const result: ImageDimensions = { width: 0, height: 0 };
        return result;
      }
      const width = (data[26] | (data[27] << 8)) & 0x3FFF;
      const height = (data[28] | (data[29] << 8)) & 0x3FFF;
      const result: ImageDimensions = { width: width, height: height };
      return result;
    } else if (chunkType === 'VP8L') {
      if (data.length < 25) {
        const result: ImageDimensions = { width: 0, height: 0 };
        return result;
      }
      const bits = data[21] | (data[22] << 8) | (data[23] << 16) | (data[24] << 24);
      const result: ImageDimensions = {
        width: (bits & 0x3FFF) + 1,
        height: ((bits >> 14) & 0x3FFF) + 1
      };
      return result;
    } else if (chunkType === 'VP8X') {
      if (data.length < 30) {
        const result: ImageDimensions = { width: 0, height: 0 };
        return result;
      }
      const width = (data[24] | (data[25] << 8) | (data[26] << 16)) + 1;
      const height = (data[27] | (data[28] << 8) | (data[29] << 16)) + 1;
      const result: ImageDimensions = { width: width, height: height };
      return result;
    }

    const result: ImageDimensions = { width: 0, height: 0 };
    return result;
  }

  private extractBmpDimensions(data: Uint8Array): ImageDimensions {
    if (data.length < 26) {
      const result: ImageDimensions = { width: 0, height: 0 };
      return result;
    }
    const view = new DataView(data.buffer, 18, 8);
    const result: ImageDimensions = {
      width: view.getInt32(0, true),
      height: Math.abs(view.getInt32(4, true))
    };
    return result;
  }

  private async saveImage(
    data: Uint8Array,
    bookId: string,
    imageType: string,
    format: ImageFormat
  ): Promise<string> {
    if (!this.context) {
      throw new Error('Context not initialized');
    }

    const filesDir = this.context.filesDir;
    const imageDir = `${filesDir}/images/${bookId}`;

    try {
      fs.mkdirSync(imageDir, true);
    } catch (error) {
      Logger.warn(this.TAG, `Directory may already exist: ${imageDir}`);
    }

    const extension = this.getExtension(format);
    const fileName = `${imageType}_${Date.now()}.${extension}`;
    const filePath = `${imageDir}/${fileName}`;

    const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
    fs.writeSync(file.fd, data.buffer);
    fs.closeSync(file);

    Logger.info(this.TAG, `Image saved: ${filePath}`);
    return filePath;
  }

  private getExtension(format: ImageFormat): string {
    const extensions: Record<ImageFormat, string> = {
      'jpeg': 'jpg',
      'png': 'png',
      'webp': 'webp',
      'gif': 'gif',
      'bmp': 'bmp',
      'svg': 'svg',
      'unknown': 'bin'
    };
    return extensions[format] || 'bin';
  }

  isValidImageUrl(url: string): boolean {
    if (!url) return false;

    try {
      const lowerUrl = url.toLowerCase();
      if (!lowerUrl.startsWith('http://') && !lowerUrl.startsWith('https://') &&
        !lowerUrl.startsWith('data:image/')) {
        return false;
      }

      if (lowerUrl.startsWith('data:image/')) {
        return true;
      }

      const imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.svg'];
      const hasImageExtension = imageExtensions.some(ext => lowerUrl.includes(ext));

      if (hasImageExtension) return true;

      const imagePatterns = ['/image/', '/img/', '/cover/', '/photo/', '/pic/', 'image=', 'img='];
      return imagePatterns.some(pattern => lowerUrl.includes(pattern));
    } catch {
      return false;
    }
  }

  detectImagesInHtml(html: string, baseUrl: string): string[] {
    const images: string[] = [];
    const imgRegex = /<img[^>]+src=["']([^"']+)["']/gi;
    let match;

    while ((match = imgRegex.exec(html)) !== null) {
      const src = match[1];
      const resolvedUrl = this.resolveUrl(baseUrl, src);
      if (this.isValidImageUrl(resolvedUrl)) {
        images.push(resolvedUrl);
      }
    }

    const srcsetRegex = /srcset=["']([^"']+)["']/gi;
    while ((match = srcsetRegex.exec(html)) !== null) {
      const srcset = match[1];
      const sources = srcset.split(',');
      for (const source of sources) {
        const url = source.trim().split(/\s+/)[0];
        const resolvedUrl = this.resolveUrl(baseUrl, url);
        if (this.isValidImageUrl(resolvedUrl)) {
          images.push(resolvedUrl);
        }
      }
    }

    const bgImageRegex = /url\(["']?([^"')]+)["']?\)/gi;
    while ((match = bgImageRegex.exec(html)) !== null) {
      const url = match[1];
      const resolvedUrl = this.resolveUrl(baseUrl, url);
      if (this.isValidImageUrl(resolvedUrl)) {
        images.push(resolvedUrl);
      }
    }

    const uniqueImages = [...new Set(images)];
    return this.prioritizeImages(uniqueImages, baseUrl);
  }

  private prioritizeImages(images: string[], baseUrl: string): string[] {
    const scored = images.map(url => {
      let score = 0;
      const lowerUrl = url.toLowerCase();

      if (lowerUrl.includes('cover')) score += 100;
      if (lowerUrl.includes('poster')) score += 90;
      if (lowerUrl.includes('thumbnail')) score += 50;
      if (lowerUrl.includes('avatar')) score += 30;
      if (lowerUrl.includes('icon')) score -= 50;
      if (lowerUrl.includes('logo')) score -= 60;
      if (lowerUrl.includes('banner')) score -= 30;
      if (lowerUrl.includes('ad') || lowerUrl.includes('adv')) score -= 100;
      if (lowerUrl.includes('loading')) score -= 80;
      if (lowerUrl.includes('placeholder')) score -= 70;

      if (lowerUrl.endsWith('.webp')) score += 10;
      if (lowerUrl.endsWith('.png')) score += 5;

      if (lowerUrl.includes('width=') || lowerUrl.includes('w=')) {
        const widthMatch = lowerUrl.match(/[?&]w(?:idth)?=(\d+)/);
        if (widthMatch) {
          const width = parseInt(widthMatch[1]);
          if (width >= 200 && width <= 600) score += 20;
        }
      }

      return { url, score };
    });

    scored.sort((a, b) => b.score - a.score);
    return scored.map(item => item.url);
  }

  private detectAntiScraping(errorMessage: string): AntiScrapingDetection {
    const lowerMessage = errorMessage.toLowerCase();

    if (lowerMessage.includes('captcha') || lowerMessage.includes('验证')) {
      return {
        isBlocked: true,
        blockType: 'captcha',
        waitTime: 0,
        message: 'CAPTCHA detected'
      };
    }

    if (lowerMessage.includes('429') || lowerMessage.includes('rate limit')) {
      return {
        isBlocked: true,
        blockType: 'rate_limit',
        waitTime: 5000,
        message: 'Rate limited'
      };
    }

    if (lowerMessage.includes('403') || lowerMessage.includes('forbidden')) {
      return {
        isBlocked: true,
        blockType: 'forbidden',
        waitTime: 3000,
        message: 'Access forbidden'
      };
    }

    if (lowerMessage.includes('cloudflare')) {
      return {
        isBlocked: true,
        blockType: 'cloudflare',
        waitTime: 10000,
        message: 'Cloudflare protection'
      };
    }

    return {
      isBlocked: false,
      blockType: 'unknown',
      waitTime: 0,
      message: ''
    };
  }

  private checkCache(url: string): ImageCacheEntry | null {
    if (!this.config.enableCache) return null;

    const entry = this.imageCache.get(url);
    if (!entry) return null;

    const age = Date.now() - entry.timestamp;
    if (age > this.config.cacheTTL) {
      this.imageCache.delete(url);
      return null;
    }

    return entry;
  }

  private addToCache(url: string, localPath: string, size: number, format: ImageFormat): void {
    if (!this.config.enableCache) return;

    this.imageCache.set(url, {
      url,
      localPath,
      timestamp: Date.now(),
      size,
      format
    });
  }

  clearCache(): void {
    this.imageCache.clear();
    Logger.info(this.TAG, 'Image cache cleared');
  }

  /**
   * 获取缓存的图片路径
   * @param url 图片URL
   * @returns 缓存的本地路径，如果不存在或已过期则返回 null
   */
  getCachedImagePath(url: string): string | null {
    const entry = this.checkCache(url);
    return entry ? entry.localPath : null;
  }

  /**
   * 检查图片是否已缓存
   * @param url 图片URL
   * @returns 是否已缓存且未过期
   */
  isImageCached(url: string): boolean {
    return this.checkCache(url) !== null;
  }

  async cleanupOldImages(maxAge: number = 30 * 24 * 60 * 60 * 1000): Promise<number> {
    if (!this.context) return 0;

    const filesDir = this.context.filesDir;
    const imageDir = `${filesDir}/images`;
    let deletedCount = 0;

    try {
      const bookDirs = fs.listFileSync(imageDir);
      const now = Date.now();

      for (const bookDir of bookDirs) {
        const stat = fs.statSync(bookDir);
        if (now - stat.mtime > maxAge) {
          fs.rmdirSync(bookDir);
          deletedCount++;
        }
      }
    } catch (error) {
      Logger.error(this.TAG, `Cleanup error: ${error}`);
    }

    return deletedCount;
  }

  private resolveUrl(baseUrl: string, relativeUrl: string): string {
    if (!relativeUrl) return '';

    if (relativeUrl.startsWith('data:')) return relativeUrl;
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }

    try {
      const protocolIndex = baseUrl.indexOf('://');
      if (protocolIndex === -1) return relativeUrl;

      const protocol = baseUrl.substring(0, protocolIndex + 3);
      const hostStart = protocolIndex + 3;
      const pathIndex = baseUrl.indexOf('/', hostStart);

      let origin: string;
      let basePath: string;

      if (pathIndex === -1) {
        origin = baseUrl;
        basePath = '/';
      } else {
        origin = baseUrl.substring(0, pathIndex);
        basePath = baseUrl.substring(pathIndex);
      }

      if (relativeUrl.startsWith('//')) {
        return protocol + relativeUrl;
      }

      if (relativeUrl.startsWith('/')) {
        return origin + relativeUrl;
      }

      const lastSlashIndex = basePath.lastIndexOf('/');
      const dirPath = lastSlashIndex >= 0 ? basePath.substring(0, lastSlashIndex + 1) : '/';
      return origin + dirPath + relativeUrl;
    } catch {
      return relativeUrl;
    }
  }

  private extractDomain(url: string): string {
    try {
      const protocolIndex = url.indexOf('://');
      if (protocolIndex === -1) return 'unknown';

      const hostStart = protocolIndex + 3;
      const pathIndex = url.indexOf('/', hostStart);

      if (pathIndex === -1) {
        return url.substring(hostStart);
      }

      return url.substring(hostStart, pathIndex);
    } catch {
      return 'unknown';
    }
  }

  private getHeaderValue(headers: object, key: string): string | undefined {
    if (!headers) return undefined;

    const record = headers as Record<string, string | string[]>;
    const value = record[key];

    if (Array.isArray(value)) {
      return value[0];
    }
    return value;
  }

  private calculateBackoffDelay(attempt: number): number {
    const baseDelay = this.config.retryDelay;
    const maxDelay = baseDelay * 10;
    const delay = baseDelay * Math.pow(2, attempt - 1);
    const jitter = Math.random() * 0.1 * delay;
    return Math.min(delay + jitter, maxDelay);
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async batchDownloadImages(
    items: Array<{ url: string; bookId: string; type: 'cover' | 'interior' | 'thumbnail' }>,
    onProgress?: (completed: number, total: number, result: ImageDownloadResult) => void
  ): Promise<ImageDownloadResult[]> {
    const results: ImageDownloadResult[] = [];
    let completed = 0;

    const chunks: Array<typeof items> = [];
    for (let i = 0; i < items.length; i += this.config.maxConcurrentDownloads) {
      chunks.push(items.slice(i, i + this.config.maxConcurrentDownloads));
    }

    for (const chunk of chunks) {
      const chunkResults = await Promise.all(
        chunk.map(async item => {
          const result = await this.downloadImage(item.url, item.bookId, item.type);
          completed++;
          if (onProgress) {
            onProgress(completed, items.length, result);
          }
          return result;
        })
      );
      results.push(...chunkResults);

      if (chunks.indexOf(chunk) < chunks.length - 1) {
        await this.sleep(500);
      }
    }

    return results;
  }

  getImageInfo(localPath: string): ImageInfo | null {
    try {
      const stat = fs.statSync(localPath);
      const file = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(Math.min(stat.size, 1024));
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);

      const uint8Data = new Uint8Array(buffer);
      const format = this.detectImageFormat(uint8Data);

      return {
        url: localPath,
        format,
        width: 0,
        height: 0,
        size: stat.size,
        isValid: format !== 'unknown'
      };
    } catch (error) {
      Logger.error(this.TAG, `Failed to get image info: ${error}`);
      return null;
    }
  }

  async deleteImage(localPath: string): Promise<boolean> {
    try {
      fs.unlinkSync(localPath);
      Logger.info(this.TAG, `Image deleted: ${localPath}`);
      return true;
    } catch (error) {
      Logger.error(this.TAG, `Failed to delete image: ${error}`);
      return false;
    }
  }

  async getStorageUsage(): Promise<StorageUsageResult> {
    if (!this.context) {
      return { totalSize: 0, imageCount: 0, bookCount: 0 } as StorageUsageResult;
    }

    const filesDir = this.context.filesDir;
    const imageDir = `${filesDir}/images`;
    let totalSize = 0;
    let imageCount = 0;
    let bookCount = 0;

    try {
      const bookDirs = fs.listFileSync(imageDir);
      bookCount = bookDirs.length;

      for (const bookDir of bookDirs) {
        const files = fs.listFileSync(bookDir);
        for (const file of files) {
          const stat = fs.statSync(file);
          totalSize += stat.size;
          imageCount++;
        }
      }
    } catch (error) {
      Logger.error(this.TAG, `Failed to calculate storage: ${error}`);
    }

    return { totalSize, imageCount, bookCount } as StorageUsageResult;
  }
}

// 导出单例实例
export const imageScraperService = ImageScraperService.getInstance();
