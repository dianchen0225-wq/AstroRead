export class EntityDecoder {
  private static readonly entities: Record<string, string> = {
    '&lt;': '<',
    '&gt;': '>',
    '&amp;': '&',
    '&quot;': '"',
    '&apos;': "'",
    '&nbsp;': ' ',
    '&copy;': '©',
    '&reg;': '®',
    '&trade;': '™',
    '&mdash;': '—',
    '&ndash;': '–',
    '&hellip;': '\u2026',
    '&lsquo;': '\u2018',
    '&rsquo;': '\u2019',
    '&ldquo;': '\u201C',
    '&rdquo;': '\u201D',
    '&#39;': "'"
  };

  static decode(text: string): string {
    if (!text) {
      return '';
    }

    let result = text;

    const entityEntries = Object.entries(EntityDecoder.entities);
    for (let i = 0; i < entityEntries.length; i++) {
      const entity = entityEntries[i][0];
      const char = entityEntries[i][1];
      result = result.replace(new RegExp(entity, 'gi'), char);
    }

    result = result.replace(/&#(\d+);/g, (_match: string, code: string): string => {
      return String.fromCharCode(parseInt(code, 10));
    });

    result = result.replace(/&#x([0-9a-fA-F]+);/g, (_match: string, code: string): string => {
      return String.fromCharCode(parseInt(code, 16));
    });

    return result;
  }

  static encode(text: string): string {
    if (!text) {
      return '';
    }

    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }

  static decodeNumeric(text: string): string {
    if (!text) {
      return '';
    }

    let result = text;

    result = result.replace(/&#(\d+);/g, (_match: string, code: string): string => {
      return String.fromCharCode(parseInt(code, 10));
    });

    result = result.replace(/&#x([0-9a-fA-F]+);/g, (_match: string, code: string): string => {
      return String.fromCharCode(parseInt(code, 16));
    });

    return result;
  }

  static stripTags(text: string): string {
    if (!text) {
      return '';
    }

    return text
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '')
      .replace(/<!--[\s\S]*?-->/g, '')
      .replace(/<[^>]+>/g, '');
  }

  static cleanHtml(text: string): string {
    if (!text) {
      return '';
    }

    let result = EntityDecoder.stripTags(text);
    result = EntityDecoder.decode(result);
    result = result.replace(/\s+/g, ' ').trim();

    return result;
  }
}

export default EntityDecoder;
