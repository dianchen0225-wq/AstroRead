/**
 * HtmlUtils - HTML 处理工具类
 * 整合 HTML 解码、清理、提取等通用功能
 */

import { cachedReplace } from "../cache/RegexCache";

/**
 * HTML 实体映射表
 */
const HTML_ENTITIES: Record<string, string> = {
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&apos;': "'",
  '&#39;': "'",
  '&nbsp;': ' ',
  '&hellip;': '…',
  '&mdash;': '—',
  '&ndash;': '–',
  '&ldquo;': '"',
  '&rdquo;': '"',
  '&lsquo;': '\'',
  '&rsquo;': '\'',
  '&bull;': '•',
  '&middot;': '·',
  '&copy;': '©',
  '&reg;': '®',
  '&trade;': '™',
  '&deg;': '°',
  '&plusmn;': '±',
  '&times;': '×',
  '&divide;': '÷',
  '&euro;': '€',
  '&pound;': '£',
  '&yen;': '¥',
  '&cent;': '¢',
  '&sect;': '§',
  '&para;': '¶',
  '&dagger;': '†',
  '&Dagger;': '‡',
  '&larr;': '←',
  '&rarr;': '→',
  '&uarr;': '↑',
  '&darr;': '↓',
  '&harr;': '↔',
  '&spades;': '♠',
  '&clubs;': '♣',
  '&hearts;': '♥',
  '&diams;': '♦'
};

/**
 * 危险的 HTML 标签（用于内容净化）
 * 增强XSS防护
 */
const DANGEROUS_TAGS = [
  'script', 'iframe', 'object', 'embed', 'applet', 'frame', 'frameset',
  'meta', 'link', 'style', 'base', 'form',
  'input', 'button', 'select', 'textarea', 'option', 'optgroup',
  'svg', 'math', 'video', 'audio', 'source', 'track',
  'canvas', 'portal', 'template', 'slot',
  'marquee', 'blink', 'isindex', 'keygen', 'listing', 'plaintext', 'xmp'
];

/**
 * 危险的 HTML 属性
 * 增强XSS防护
 */
const DANGEROUS_ATTRS = [
  // 事件处理器
  'onclick', 'ondblclick', 'onmousedown', 'onmouseup', 'onmouseover',
  'onmousemove', 'onmouseout', 'onmouseenter', 'onmouseleave',
  'onkeydown', 'onkeypress', 'onkeyup',
  'onfocus', 'onblur', 'onchange', 'onsubmit', 'onreset',
  'onload', 'onerror', 'onunload', 'onabort', 'onbeforeunload',
  'ondrag', 'ondragstart', 'ondragend', 'ondragenter', 'ondragleave', 'ondragover', 'ondrop',
  'onscroll', 'onresize', 'oncontextmenu', 'onwheel', 'onmousewheel',
  'onpointerdown', 'onpointerup', 'onpointermove', 'onpointerenter', 'onpointerleave',
  'ontouchstart', 'ontouchend', 'ontouchmove', 'ontouchcancel',
  'onanimationstart', 'onanimationend', 'onanimationiteration',
  'ontransitionstart', 'ontransitionend', 'ontransitionrun', 'ontransitioncancel',
  'onbeforecopy', 'onbeforecut', 'onbeforepaste', 'oncopy', 'oncut', 'onpaste',
  'onselect', 'onselectstart', 'onselectionchange',
  'onhashchange', 'onpopstate', 'onpageshow', 'onpagehide',
  // 危险属性
  'formaction', 'xlink:href', 'xmlns', 'xml:base', 'xml:lang', 'xml:space',
  'data-', 'form', 'ping', 'rel', 'target', 'action', 'method', 'enctype',
  'accept-charset', 'autocomplete', 'autofocus', 'checked', 'disabled',
  'formenctype', 'formmethod', 'formnovalidate', 'formtarget', 'maxlength',
  'multiple', 'name', 'novalidate', 'pattern', 'placeholder', 'readonly',
  'required', 'size', 'step', 'type', 'value', 'accesskey', 'contenteditable',
  'contextmenu', 'dir', 'draggable', 'dropzone', 'hidden', 'lang', 'spellcheck',
  'tabindex', 'translate', 'itemscope', 'itemtype', 'itemid', 'itemprop', 'itemref'
];

/**
 * 危险的URL协议
 */
const DANGEROUS_PROTOCOLS = [
  'javascript:', 'vbscript:', 'data:', 'file:', 'ftp:', 'telnet:', 'ssh:',
  'ldap:', 'ldaps:', 'mailto:', 'news:', 'nntp:', 'snews:', 'tel:', 'callto:',
  'wtai:', 'market:', 'itms:', 'itms-apps:', 'itms-services:', 'itms-booksservices:',
  'sms:', 'mms:', 'geo:', 'maps:', 'skype:', 'whatsapp:', 'facetime:', 'facetime-audio:',
  'x-apple-', 'x-safari-', 'chrome-extension:', 'moz-extension:', 'ms-browser-extension:'
];

/**
 * 允许的URL协议白名单
 */
const ALLOWED_PROTOCOLS = [
  'http:', 'https:', 'about:', 'blob:', 'filesystem:'
];

export class HtmlUtils {
  private static readonly TAG = 'HtmlUtils';

  /**
   * 解码 HTML 实体
   */
  static decodeHtmlEntities(text: string): string {
    if (!text) return '';

    let result = text;

    // 解码命名实体
    const entityKeys = Object.keys(HTML_ENTITIES);
    for (const entity of entityKeys) {
      result = result.split(entity).join(HTML_ENTITIES[entity]);
    }

    // 解码十进制数字实体 &#123;
    result = result.replace(/&#(\d+);/g, (match: string, dec: string) => {
      const code = parseInt(dec, 10);
      if (code > 0 && code < 0x110000) {
        return String.fromCodePoint(code);
      }
      return match;
    });

    // 解码十六进制数字实体 &#x7B;
    result = result.replace(/&#x([0-9a-fA-F]+);/g, (match: string, hex: string) => {
      const code = parseInt(hex, 16);
      if (code > 0 && code < 0x110000) {
        return String.fromCodePoint(code);
      }
      return match;
    });

    return result;
  }

  /**
   * 编码 HTML 特殊字符
   */
  static encodeHtml(text: string): string {
    if (!text) return '';

    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  /**
   * 移除 HTML 标签
   */
  static removeHtmlTags(html: string): string {
    if (!html) return '';
    return html.replace(/<[^>]*>/g, '');
  }

  /**
   * 提取纯文本内容
   */
  static extractText(html: string): string {
    if (!html) return '';

    let text = html;

    // 处理块级元素，添加换行
    text = text.replace(/<\/(p|div|br|li|tr|dt|dd|h[1-6])[^>]*>/gi, '\n');
    text = text.replace(/<br\s*\/?>/gi, '\n');

    // 移除所有标签
    text = text.replace(/<[^>]*>/g, '');

    // 解码 HTML 实体
    text = HtmlUtils.decodeHtmlEntities(text);

    // 清理多余空白
    text = text
      .replace(/[\r\n]+/g, '\n')
      .replace(/[ \t]+/g, ' ')
      .trim();

    return text;
  }

  /**
   * 净化 HTML 内容（移除危险标签和属性）
   * 增强XSS防护
   */
  static sanitizeHtml(html: string, options?: SanitizeOptions): string {
    if (!html) return '';

    const opts: SanitizeOptions = {
      allowTags: options?.allowTags ?? ['p', 'br', 'b', 'i', 'u', 'strong', 'em', 'span', 'div', 'a', 'img', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'blockquote'],
      allowAttrs: options?.allowAttrs ?? ['href', 'src', 'alt', 'title', 'class'],
      allowDataAttrs: options?.allowDataAttrs ?? false,
      removeComments: options?.removeComments ?? true
    };

    let result = html;

    // 移除注释
    if (opts.removeComments) {
      result = result.replace(/<!--[\s\S]*?-->/g, '');
    }

    // 移除 CDATA
    result = result.replace(/<!\[CDATA\[[\s\S]*?\]\]>/gi, '');

    // 移除 DOCTYPE
    result = result.replace(/<!DOCTYPE[^>]*>/gi, '');

    // 移除 XML 声明
    result = result.replace(/<\?xml[^>]*\?>/gi, '');

    // 移除危险标签及其内容（使用更严格的模式）
    for (const tag of DANGEROUS_TAGS) {
      // 匹配完整的标签对
      const regex = new RegExp(`<${tag}\\b[^>]*>[\\s\\S]*?<\\/${tag}>`, 'gi');
      result = result.replace(regex, '');
      // 自闭合标签
      const selfClosingRegex = new RegExp(`<${tag}\\b[^>]*\\/?>`, 'gi');
      result = result.replace(selfClosingRegex, '');
      // 处理大写标签
      const upperRegex = new RegExp(`<${tag.toUpperCase()}\\b[^>]*>[\\s\S]*?<\\/${tag.toUpperCase()}>`, 'gi');
      result = result.replace(upperRegex, '');
      const upperSelfClosingRegex = new RegExp(`<${tag.toUpperCase()}\\b[^>]*\\/?>`, 'gi');
      result = result.replace(upperSelfClosingRegex, '');
    }

    // 移除危险属性（使用更严格的模式）
    for (const attr of DANGEROUS_ATTRS) {
      // 匹配双引号属性
      const doubleQuoteRegex = new RegExp(`\\s${attr}\\s*=\\s*"[^"]*"`, 'gi');
      result = result.replace(doubleQuoteRegex, '');
      // 匹配单引号属性
      const singleQuoteRegex = new RegExp(`\\s${attr}\\s*=\\s'[^']*'`, 'gi');
      result = result.replace(singleQuoteRegex, '');
      // 匹配无引号属性
      const unquotedRegex = new RegExp(`\\s${attr}\\s*=\\s*[^\\s>]+`, 'gi');
      result = result.replace(unquotedRegex, '');
      // 匹配空属性
      const emptyRegex = new RegExp(`\\s${attr}\\b(?!\\s*=)`, 'gi');
      result = result.replace(emptyRegex, '');
    }

    // 移除所有危险协议
    for (const protocol of DANGEROUS_PROTOCOLS) {
      const protocolRegex = new RegExp(`\\s*(href|src|action|background|formaction|poster|cite|longdesc|profile|usemap)\\s*=\\s*["']?\\s*${protocol.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}[^"'>\\s]*`, 'gi');
      result = result.replace(protocolRegex, '');
    }

    // 移除 expression() 和 @import（CSS表达式）
    result = result.replace(/expression\s*\(/gi, '');
    result = result.replace(/@import\s+/gi, '');
    result = result.replace(/@charset\s+/gi, '');

    // 移除行为属性（IE的HTC行为）
    result = result.replace(/behavior\s*:\s*url\s*\(/gi, '');
    result = result.replace(/-moz-binding/gi, '');

    // 移除 CSS 中的 javascript: 和 data:
    result = result.replace(/url\s*\(\s*["']?\s*javascript:/gi, 'url(');
    result = result.replace(/url\s*\(\s*["']?\s*data:/gi, 'url(');

    // 如果指定了允许的标签，移除其他标签
    if (opts.allowTags && opts.allowTags.length > 0) {
      result = result.replace(/<\/?([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>/g, (match: string, tagName: string) => {
        const lowerTagName = tagName.toLowerCase();
        if (opts.allowTags!.includes(lowerTagName)) {
          // 对允许的标签进行属性过滤
          return HtmlUtils.sanitizeTagAttributes(match, lowerTagName, opts.allowAttrs!, opts.allowDataAttrs!);
        }
        return '';
      });
    }

    // 最后清理：移除任何剩余的危险字符
    result = result.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]/g, '');

    return result;
  }

  /**
   * 净化标签属性
   */
  private static sanitizeTagAttributes(
    tagHtml: string,
    tagName: string,
    allowAttrs: string[],
    allowDataAttrs: boolean
  ): string {
    // 提取标签名
    const tagMatch = tagHtml.match(/<\/?([a-zA-Z][a-zA-Z0-9]*)\b/);
    if (!tagMatch) return tagHtml;

    const isClosingTag = tagHtml.startsWith('</');
    if (isClosingTag) return tagHtml; // 闭合标签不需要处理属性

    // 提取属性
    const attrs: string[] = [];
    const attrRegex = /\s([a-zA-Z_:][a-zA-Z0-9_:\-]*)\s*(?:=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g;
    let attrMatch: RegExpExecArray | null;

    while ((attrMatch = attrRegex.exec(tagHtml)) !== null) {
      const attrName = attrMatch[1].toLowerCase();
      const attrValue = attrMatch[2] || attrMatch[3] || attrMatch[4] || '';

      // 检查是否是允许的属性
      if (allowAttrs.includes(attrName)) {
        // 对 href 和 src 进行额外的安全检查
        if ((attrName === 'href' || attrName === 'src') && attrValue) {
          const lowerValue = attrValue.toLowerCase().trim();
          // 检查危险协议
          let isDangerous = false;
          for (const protocol of DANGEROUS_PROTOCOLS) {
            if (lowerValue.startsWith(protocol)) {
              isDangerous = true;
              break;
            }
          }
          if (!isDangerous) {
            // 对属性值进行HTML编码
            const encodedValue = HtmlUtils.encodeHtmlAttribute(attrValue);
            attrs.push(`${attrName}="${encodedValue}"`);
          }
        } else {
          // 对其他属性值进行HTML编码
          const encodedValue = HtmlUtils.encodeHtmlAttribute(attrValue);
          attrs.push(`${attrName}="${encodedValue}"`);
        }
      } else if (allowDataAttrs && attrName.startsWith('data-')) {
        // 允许 data-* 属性
        const encodedValue = HtmlUtils.encodeHtmlAttribute(attrValue);
        attrs.push(`${attrName}="${encodedValue}"`);
      }
    }

    // 重建标签
    if (tagHtml.endsWith('/>')) {
      return `<${tagName}${attrs.length > 0 ? ' ' + attrs.join(' ') : ''} />`;
    }
    return `<${tagName}${attrs.length > 0 ? ' ' + attrs.join(' ') : ''}>`;
  }

  /**
   * 编码HTML属性值
   */
  private static encodeHtmlAttribute(value: string): string {
    if (!value) return '';
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#x27;')
      .replace(/\//g, '&#x2F;');
  }

  /**
   * 提取属性值
   */
  static extractAttribute(html: string, attrName: string): string | null {
    if (!html || !attrName) return null;

    const regex = new RegExp(`${attrName}\\s*=\\s*["']([^"']*)["']`, 'i');
    const match = html.match(regex);
    return match ? match[1] : null;
  }

  /**
   * 提取所有链接
   */
  static extractLinks(html: string, baseUrl?: string): LinkInfo[] {
    if (!html) return [];

    const links: LinkInfo[] = [];
    const regex = /<a[^>]+href\s*=\s*["']([^"']+)["'][^>]*>([^<]*)<\/a>/gi;

    let match: RegExpExecArray | null;
    while ((match = regex.exec(html)) !== null) {
      let href = match[1];
      const text = HtmlUtils.decodeHtmlEntities(match[2].trim());

      // 处理相对 URL
      if (baseUrl && href && !href.startsWith('http')) {
        href = HtmlUtils.resolveUrl(baseUrl, href);
      }

      if (href && !href.startsWith('javascript:')) {
        links.push({ href, text });
      }
    }

    return links;
  }

  /**
   * 提取所有图片
   */
  static extractImages(html: string, baseUrl?: string): ImageInfo[] {
    if (!html) return [];

    const images: ImageInfo[] = [];
    const regex = /<img[^>]+src\s*=\s*["']([^"']+)["'][^>]*>/gi;

    let match: RegExpExecArray | null;
    while ((match = regex.exec(html)) !== null) {
      let src = match[1];
      const alt = HtmlUtils.extractAttribute(match[0], 'alt') || '';
      const title = HtmlUtils.extractAttribute(match[0], 'title') || '';

      // 处理相对 URL
      if (baseUrl && src && !src.startsWith('http') && !src.startsWith('data:')) {
        src = HtmlUtils.resolveUrl(baseUrl, src);
      }

      if (src) {
        images.push({ src, alt, title });
      }
    }

    return images;
  }

  /**
   * 解析 meta 标签
   */
  static parseMetaTags(html: string): MetaTagInfo[] {
    if (!html) return [];

    const metas: MetaTagInfo[] = [];
    const regex = /<meta\s+([^>]+)>/gi;

    let match: RegExpExecArray | null;
    while ((match = regex.exec(html)) !== null) {
      const metaHtml = match[1];
      const name = HtmlUtils.extractAttribute(metaHtml, 'name') ||
                   HtmlUtils.extractAttribute(metaHtml, 'property');
      const content = HtmlUtils.extractAttribute(metaHtml, 'content');
      const charset = HtmlUtils.extractAttribute(metaHtml, 'charset');
      const httpEquiv = HtmlUtils.extractAttribute(metaHtml, 'http-equiv');

      if (name && content) {
        metas.push({ name, content });
      } else if (charset) {
        metas.push({ name: 'charset', content: charset });
      } else if (httpEquiv && content) {
        metas.push({ name: httpEquiv, content });
      }
    }

    return metas;
  }

  /**
   * 检测编码
   */
  static detectCharset(html: string, headers?: Record<string, string>): string | null {
    // 1. 从 Content-Type 头检测
    if (headers) {
      const contentType = headers['Content-Type'] || headers['content-type'];
      if (contentType) {
        const match = contentType.match(/charset=["']?([^;"'\s]+)["']?/i);
        if (match) {
          return HtmlUtils.normalizeCharset(match[1]);
        }
      }
    }

    // 2. 从 meta 标签检测
    const metas = HtmlUtils.parseMetaTags(html);
    for (const meta of metas) {
      if (meta.name === 'charset') {
        return HtmlUtils.normalizeCharset(meta.content);
      }
      if (meta.name.toLowerCase() === 'content-type' && meta.content.includes('charset=')) {
        const match = meta.content.match(/charset=([^;\s]+)/i);
        if (match) {
          return HtmlUtils.normalizeCharset(match[1]);
        }
      }
    }

    return null;
  }

  /**
   * 标准化编码名称
   */
  static normalizeCharset(charset: string): string {
    const charsetMap: Record<string, string> = {
      'utf8': 'utf-8',
      'gb2312': 'gbk',
      'gb_2312': 'gbk',
      'gb231280': 'gbk',
      'x-gbk': 'gbk',
      'iso-8859-1': 'latin1',
      'iso8859-1': 'latin1'
    };

    const normalized = charset.toLowerCase().trim();
    return charsetMap[normalized] || normalized;
  }

  /**
   * 解析 URL
   */
  static resolveUrl(baseUrl: string, relativeUrl: string): string {
    if (!relativeUrl) return '';
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }
    if (relativeUrl.startsWith('//')) {
      const protocol = baseUrl.startsWith('https') ? 'https:' : 'http:';
      return protocol + relativeUrl;
    }
    if (!baseUrl) return relativeUrl;

    try {
      const protocolEnd = baseUrl.indexOf('://');
      if (protocolEnd === -1) return relativeUrl;

      const protocol = baseUrl.substring(0, protocolEnd + 3);
      const hostStart = protocolEnd + 3;
      const pathStart = baseUrl.indexOf('/', hostStart);
      const host = pathStart === -1 ? baseUrl.substring(hostStart) : baseUrl.substring(hostStart, pathStart);

      if (relativeUrl.startsWith('/')) {
        return `${protocol}${host}${relativeUrl}`;
      }

      const path = pathStart === -1 ? '/' : baseUrl.substring(pathStart);
      const lastSlash = path.lastIndexOf('/');
      const basePath = lastSlash === -1 ? '/' : path.substring(0, lastSlash + 1);

      return `${protocol}${host}${basePath}${relativeUrl}`;
    } catch {
      return relativeUrl;
    }
  }

  /**
   * 清理文本（移除多余空白和特殊字符）
   */
  static cleanText(text: string): string {
    if (!text) return '';

    return text
      .replace(/[\r\n\t]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * 检查是否为有效的 HTML
   */
  static isValidHtml(text: string): boolean {
    if (!text) return false;
    // 检查是否包含 HTML 标签
    return /<[a-zA-Z][^>]*>/.test(text);
  }

  /**
   * 获取元素的文本内容
   */
  static getElementText(html: string): string {
    if (!html) return '';

    // 提取标签之间的文本
    const textMatch = html.match(/>([^<]*)</);
    if (textMatch) {
      return HtmlUtils.decodeHtmlEntities(textMatch[1].trim());
    }

    return '';
  }
}

// ========== 类型定义 ==========
export interface SanitizeOptions {
  allowTags?: string[];
  allowAttrs?: string[];
  allowDataAttrs?: boolean;
  removeComments?: boolean;
}

export interface LinkInfo {
  href: string;
  text: string;
}

export interface ImageInfo {
  src: string;
  alt: string;
  title: string;
}

export interface MetaTagInfo {
  name: string;
  content: string;
}

export default HtmlUtils;
