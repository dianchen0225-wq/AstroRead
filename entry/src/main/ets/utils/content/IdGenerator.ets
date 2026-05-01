/**
 * ID生成器
 */
export class IdGenerator {
  /**
   * 生成UUID
   */
  static generateUUID(): string {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }

  /**
   * 生成简单ID（基于时间戳）
   */
  static generateSimpleId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 基于书源ID和书籍URL生成书籍ID
   */
  static generateBookId(sourceId: string, bookUrl: string): string {
    const input = `${sourceId}_${bookUrl || ''}`;
    return IdGenerator.generateSimpleId();
  }

  /**
   * 基于书籍ID和章节URL生成章节ID
   */
  static generateChapterId(bookId: string, chapterUrl: string): string {
    return `ch_${bookId}_${IdGenerator.generateSimpleId()}`;
  }

  /**
   * 基于内容生成唯一哈希
   */
  static generateContentHash(content: string): string {
    let hash = 0;
    for (let i = 0; i < Math.min(content.length, 1000); i++) {
      const char = content.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash).toString(36);
  }
}
