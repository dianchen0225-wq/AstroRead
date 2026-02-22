/**
 * HTML工具类
 * 提供HTML解析相关的通用函数
 */

export class HtmlUtils {
  private static readonly HTML_ENTITIES: Record<string, string> = {
    // 基础实体
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&#x27;': "'",
    '&nbsp;': ' ',
    '&#160;': ' ',
    // 中文标点
    '&hellip;': '…',
    '&#8230;': '…',
    // 破折号和连字符
    '&mdash;': '—',
    '&#8212;': '—',
    '&ndash;': '–',
    '&#8211;': '–',
    // 引号
    '&ldquo;': '"',
    '&#8220;': '"',
    '&rdquo;': '"',
    '&#8221;': '"',
    '&lsquo;': "'",
    '&#8216;': "'",
    '&rsquo;': "'",
    '&#8217;': "'",
    // 其他常用实体
    '&copy;': '©',
    '&#169;': '©',
    '&reg;': '®',
    '&#174;': '®',
    '&trade;': '™',
    '&#8482;': '™',
    '&yen;': '¥',
    '&#165;': '¥',
    '&euro;': '€',
    '&#8364;': '€',
    // 数学符号
    '&times;': '×',
    '&#215;': '×',
    '&divide;': '÷',
    '&#247;': '÷',
    '&plusmn;': '±',
    '&#177;': '±',
    // 箭头
    '&larr;': '←',
    '&#8592;': '←',
    '&uarr;': '↑',
    '&#8593;': '↑',
    '&rarr;': '→',
    '&#8594;': '→',
    '&darr;': '↓',
    '&#8595;': '↓',
  };

  /**
   * 解码HTML实体
   */
  static decodeHtmlEntities(text: string): string {
    if (!text) return '';

    let result = text;
    
    // 处理命名实体
    const entityKeys = Object.keys(this.HTML_ENTITIES);
    for (const entity of entityKeys) {
      result = result.split(entity).join(this.HTML_ENTITIES[entity]);
    }

    // 处理十进制数字实体 &#123;
    result = result.replace(/&#(\d+);/g, (match: string, dec: string) => {
      const code = parseInt(dec, 10);
      if (!isNaN(code) && code > 0 && code < 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return match;
    });

    // 处理十六进制数字实体 &#x7B;
    result = result.replace(/&#x([0-9a-fA-F]+);/g, (match: string, hex: string) => {
      const code = parseInt(hex, 16);
      if (!isNaN(code) && code > 0 && code < 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return match;
    });

    return result;
  }

  /**
   * 清理HTML标签，提取纯文本
   */
  static extractText(html: string): string {
    if (!html) return '';
    
    let text = html;
    
    // 移除 script/style
    text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
    
    // 替换 br 为换行
    text = text.replace(/<br\s*\/?>/gi, '\n');
    text = text.replace(/<p[^>]*>/gi, '\n');
    text = text.replace(/<\/p>/gi, '');
    
    // 移除所有HTML标签
    text = text.replace(/<[^>]+>/g, '');
    
    // 解码HTML实体
    text = this.decodeHtmlEntities(text);
    
    // 清理空白
    text = text.replace(/\s+/g, ' ').trim();
    
    return text;
  }

  /**
   * 清理文本中的特殊字符
   */
  static cleanText(text: string): string {
    if (!text) return '';
    return text
      .replace(/[\n\r\t]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * 转义正则表达式特殊字符
   */
  static escapeRegex(text: string): string {
    return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  /**
   * 解析相对URL为绝对URL
   */
  static resolveUrl(base: string, relative: string): string {
    if (!relative) return '';
    if (relative.startsWith('http')) return relative;
    if (relative.startsWith('//')) return 'https:' + relative;
    
    try {
      const baseUrl = new URL(base);
      
      if (relative.startsWith('/')) {
        return `${baseUrl.protocol}//${baseUrl.host}${relative}`;
      }
      
      const basePath = baseUrl.pathname.split('/').slice(0, -1).join('/') + '/';
      return `${baseUrl.protocol}//${baseUrl.host}${basePath}${relative}`;
    } catch {
      // 简单拼接
      if (base.endsWith('/')) {
        return base + relative;
      }
      return base + '/' + relative;
    }
  }

  /**
   * 基于简单选择器提取元素
   * 支持 tag#id.class 格式
   */
  static selectElements(html: string, selector: string): string[] {
    if (!html || !selector) return [];
    
    const elements: string[] = [];
    
    // 解析选择器
    const tagMatch = selector.match(/^([a-zA-Z0-9]+)/);
    const idMatch = selector.match(/#([a-zA-Z0-9_-]+)/);
    const classMatch = selector.match(/\.([a-zA-Z0-9_-]+)/);
    
    const tag = tagMatch ? tagMatch[1] : '';
    const id = idMatch ? idMatch[1] : '';
    const className = classMatch ? classMatch[1] : '';
    
    // 构建正则表达式
    let pattern = '';
    if (tag) {
      pattern += `<${tag}[^>]*`;
    } else {
      pattern += `<[^>]*`;
    }
    
    if (id) {
      pattern += `[^>]*id=["']${this.escapeRegex(id)}["']`;
    }
    
    if (className) {
      pattern += `[^>]*class=["'][^"']*${this.escapeRegex(className)}[^"']*["']`;
    }
    
    pattern += '[^>]*>';
    
    const regex = new RegExp(pattern, 'gi');
    let match;
    
    while ((match = regex.exec(html)) !== null) {
      const startIndex = match.index;
      const endIndex = this.findElementEnd(html, startIndex, tag || '');
      if (endIndex > startIndex) {
        elements.push(html.substring(startIndex, endIndex));
      }
    }
    
    return elements;
  }

  /**
   * 查找元素结束位置
   */
  private static findElementEnd(html: string, startIndex: number, tag: string): number {
    if (!tag) {
      // 找到下一个 <
      const nextTag = html.indexOf('<', startIndex + 1);
      return nextTag > 0 ? nextTag : html.length;
    }
    
    const openTag = `<${tag}`;
    const closeTag = `</${tag}>`;
    let depth = 1;
    let pos = startIndex + openTag.length;
    
    while (depth > 0 && pos < html.length) {
      const nextOpen = html.indexOf(openTag, pos);
      const nextClose = html.indexOf(closeTag, pos);
      
      if (nextClose === -1) break;
      
      if (nextOpen !== -1 && nextOpen < nextClose) {
        depth++;
        pos = nextOpen + openTag.length;
      } else {
        depth--;
        if (depth === 0) {
          return nextClose + closeTag.length;
        }
        pos = nextClose + closeTag.length;
      }
    }
    
    return html.length;
  }
}
