import { Logger } from "../performance/Logger";

export interface ImageCandidate {
  url: string;
  confidence: number;
  source: ImageSource;
  width?: number;
  height?: number;
  alt?: string;
  className?: string;
  parentTag?: string;
}

export type ImageSource = 'img_tag' | 'srcset' | 'background' | 'meta_og' | 'meta_twitter' | 'json_ld' | 'data_attribute';

interface JsonLdObject {
  [key: string]: JsonLdValue;
}

type JsonLdValue = string | number | boolean | null | JsonLdObject | JsonLdValue[];

export interface DimensionRange {
  width: number;
  height: number;
}

export interface AspectRatioRange {
  min: number;
  max: number;
}

export interface AspectRatioWeight {
  min: number;
  max: number;
  weight: number;
}

export interface ParsedUrl {
  protocol: string;
  host: string;
  pathname: string;
  search: string;
  hash: string;
}

export interface ImageDetectionConfig {
  minConfidence: number;
  preferHighRes: boolean;
  minDimensions: DimensionRange;
  maxDimensions: DimensionRange;
  aspectRatioRange: AspectRatioRange;
  excludePatterns: string[];
  includePatterns: string[];
  prioritizeCoverKeywords: boolean;
}

const DEFAULT_CONFIG: ImageDetectionConfig = {
  minConfidence: 0.5,
  preferHighRes: true,
  minDimensions: { width: 100, height: 140 } as DimensionRange,
  maxDimensions: { width: 2000, height: 3000 } as DimensionRange,
  aspectRatioRange: { min: 0.5, max: 1.0 } as AspectRatioRange,
  excludePatterns: [
    'avatar', 'logo', 'icon', 'banner', 'header', 'footer',
    'button', 'sprite', 'loading', 'placeholder', 'ad', 'adv',
    'advertisement', 'sponsor', 'social', 'share', 'comment',
    'profile', 'user', 'thumb-up', 'like', 'star', 'rating',
    'search', 'menu', 'nav', 'sidebar', 'widget'
  ],
  includePatterns: [
    'cover', 'poster', 'book', 'jacket', 'thumbnail',
    'product', 'item', 'main', 'featured'
  ],
  prioritizeCoverKeywords: true
};

const COVER_KEYWORDS: string[] = [
  'cover', 'poster', 'jacket', 'bookcover', 'book-cover',
  'front', 'dustjacket', 'dust-jacket', '封面', '书皮'
];

const BOOK_COVER_ASPECT_RATIOS: AspectRatioWeight[] = [
  { min: 0.6, max: 0.75, weight: 1.0 } as AspectRatioWeight,
  { min: 0.55, max: 0.8, weight: 0.8 } as AspectRatioWeight,
  { min: 0.5, max: 0.85, weight: 0.6 } as AspectRatioWeight
];

export class ImageDetector {
  private config: ImageDetectionConfig;
  private readonly TAG = 'ImageDetector';

  constructor(config?: Partial<ImageDetectionConfig>) {
    this.config = this.mergeConfig(DEFAULT_CONFIG, config);
  }

  updateConfig(config: Partial<ImageDetectionConfig>): void {
    this.config = this.mergeConfig(this.config, config);
  }

  private mergeConfig(base: ImageDetectionConfig, update?: Partial<ImageDetectionConfig>): ImageDetectionConfig {
    if (!update) {
      return base;
    }
    const merged: ImageDetectionConfig = {
      minConfidence: update.minConfidence !== undefined ? update.minConfidence : base.minConfidence,
      preferHighRes: update.preferHighRes !== undefined ? update.preferHighRes : base.preferHighRes,
      minDimensions: update.minDimensions !== undefined ? update.minDimensions : base.minDimensions,
      maxDimensions: update.maxDimensions !== undefined ? update.maxDimensions : base.maxDimensions,
      aspectRatioRange: update.aspectRatioRange !== undefined ? update.aspectRatioRange : base.aspectRatioRange,
      excludePatterns: update.excludePatterns !== undefined ? update.excludePatterns : base.excludePatterns,
      includePatterns: update.includePatterns !== undefined ? update.includePatterns : base.includePatterns,
      prioritizeCoverKeywords: update.prioritizeCoverKeywords !== undefined ? update.prioritizeCoverKeywords : base.prioritizeCoverKeywords
    };
    return merged;
  }

  detectBookCoverImages(html: string, baseUrl: string): ImageCandidate[] {
    const candidates: ImageCandidate[] = [];

    candidates.push(...this.detectFromImgTags(html, baseUrl));
    candidates.push(...this.detectFromMetaTags(html, baseUrl));
    candidates.push(...this.detectFromSrcset(html, baseUrl));
    candidates.push(...this.detectFromBackgroundImages(html, baseUrl));
    candidates.push(...this.detectFromJsonLd(html, baseUrl));
    candidates.push(...this.detectFromDataAttributes(html, baseUrl));

    const scoredCandidates = candidates.map(c => {
      const scored: ImageCandidate = {
        url: c.url,
        confidence: this.calculateConfidence(c, html),
        source: c.source,
        width: c.width,
        height: c.height,
        alt: c.alt,
        className: c.className,
        parentTag: c.parentTag
      };
      return scored;
    });

    const filtered = scoredCandidates.filter(c => c.confidence >= this.config.minConfidence);
    const sorted = filtered.sort((a, b) => b.confidence - a.confidence);

    const unique = this.deduplicateCandidates(sorted);

    Logger.info(this.TAG, `Detected ${unique.length} book cover candidates from ${html.length} chars HTML`);

    return unique;
  }

  private detectFromImgTags(html: string, baseUrl: string): ImageCandidate[] {
    const candidates: ImageCandidate[] = [];
    const imgRegex = /<img\s+([^>]*?)\/?>/gi;
    let match: RegExpExecArray | null = null;

    while ((match = imgRegex.exec(html)) !== null) {
      const attributes = match[1];
      const metadata = this.parseImgAttributes(attributes);

      if (!metadata.src && !metadata['data-src']) continue;

      const src = metadata.src || metadata['data-src'] || '';
      const url = this.resolveUrl(baseUrl, src);

      if (!this.isValidImageUrl(url)) continue;

      candidates.push({
        url,
        confidence: 0,
        source: 'img_tag',
        width: metadata.width ? parseInt(metadata.width) : undefined,
        height: metadata.height ? parseInt(metadata.height) : undefined,
        alt: metadata.alt,
        className: metadata.class,
        parentTag: this.findParentTag(html, match.index)
      });
    }

    return candidates;
  }

  private detectFromMetaTags(html: string, baseUrl: string): ImageCandidate[] {
    const candidates: ImageCandidate[] = [];

    const ogImageRegex = /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i;
    const ogMatch = ogImageRegex.exec(html);
    if (ogMatch) {
      candidates.push({
        url: this.resolveUrl(baseUrl, ogMatch[1]),
        confidence: 0.9,
        source: 'meta_og'
      });
    }

    const twitterImageRegex = /<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i;
    const twitterMatch = twitterImageRegex.exec(html);
    if (twitterMatch) {
      candidates.push({
        url: this.resolveUrl(baseUrl, twitterMatch[1]),
        confidence: 0.85,
        source: 'meta_twitter'
      });
    }

    return candidates;
  }

  private detectFromSrcset(html: string, baseUrl: string): ImageCandidate[] {
    const candidates: ImageCandidate[] = [];
    const srcsetRegex = /srcset=["']([^"']+)["']/gi;
    let match: RegExpExecArray | null = null;

    while ((match = srcsetRegex.exec(html)) !== null) {
      const srcset = match[1];
      const sources: string[] = srcset.split(',');

      let bestUrl = '';
      let bestWidth = 0;

      for (const source of sources) {
        const parts: string[] = source.trim().split(/\s+/);
        const url = parts[0];
        const widthDescriptor = parts[1] || '';

        let width = 0;
        if (widthDescriptor.endsWith('w')) {
          width = parseInt(widthDescriptor);
        }

        if (this.config.preferHighRes && width > bestWidth) {
          bestWidth = width;
          bestUrl = url;
        } else if (!this.config.preferHighRes && !bestUrl) {
          bestUrl = url;
        }
      }

      if (bestUrl) {
        candidates.push({
          url: this.resolveUrl(baseUrl, bestUrl),
          confidence: 0.7,
          source: 'srcset',
          width: bestWidth || undefined
        });
      }
    }

    return candidates;
  }

  private detectFromBackgroundImages(html: string, baseUrl: string): ImageCandidate[] {
    const candidates: ImageCandidate[] = [];
    const bgImageRegex = /url\(["']?([^"')]+)["']?\)/gi;
    let match: RegExpExecArray | null = null;

    while ((match = bgImageRegex.exec(html)) !== null) {
      const url = match[1];

      if (!this.isValidImageUrl(url)) continue;

      const surroundingContext = html.substring(Math.max(0, match.index - 200), match.index + 200);
      const hasCoverContext = this.hasCoverContext(surroundingContext);

      candidates.push({
        url: this.resolveUrl(baseUrl, url),
        confidence: hasCoverContext ? 0.6 : 0.3,
        source: 'background'
      });
    }

    return candidates;
  }

  private detectFromJsonLd(html: string, baseUrl: string): ImageCandidate[] {
    const candidates: ImageCandidate[] = [];
    const jsonLdRegex = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
    let match: RegExpExecArray | null = null;

    while ((match = jsonLdRegex.exec(html)) !== null) {
      try {
        const jsonStr = match[1];
        const json: Record<string, JsonLdValue> = JSON.parse(jsonStr);

        const images = this.extractImagesFromJsonLd(json);
        for (const image of images) {
          candidates.push({
            url: this.resolveUrl(baseUrl, image),
            confidence: 0.8,
            source: 'json_ld'
          });
        }
      } catch (error) {
        // Invalid JSON, skip
      }
    }

    return candidates;
  }

  private extractImagesFromJsonLd(json: JsonLdObject): string[] {
    const images: string[] = [];

    const traverse = (obj: JsonLdObject | null) => {
      if (!obj || typeof obj !== 'object') return;

      if (Array.isArray(obj)) {
        obj.forEach((item: JsonLdValue) => {
          if (typeof item === 'object' && item !== null) {
            traverse(item as JsonLdObject);
          }
        });
        return;
      }

      const record = obj;

      if (record['@type'] === 'Book' || record['@type'] === 'Product') {
        if (record.image) {
          if (typeof record.image === 'string') {
            images.push(record.image);
          } else if (Array.isArray(record.image)) {
            record.image.forEach((img: JsonLdValue) => {
              if (typeof img === 'string') images.push(img);
            });
          } else if (typeof record.image === 'object' && record.image !== null) {
            const imgObj = record.image as JsonLdObject;
            if (typeof imgObj.url === 'string') images.push(imgObj.url);
          }
        }

        if (record.thumbnailUrl) {
          if (typeof record.thumbnailUrl === 'string') {
            images.push(record.thumbnailUrl);
          } else if (Array.isArray(record.thumbnailUrl)) {
            record.thumbnailUrl.forEach((url: JsonLdValue) => {
              if (typeof url === 'string') images.push(url);
            });
          }
        }
      }

      Object.values(record).forEach((value: JsonLdValue) => {
        if (typeof value === 'object' && value !== null) {
          traverse(value as JsonLdObject);
        }
      });
    };

    traverse(json);
    return images;
  }

  private detectFromDataAttributes(html: string, baseUrl: string): ImageCandidate[] {
    const candidates: ImageCandidate[] = [];
    const dataAttrRegex = /data-(?:src|image|cover|poster|original|lazy)["']?\s*=\s*["']([^"']+)["']/gi;
    let match: RegExpExecArray | null = null;

    while ((match = dataAttrRegex.exec(html)) !== null) {
      const url = match[1];

      if (!this.isValidImageUrl(url)) continue;

      candidates.push({
        url: this.resolveUrl(baseUrl, url),
        confidence: 0.65,
        source: 'data_attribute'
      });
    }

    return candidates;
  }

  private parseImgAttributes(attributes: string): Record<string, string> {
    const result: Record<string, string> = {};
    const attrRegex = /(\S+)\s*=\s*["']([^"']*)["']/g;
    let match: RegExpExecArray | null = null;

    while ((match = attrRegex.exec(attributes)) !== null) {
      result[match[1].toLowerCase()] = match[2];
    }

    return result;
  }

  private findParentTag(html: string, index: number): string | undefined {
    const before = html.substring(0, index);
    const tagMatches = before.match(/<(\w+)[^>]*>(?=[^<]*$)/);
    return tagMatches ? tagMatches[1].toLowerCase() : undefined;
  }

  private calculateConfidence(candidate: ImageCandidate, html: string): number {
    let score = 0;
    const url = candidate.url.toLowerCase();

    score += this.scoreByUrlPatterns(url);
    score += this.scoreBySource(candidate.source);
    score += this.scoreByDimensions(candidate);
    score += this.scoreByMetadata(candidate);
    score += this.scoreByContext(candidate, html);

    return Math.min(1, Math.max(0, score));
  }

  private scoreByUrlPatterns(url: string): number {
    let score = 0;

    for (const keyword of COVER_KEYWORDS) {
      if (url.includes(keyword)) {
        score += 0.3;
        break;
      }
    }

    for (const pattern of this.config.includePatterns) {
      if (url.includes(pattern)) {
        score += 0.15;
      }
    }

    for (const pattern of this.config.excludePatterns) {
      if (url.includes(pattern)) {
        score -= 0.25;
      }
    }

    if (url.includes('original') || url.includes('full') || url.includes('large')) {
      score += 0.1;
    }

    if (url.includes('thumb') || url.includes('small') || url.includes('mini')) {
      score -= 0.1;
    }

    return score;
  }

  private scoreBySource(source: ImageSource): number {
    const sourceScores: Record<ImageSource, number> = {
      'meta_og': 0.25,
      'json_ld': 0.2,
      'meta_twitter': 0.18,
      'img_tag': 0.15,
      'srcset': 0.12,
      'data_attribute': 0.1,
      'background': 0.05
    };
    return sourceScores[source] || 0;
  }

  private scoreByDimensions(candidate: ImageCandidate): number {
    let score = 0;

    if (candidate.width && candidate.height) {
      const aspectRatio = candidate.width / candidate.height;

      for (const range of BOOK_COVER_ASPECT_RATIOS) {
        if (aspectRatio >= range.min && aspectRatio <= range.max) {
          score += 0.2 * range.weight;
          break;
        }
      }

      if (candidate.width >= this.config.minDimensions.width &&
        candidate.height >= this.config.minDimensions.height) {
        score += 0.1;
      }

      if (this.config.preferHighRes && candidate.width >= 300 && candidate.height >= 400) {
        score += 0.1;
      }
    }

    return score;
  }

  private scoreByMetadata(candidate: ImageCandidate): number {
    let score = 0;

    if (candidate.alt) {
      const altLower = candidate.alt.toLowerCase();
      for (const keyword of COVER_KEYWORDS) {
        if (altLower.includes(keyword)) {
          score += 0.15;
          break;
        }
      }
    }

    if (candidate.className) {
      const classLower = candidate.className.toLowerCase();
      for (const keyword of COVER_KEYWORDS) {
        if (classLower.includes(keyword)) {
          score += 0.1;
          break;
        }
      }
    }

    if (candidate.parentTag) {
      const bookRelatedParents = ['figure', 'picture', 'article', 'book', 'product'];
      if (bookRelatedParents.includes(candidate.parentTag)) {
        score += 0.05;
      }
    }

    return score;
  }

  private scoreByContext(candidate: ImageCandidate, html: string): number {
    let score = 0;

    const urlIndex = html.toLowerCase().indexOf(candidate.url.toLowerCase());
    if (urlIndex > 0) {
      const context = html.substring(Math.max(0, urlIndex - 500), urlIndex + 500);

      if (this.hasCoverContext(context)) {
        score += 0.1;
      }

      if (context.includes('book') || context.includes('书籍') || context.includes('图书')) {
        score += 0.05;
      }
    }

    return score;
  }

  private hasCoverContext(context: string): boolean {
    const lowerContext = context.toLowerCase();
    return COVER_KEYWORDS.some(keyword => lowerContext.includes(keyword.toLowerCase()));
  }

  private isValidImageUrl(url: string): boolean {
    if (!url) return false;

    const lowerUrl = url.toLowerCase();

    if (lowerUrl.startsWith('data:image/')) return true;
    if (!lowerUrl.startsWith('http://') && !lowerUrl.startsWith('https://') &&
      !lowerUrl.startsWith('//')) {
      return false;
    }

    const imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'];
    const hasImageExtension = imageExtensions.some(ext => lowerUrl.includes(ext));

    if (hasImageExtension) return true;

    const imagePatterns = ['/image/', '/img/', '/cover/', '/photo/', '/pic/',
      'image=', 'img=', 'format=jpg', 'format=png'];
    return imagePatterns.some(pattern => lowerUrl.includes(pattern));
  }

  private deduplicateCandidates(candidates: ImageCandidate[]): ImageCandidate[] {
    const seen = new Map<string, ImageCandidate>();

    for (const candidate of candidates) {
      const normalizedUrl = this.normalizeUrl(candidate.url);

      if (!seen.has(normalizedUrl) || seen.get(normalizedUrl)!.confidence < candidate.confidence) {
        seen.set(normalizedUrl, candidate);
      }
    }

    return Array.from(seen.values());
  }

  private normalizeUrl(url: string): string {
    try {
      const parsed = this.parseUrl(url);
      const sortedParams = this.sortSearchParams(parsed.search);
      const normalized = parsed.protocol + '//' + parsed.host + parsed.pathname + sortedParams;
      return normalized.toLowerCase();
    } catch {
      return url.toLowerCase();
    }
  }

  private parseUrl(url: string): ParsedUrl {
    const protocolMatch = url.match(/^(https?:)\/\/([^\/]+)(\/[^?#]*)?(\?[^#]*)?(#.*)?$/i);
    if (!protocolMatch) {
      throw new Error('Invalid URL');
    }
    const result: ParsedUrl = {
      protocol: protocolMatch[1] || '',
      host: protocolMatch[2] || '',
      pathname: protocolMatch[3] || '',
      search: protocolMatch[4] || '',
      hash: protocolMatch[5] || ''
    };
    return result;
  }

  private sortSearchParams(search: string): string {
    if (!search || search.length <= 1) return '';
    const params = search.substring(1).split('&');
    params.sort();
    return '?' + params.join('&');
  }

  private resolveUrl(baseUrl: string, relativeUrl: string): string {
    if (!relativeUrl) return '';

    if (relativeUrl.startsWith('data:')) return relativeUrl;

    if (relativeUrl.startsWith('//')) {
      const base = this.parseUrl(baseUrl);
      return base.protocol + relativeUrl;
    }

    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }

    try {
      const base = this.parseUrl(baseUrl);

      if (relativeUrl.startsWith('/')) {
        return base.protocol + '//' + base.host + relativeUrl;
      }

      const basePath = base.pathname.substring(0, base.pathname.lastIndexOf('/') + 1);
      return base.protocol + '//' + base.host + basePath + relativeUrl;
    } catch {
      return relativeUrl;
    }
  }

  selectBestImage(candidates: ImageCandidate[]): ImageCandidate | null {
    if (candidates.length === 0) return null;

    const sorted = [...candidates].sort((a, b) => b.confidence - a.confidence);
    return sorted[0];
  }

  filterByDimensions(candidates: ImageCandidate[], minWidth: number, minHeight: number): ImageCandidate[] {
    return candidates.filter(c => {
      if (!c.width || !c.height) return true;
      return c.width >= minWidth && c.height >= minHeight;
    });
  }

  filterByAspectRatio(candidates: ImageCandidate[], minRatio: number, maxRatio: number): ImageCandidate[] {
    return candidates.filter(c => {
      if (!c.width || !c.height) return true;
      const ratio = c.width / c.height;
      return ratio >= minRatio && ratio <= maxRatio;
    });
  }
}
