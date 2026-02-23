/**
 * ResponseParser - 响应解析器
 * 负责解析HTTP响应数据和响应头
 * 包含自动编码检测功能
 */

import {
  HttpRequestConfig,
  HttpResponse,
  HttpHeaders
} from './interfaces/IHttpClient';
import { ConfigManager } from './HttpClientConfig';
import { util } from '@kit.ArkTS';

/**
 * 响应解析器
 */
export class ResponseParser {
  private static readonly CHARSET_MAP: Record<string, string> = {
    'utf8': 'utf-8',
    'gb2312': 'gbk',
    'gb_2312': 'gbk',
    'gb231280': 'gbk',
    'x-gbk': 'gbk',
    'iso-8859-1': 'latin1',
    'iso8859-1': 'latin1'
  };

  private static readonly FALLBACK_ENCODINGS: string[] = ['utf-8', 'gbk', 'gb2312', 'gb18030', 'big5'];

  /**
   * 解析响应数据
   */
  static parseResponseData<T>(
    data: string | ArrayBuffer,
    config: HttpRequestConfig
  ): T {
    const responseType = config.responseType?.type ?? 'text';

    if (responseType === 'json') {
      try {
        if (typeof data === 'string') {
          return JSON.parse(data) as T;
        }
        return data as T;
      } catch {
        return data as T;
      }
    }

    return data as T;
  }

  /**
   * 解码ArrayBuffer响应，自动检测编码
   */
  static decodeArrayBuffer(arrayBuffer: ArrayBuffer, headers: Record<string, string>): string {
    const uint8Data = new Uint8Array(arrayBuffer);

    const charsetFromHeader = ResponseParser.detectCharsetFromHeader(headers);
    if (charsetFromHeader) {
      try {
        const decoder = util.TextDecoder.create(charsetFromHeader, { ignoreBOM: true });
        const text = decoder.decodeToString(uint8Data);
        if (ResponseParser.isValidDecodedContent(text)) {
          return text;
        }
      } catch {
        // 编码解码失败，尝试其他编码
      }
    }

    const charsetFromContent = ResponseParser.detectCharsetFromContent(uint8Data);
    if (charsetFromContent && charsetFromContent !== charsetFromHeader) {
      try {
        const decoder = util.TextDecoder.create(charsetFromContent, { ignoreBOM: true });
        const text = decoder.decodeToString(uint8Data);
        if (ResponseParser.isValidDecodedContent(text)) {
          return text;
        }
      } catch {
        // 编码解码失败，尝试其他编码
      }
    }

    for (const encoding of ResponseParser.FALLBACK_ENCODINGS) {
      if (encoding === charsetFromHeader || encoding === charsetFromContent) {
        continue;
      }
      try {
        const decoder = util.TextDecoder.create(encoding, { ignoreBOM: true });
        const text = decoder.decodeToString(uint8Data);
        if (ResponseParser.isValidDecodedContent(text)) {
          return text;
        }
      } catch {
        continue;
      }
    }

    try {
      const defaultDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      return defaultDecoder.decodeToString(uint8Data);
    } catch {
      return '';
    }
  }

  /**
   * 从响应头检测编码
   */
  private static detectCharsetFromHeader(headers: Record<string, string>): string | null {
    const contentType = ResponseParser.getHeaderValue(headers, 'Content-Type');
    if (!contentType) {
      return null;
    }

    const charsetMatch = contentType.match(/charset=["']?([^;"'\s]+)["']?/i);
    if (charsetMatch) {
      return ResponseParser.normalizeCharset(charsetMatch[1].toLowerCase());
    }
    return null;
  }

  /**
   * 从内容检测编码（检查 meta 标签）
   */
  private static detectCharsetFromContent(uint8Data: Uint8Array): string | null {
    try {
      const asciiDecoder = util.TextDecoder.create('ascii', { ignoreBOM: true });
      const preview = asciiDecoder.decodeToString(uint8Data.slice(0, 1024));

      const metaCharsetMatch = preview.match(/<meta[^>]+charset=["']?([^"'\s>]+)["']?/i);
      if (metaCharsetMatch) {
        return ResponseParser.normalizeCharset(metaCharsetMatch[1].toLowerCase());
      }

      const contentTypeMatch = preview.match(/<meta[^>]+content=["'][^"']*charset=([^"'\s;]+)/i);
      if (contentTypeMatch) {
        return ResponseParser.normalizeCharset(contentTypeMatch[1].toLowerCase());
      }
    } catch {
      // 忽略错误
    }
    return null;
  }

  /**
   * 标准化编码名称
   */
  private static normalizeCharset(charset: string): string {
    const normalized = charset.toLowerCase().trim();
    return ResponseParser.CHARSET_MAP[normalized] || normalized;
  }

  /**
   * 检查解码后的内容是否有效（无乱码）
   */
  private static isValidDecodedContent(content: string): boolean {
    const replacementChar = '\uFFFD';
    const replacementCount = (content.match(new RegExp(replacementChar, 'g')) || []).length;
    const ratio = replacementCount / content.length;
    return ratio < 0.01;
  }

  /**
   * 获取响应头值（忽略大小写）
   */
  private static getHeaderValue(headers: Record<string, string>, key: string): string | undefined {
    const keys = Object.keys(headers);
    for (const k of keys) {
      if (k.toLowerCase() === key.toLowerCase()) {
        return headers[k];
      }
    }
    return undefined;
  }

  /**
   * 解析响应头
   */
  static parseResponseHeaders(header: Record<string, string>): HttpHeaders {
    const result: HttpHeaders = {};

    // 常用响应头映射
    const headerMappings: Record<string, keyof HttpHeaders> = {
      'content-type': 'Content-Type',
      'cache-control': 'Cache-Control',
      'set-cookie': 'Set-Cookie',
      'user-agent': 'UserAgent',
      'authorization': 'Authorization'
    };
    const entries = Object.entries(header);
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const key = entry[0];
      const value = entry[1];
      const normalizedKey = key.toLowerCase();
      const mappedKey = headerMappings[normalizedKey];
      
      if (mappedKey) {
        result[mappedKey] = value;
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  /**
   * 创建响应对象
   */
  static createResponse<T>(
    data: T,
    status: number,
    headers: HttpHeaders,
    config: HttpRequestConfig,
    duration: number,
    cached: boolean = false,
    retries: number = 0
  ): HttpResponse<T> {
    return {
      data,
      status,
      statusText: ConfigManager.getStatusText(status),
      headers,
      config,
      duration,
      cached,
      retries
    };
  }

  /**
   * 估算数据大小
   */
  static estimateSize(data: ESObject): number {
    if (typeof data === 'string') {
      return data.length;
    }
    if (data instanceof ArrayBuffer) {
      return data.byteLength;
    }
    if (typeof data === 'object' && data !== null) {
      return JSON.stringify(data).length;
    }
    return 0;
  }

  /**
   * 提取Set-Cookie头
   */
  static extractSetCookie(headers: HttpHeaders): string | undefined {
    return headers['Set-Cookie'];
  }
}

export default ResponseParser;