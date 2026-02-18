export class TextCleaner {
  static clean(text: string): string {
    if (!text) {
      return '';
    }

    return text
      .replace(/\r\n/g, '\n')
      .replace(/\r/g, '\n')
      .replace(/\t/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  static cleanWhitespace(text: string): string {
    if (!text) {
      return '';
    }

    return text
      .replace(/[\u00A0\u1680\u180E\u2000-\u200B\u202F\u205F\u3000\uFEFF]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  static cleanLineBreaks(text: string): string {
    if (!text) {
      return '';
    }

    return text
      .replace(/\r\n/g, '\n')
      .replace(/\r/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  static cleanPunctuation(text: string): string {
    if (!text) {
      return '';
    }

    return text
      .replace(/[！!]+/g, '！')
      .replace(/[。.]+/g, '。')
      .replace(/[,，]+/g, '，')
      .replace(/[;；]+/g, '；')
      .replace(/[?？]+/g, '？')
      .replace(/[:：]+/g, '：');
  }

  static removeControlChars(text: string): string {
    if (!text) {
      return '';
    }

    return text.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
  }

  static normalizeQuotes(text: string): string {
    if (!text) {
      return '';
    }

    return text
      .replace(/[''′´`]/g, "'")
      .replace(/[""″«»]/g, '"');
  }

  static fullClean(text: string): string {
    if (!text) {
      return '';
    }

    let result = text;
    result = TextCleaner.removeControlChars(result);
    result = TextCleaner.cleanWhitespace(result);
    result = TextCleaner.cleanLineBreaks(result);
    result = TextCleaner.normalizeQuotes(result);
    result = TextCleaner.cleanPunctuation(result);

    return result.trim();
  }

  static truncate(text: string, maxLength: number, suffix: string = '...'): string {
    if (!text || text.length <= maxLength) {
      return text;
    }

    return text.substring(0, maxLength - suffix.length) + suffix;
  }

  static removeEmptyLines(text: string): string {
    if (!text) {
      return '';
    }

    const lines = text.split('\n');
    const nonEmptyLines: string[] = [];

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.length > 0) {
        nonEmptyLines.push(line);
      }
    }

    return nonEmptyLines.join('\n');
  }
}

export default TextCleaner;
