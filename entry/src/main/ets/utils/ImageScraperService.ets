import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { Logger } from './Logger';
import { RequestThrottler } from './RequestThrottler';
import { NetworkManager } from './NetworkManager';
import { Book } from '../models/Book';
import { util } from '@kit.ArkTS';
import { networkConfigManager, ImageScraperConfig } from './NetworkConfig';

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

export type ImageFormat = 'jpeg' | 'png' | 'webp' | 'gif' | 'bmp' | 'svg' | 'unknown';

export type ImageQuality = 'original' | 'high' | 'medium' | 'low';

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

const IMAGE_SIGNATURES: Map<string, number[]> = new Map([
  ['jpeg', [0xFF, 0xD8, 0xFF]],
  ['png', [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]],
  ['gif', [0x47, 0x49, 0x46, 0x38]],
  ['webp', [0x52, 0x49, 0x46, 0x46]],
  ['bmp', [0x42, 0x4D]]
]);

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

export class ImageScraperService {
  private static instance: ImageScraperService | null = null;
  private config: ImageScraperConfig;
  private context: common.UIAbilityContext | null = null;
  private imageCache: Map<string, ImageCacheEntry> = new Map();
  private stats: ImageScrapeStats;
  private throttler: RequestThrottler;
  private downloadQueue: Map<string, Promise<ImageDownloadResult>> = new Map();
  private readonly TAG = 'ImageScraperService';

  private constructor(config?: Partial<ImageScraperConfig>) {
    const baseConfig = networkConfigManager.getImageScraperConfig();
    this.config = { ...baseConfig, ...config };
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

  static getInstance(config?: Partial<ImageScraperConfig>): ImageScraperService {
    if (!ImageScraperService.instance) {
      ImageScraperService.instance = new ImageScraperService(config);
    }
    return ImageScraperService.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  updateConfig(config: Partial<ImageScrapeConfig>): void {
    this.config = { ...this.config, ...config };
    Logger.info(this.TAG, 'Image scraper config updated');
  }

  getConfig(): ImageScrapeConfig {
    return { ...this.config };
  }

  getStats(): ImageScrapeStats {
    return { ...this.stats };
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

  async scrapeBookImages(book: Book, options?: {
    includeCover?: boolean;
    includeInterior?: boolean;
    quality?: ImageQuality;
  }): Promise<ImageDownloadResult[]> {
    const results: ImageDownloadResult[] = [];
    const opts = {
      includeCover: true,
      includeInterior: false,
      quality: 'original' as ImageQuality,
      ...options
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

      const throttleResult = await this.throttler.waitForSlot(this.extractDomain(imageUrl));
      if (!throttleResult.allowed) {
        Logger.warn(this.TAG, `Rate limited: ${throttleResult.reason}`);
        await this.sleep(throttleResult.waitTime);
      }

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

  private validateImageData(data: Uint8Array): {
    isValid: boolean;
    format: ImageFormat;
    width: number;
    height: number;
    errorMessage?: string;
  } {
    if (data.length < this.config.minImageSize) {
      return {
        isValid: false,
        format: 'unknown',
        width: 0,
        height: 0,
        errorMessage: `Image too small: ${data.length} bytes (min: ${this.config.minImageSize})`
      };
    }

    if (data.length > this.config.maxImageSize) {
      return {
        isValid: false,
        format: 'unknown',
        width: 0,
        height: 0,
        errorMessage: `Image too large: ${data.length} bytes (max: ${this.config.maxImageSize})`
      };
    }

    const format = this.detectImageFormat(data);
    if (format === 'unknown') {
      return {
        isValid: false,
        format: 'unknown',
        width: 0,
        height: 0,
        errorMessage: 'Unknown image format'
      };
    }

    const dimensions = this.extractImageDimensions(data, format);

    return {
      isValid: true,
      format,
      width: dimensions.width,
      height: dimensions.height
    };
  }

  detectImageFormat(data: Uint8Array): ImageFormat {
    for (const [format, signature] of IMAGE_SIGNATURES) {
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

  private extractImageDimensions(data: Uint8Array, format: ImageFormat): { width: number; height: number } {
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
          return { width: 0, height: 0 };
      }
    } catch (error) {
      Logger.warn(this.TAG, `Failed to extract dimensions: ${error}`);
      return { width: 0, height: 0 };
    }
  }

  private extractPngDimensions(data: Uint8Array): { width: number; height: number } {
    if (data.length < 24) return { width: 0, height: 0 };
    const view = new DataView(data.buffer, 16, 8);
    return {
      width: view.getUint32(0, false),
      height: view.getUint32(4, false)
    };
  }

  private extractJpegDimensions(data: Uint8Array): { width: number; height: number } {
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
        return {
          height: view.getUint16(0, false),
          width: view.getUint16(2, false)
        };
      }

      if (marker === 0xD8 || marker === 0xD9) {
        offset += 2;
        continue;
      }

      if (offset + 4 > data.length) break;
      const length = (data[offset + 2] << 8) | data[offset + 3];
      offset += 2 + length;
    }
    return { width: 0, height: 0 };
  }

  private extractGifDimensions(data: Uint8Array): { width: number; height: number } {
    if (data.length < 10) return { width: 0, height: 0 };
    return {
      width: data[6] | (data[7] << 8),
      height: data[8] | (data[9] << 8)
    };
  }

  private extractWebpDimensions(data: Uint8Array): { width: number; height: number } {
    if (data.length < 30) return { width: 0, height: 0 };

    const riff = String.fromCharCode(data[0], data[1], data[2], data[3]);
    const webp = String.fromCharCode(data[8], data[9], data[10], data[11]);

    if (riff !== 'RIFF' || webp !== 'WEBP') {
      return { width: 0, height: 0 };
    }

    const chunkType = String.fromCharCode(data[12], data[13], data[14], data[15]);
    if (chunkType === 'VP8 ') {
      if (data.length < 30) return { width: 0, height: 0 };
      const width = (data[26] | (data[27] << 8)) & 0x3FFF;
      const height = (data[28] | (data[29] << 8)) & 0x3FFF;
      return { width, height };
    } else if (chunkType === 'VP8L') {
      if (data.length < 25) return { width: 0, height: 0 };
      const bits = data[21] | (data[22] << 8) | (data[23] << 16) | (data[24] << 24);
      return {
        width: (bits & 0x3FFF) + 1,
        height: ((bits >> 14) & 0x3FFF) + 1
      };
    } else if (chunkType === 'VP8X') {
      if (data.length < 30) return { width: 0, height: 0 };
      const width = (data[24] | (data[25] << 8) | (data[26] << 16)) + 1;
      const height = (data[27] | (data[28] << 8) | (data[29] << 16)) + 1;
      return { width, height };
    }

    return { width: 0, height: 0 };
  }

  private extractBmpDimensions(data: Uint8Array): { width: number; height: number } {
    if (data.length < 26) return { width: 0, height: 0 };
    const view = new DataView(data.buffer, 18, 8);
    return {
      width: view.getInt32(0, true),
      height: Math.abs(view.getInt32(4, true))
    };
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
      const base = new URL(baseUrl);

      if (relativeUrl.startsWith('//')) {
        return base.protocol + relativeUrl;
      }

      if (relativeUrl.startsWith('/')) {
        return base.origin + relativeUrl;
      }

      const basePath = base.pathname.substring(0, base.pathname.lastIndexOf('/') + 1);
      return base.origin + basePath + relativeUrl;
    } catch {
      return relativeUrl;
    }
  }

  private extractDomain(url: string): string {
    try {
      const parsed = new URL(url);
      return parsed.hostname;
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

  async getStorageUsage(): Promise<{ totalSize: number; imageCount: number; bookCount: number }> {
    if (!this.context) {
      return { totalSize: 0, imageCount: 0, bookCount: 0 };
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

    return { totalSize, imageCount, bookCount };
  }
}
