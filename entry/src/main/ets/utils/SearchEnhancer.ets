import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { Logger } from './Logger';

interface MatchedBook {
  book: Book;
  score: number;
  matchType: string;
}

interface BookWithSource extends Book {
  bookSourceId: string;
  bookSourceName: string;
}

interface FuzzyMatchConfig {
  enablePinyin: boolean;
  enablePartialMatch: boolean;
  enableInitialsMatch: boolean;
  minScore: number;
  maxResults: number;
}

interface FieldMatchResult {
  score: number;
  matchType: string;
}

interface ScoreDetails {
  score: number;
  matchType: string;
}

const DEFAULT_FUZZY_CONFIG: FuzzyMatchConfig = {
  enablePinyin: true,
  enablePartialMatch: true,
  enableInitialsMatch: true,
  minScore: 0.3,
  maxResults: 50
};

class SearchEnhancer {
  
  private TAG: string = 'SearchEnhancer';
  
  searchBooks(books: Array<Book>, keyword: string, source?: BookSource, config?: FuzzyMatchConfig): Array<Book> {
    const actualConfig: FuzzyMatchConfig = config || DEFAULT_FUZZY_CONFIG;
    
    if (!books || books.length === 0 || !keyword || keyword.trim().length === 0) {
      return [];
    }
    
    const trimmedKeyword = keyword.trim().toLowerCase();
    const matchedBooks: Array<MatchedBook> = [];
    
    Logger.debug(this.TAG, `开始模糊搜索: "${trimmedKeyword}", 书籍数量: ${books.length}`);
    
    for (let i = 0; i < books.length; i++) {
      const book = books[i];
      const result = this.calculateMatchScoreWithDetails(book, trimmedKeyword, source, actualConfig);
      if (result.score >= actualConfig.minScore) {
        const matchedBook: MatchedBook = { 
          book: book, 
          score: result.score,
          matchType: result.matchType
        };
        matchedBooks.push(matchedBook);
      }
    }
    
    matchedBooks.sort((a: MatchedBook, b: MatchedBook) => b.score - a.score);
    
    const limitedResults = matchedBooks.slice(0, actualConfig.maxResults);
    Logger.debug(this.TAG, `搜索"${keyword}"匹配到${limitedResults.length}本书`);
    
    const resultBooks: Array<Book> = [];
    for (let i = 0; i < limitedResults.length; i++) {
      resultBooks.push(limitedResults[i].book);
    }
    return resultBooks;
  }
  
  private calculateMatchScoreWithDetails(book: Book, keyword: string, source?: BookSource, config?: FuzzyMatchConfig): ScoreDetails {
    let score = 0;
    let matchType = 'none';
    const actualConfig: FuzzyMatchConfig = config || DEFAULT_FUZZY_CONFIG;
    
    if (book.name) {
      const nameResult = this.calculateFieldMatch(book.name.toLowerCase(), keyword, actualConfig);
      if (nameResult.score > 0) {
        score += nameResult.score * 0.6;
        matchType = nameResult.matchType;
      }
    }
    
    if (book.author) {
      const authorResult = this.calculateFieldMatch(book.author.toLowerCase(), keyword, actualConfig);
      if (authorResult.score > 0) {
        score += authorResult.score * 0.25;
        if (matchType === 'none') {
          matchType = `author_${authorResult.matchType}`;
        }
      }
    }
    
    if (book.intro) {
      const introScore = this.calculateFieldMatch(book.intro.toLowerCase(), keyword, actualConfig).score;
      score += introScore * 0.1;
    }
    
    if (book.kind) {
      const kindScore = this.calculateFieldMatch(book.kind.toLowerCase(), keyword, actualConfig).score;
      score += kindScore * 0.05;
    }
    
    if (source) {
      const sourceWeight = this.calculateSourceWeight(source);
      score *= sourceWeight;
    }
    
    const result: ScoreDetails = { score: score, matchType: matchType };
    return result;
  }
  
  private calculateFieldMatch(text: string, keyword: string, config: FuzzyMatchConfig): FieldMatchResult {
    if (!text || !keyword) {
      const noResult: FieldMatchResult = { score: 0, matchType: 'none' };
      return noResult;
    }
    
    if (text === keyword) {
      const exactResult: FieldMatchResult = { score: 1.0, matchType: 'exact' };
      return exactResult;
    }
    
    if (text.includes(keyword)) {
      const position = text.indexOf(keyword);
      const positionBonus = position === 0 ? 0.1 : 0;
      const containsResult: FieldMatchResult = { score: 0.85 + positionBonus, matchType: 'contains' };
      return containsResult;
    }
    
    if (keyword.length >= 2) {
      const words = keyword.split(/\s+/).filter((w: string) => w.length > 0);
      if (words.length > 1) {
        let matchCount = 0;
        for (let i = 0; i < words.length; i++) {
          if (text.includes(words[i])) {
            matchCount++;
          }
        }
        if (matchCount > 0) {
          const multiResult: FieldMatchResult = { score: (matchCount / words.length) * 0.7, matchType: 'multi_word' };
          return multiResult;
        }
      }
    }
    
    if (config.enablePartialMatch) {
      const partialScore = this.calculatePartialMatchScore(text, keyword);
      if (partialScore > 0.5) {
        const partialResult: FieldMatchResult = { score: partialScore * 0.6, matchType: 'partial' };
        return partialResult;
      }
    }
    
    if (config.enablePinyin) {
      const pinyinScore = this.calculatePinyinMatchScore(text, keyword);
      if (pinyinScore > 0.5) {
        const pinyinResult: FieldMatchResult = { score: pinyinScore * 0.5, matchType: 'pinyin' };
        return pinyinResult;
      }
    }
    
    if (config.enableInitialsMatch) {
      const initialsScore = this.calculateInitialsMatchScore(text, keyword);
      if (initialsScore > 0.5) {
        const initialsResult: FieldMatchResult = { score: initialsScore * 0.4, matchType: 'initials' };
        return initialsResult;
      }
    }
    
    const fuzzyScore = this.calculateFuzzyMatchScore(text, keyword);
    if (fuzzyScore > 0.6) {
      const fuzzyResult: FieldMatchResult = { score: fuzzyScore * 0.35, matchType: 'fuzzy' };
      return fuzzyResult;
    }
    
    const noMatchResult: FieldMatchResult = { score: 0, matchType: 'none' };
    return noMatchResult;
  }
  
  private calculatePartialMatchScore(text: string, keyword: string): number {
    if (keyword.length < 2) return 0;
    
    let maxScore = 0;
    const minLen = Math.min(3, keyword.length);
    
    for (let len = minLen; len <= keyword.length; len++) {
      for (let i = 0; i <= keyword.length - len; i++) {
        const subPart = keyword.substring(i, i + len);
        if (text.includes(subPart)) {
          const score = len / keyword.length;
          maxScore = Math.max(maxScore, score);
        }
      }
    }
    
    return maxScore;
  }
  
  private calculatePinyinMatchScore(text: string, keyword: string): number {
    const textPinyin = this.convertToPinyin(text);
    const keywordLower = keyword.toLowerCase();
    
    if (textPinyin.includes(keywordLower)) {
      return 0.9;
    }
    
    const textPinyinNoSpace = textPinyin.replace(/\s+/g, '');
    if (textPinyinNoSpace.includes(keywordLower)) {
      return 0.85;
    }
    
    return 0;
  }
  
  private calculateInitialsMatchScore(text: string, keyword: string): number {
    const initials = this.getInitials(text);
    const keywordUpper = keyword.toUpperCase();
    
    if (initials === keywordUpper) {
      return 1.0;
    }
    
    if (initials.includes(keywordUpper)) {
      return 0.8;
    }
    
    return 0;
  }
  
  private convertToPinyin(text: string): string {
    let result = '';
    for (let i = 0; i < text.length; i++) {
      const char = text.charAt(i);
      const pinyin = this.getPinyin(char);
      if (pinyin.length > 0) {
        result += pinyin + ' ';
      } else if (/[a-zA-Z0-9]/.test(char)) {
        result += char.toLowerCase();
      }
    }
    return result.trim();
  }
  
  private getPinyin(char: string): string {
    if (char === '啊' || char === '阿') return 'a';
    if (char === '爱') return 'ai';
    if (char === '安' || char === '按') return 'an';
    if (char === '吧' || char === '把') return 'ba';
    if (char === '被') return 'bei';
    if (char === '本') return 'ben';
    if (char === '不') return 'bu';
    if (char === '才') return 'cai';
    if (char === '从') return 'cong';
    if (char === '错') return 'cuo';
    if (char === '大') return 'da';
    if (char === '到') return 'dao';
    if (char === '的' || char === '地' || char === '得') return 'de';
    if (char === '儿') return 'er';
    if (char === '发') return 'fa';
    if (char === '方') return 'fang';
    if (char === '分') return 'fen';
    if (char === '风') return 'feng';
    if (char === '个') return 'ge';
    if (char === '给') return 'gei';
    if (char === '更') return 'geng';
    if (char === '工') return 'gong';
    if (char === '过') return 'guo';
    if (char === '还') return 'hai';
    if (char === '好') return 'hao';
    if (char === '和') return 'he';
    if (char === '很') return 'hen';
    if (char === '会') return 'hui';
    if (char === '几') return 'ji';
    if (char === '家') return 'jia';
    if (char === '见') return 'jian';
    if (char === '叫') return 'jiao';
    if (char === '就') return 'jiu';
    if (char === '可') return 'ke';
    if (char === '看') return 'kan';
    if (char === '空') return 'kong';
    if (char === '了') return 'le';
    if (char === '来') return 'lai';
    if (char === '老') return 'lao';
    if (char === '里') return 'li';
    if (char === '两') return 'liang';
    if (char === '吗') return 'ma';
    if (char === '没') return 'mei';
    if (char === '们') return 'men';
    if (char === '名') return 'ming';
    if (char === '那') return 'na';
    if (char === '你') return 'ni';
    if (char === '年') return 'nian';
    if (char === '能') return 'neng';
    if (char === '哦') return 'o';
    if (char === '平') return 'ping';
    if (char === '去') return 'qu';
    if (char === '人') return 'ren';
    if (char === '日') return 'ri';
    if (char === '上') return 'shang';
    if (char === '谁') return 'shei';
    if (char === '什') return 'shen';
    if (char === '生') return 'sheng';
    if (char === '时') return 'shi';
    if (char === '他' || char === '她' || char === '它') return 'ta';
    if (char === '天') return 'tian';
    if (char === '听') return 'ting';
    if (char === '为') return 'wei';
    if (char === '我') return 'wo';
    if (char === '无') return 'wu';
    if (char === '下') return 'xia';
    if (char === '想') return 'xiang';
    if (char === '小') return 'xiao';
    if (char === '些') return 'xie';
    if (char === '学') return 'xue';
    if (char === '一') return 'yi';
    if (char === '有' || char === '又') return 'you';
    if (char === '与') return 'yu';
    if (char === '元') return 'yuan';
    if (char === '在') return 'zai';
    if (char === '这') return 'zhe';
    if (char === '中') return 'zhong';
    if (char === '主') return 'zhu';
    if (char === '作') return 'zuo';
    return '';
  }
  
  private getInitials(text: string): string {
    let initials = '';
    for (let i = 0; i < text.length; i++) {
      const char = text.charAt(i);
      const pinyin = this.getPinyin(char);
      if (pinyin.length > 0) {
        initials += pinyin.charAt(0).toUpperCase();
      } else if (/[a-zA-Z]/.test(char)) {
        initials += char.toUpperCase();
      }
    }
    return initials;
  }
  
  private calculateSourceWeight(source: BookSource): number {
    const baseWeight = 1.0;
    const sortBonus = source.sort ? source.sort / 100 : 0;
    const enabledBonus = source.enabled ? 0.2 : 0;
    return baseWeight + sortBonus + enabledBonus;
  }
  
  private calculateFuzzyMatchScore(text: string, keyword: string): number {
    const distance = this.calculateLevenshteinDistance(text, keyword);
    const maxLength = Math.max(text.length, keyword.length);
    
    if (maxLength === 0) return 1.0;
    
    return 1.0 - distance / maxLength;
  }
  
  private calculateLevenshteinDistance(str1: string, str2: string): number {
    const matrix: number[][] = [];
    
    for (let i = 0; i <= str2.length; i++) {
      matrix[i] = [i];
    }
    
    for (let j = 0; j <= str1.length; j++) {
      matrix[0][j] = j;
    }
    
    for (let i = 1; i <= str2.length; i++) {
      for (let j = 1; j <= str1.length; j++) {
        if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
          matrix[i][j] = matrix[i - 1][j - 1];
        } else {
          matrix[i][j] = Math.min(
            matrix[i - 1][j - 1] + 1,
            matrix[i][j - 1] + 1,
            matrix[i - 1][j] + 1
          );
        }
      }
    }
    
    return matrix[str2.length][str1.length];
  }
  
  generateSearchSuggestions(keyword: string, searchHistory: Array<string>): Array<string> {
    const suggestions: Array<string> = [];
    
    if (!keyword || keyword.trim().length === 0) {
      return suggestions;
    }
    
    const trimmedKeyword = keyword.trim().toLowerCase();
    
    for (let i = 0; i < searchHistory.length; i++) {
      const historyItem = searchHistory[i];
      if (historyItem.toLowerCase().includes(trimmedKeyword) && 
          historyItem !== trimmedKeyword) {
        suggestions.push(historyItem);
      }
    }
    
    const uniqueSuggestions: Array<string> = [];
    const seen: Set<string> = new Set<string>();
    for (let i = 0; i < suggestions.length; i++) {
      if (!seen.has(suggestions[i])) {
        seen.add(suggestions[i]);
        uniqueSuggestions.push(suggestions[i]);
      }
    }
    return uniqueSuggestions.slice(0, 5);
  }
  
  async searchMultipleSources(
    keyword: string, 
    sources: Array<BookSource>,
    searchFunction: (keyword: string, source: BookSource) => Promise<Array<Book>>
  ): Promise<Array<Book>> {
    const allResults: Array<Book> = [];
    const enabledSources: Array<BookSource> = [];
    
    for (let i = 0; i < sources.length; i++) {
      if (sources[i].enabled) {
        enabledSources.push(sources[i]);
      }
    }
    
    Logger.debug(this.TAG, `开始在${enabledSources.length}个书源中搜索"${keyword}"`);
    
    const searchPromises = enabledSources.map(async (source: BookSource) => {
      try {
        const results = await searchFunction(keyword, source);
        const mappedResults: Array<Book> = [];
        for (let i = 0; i < results.length; i++) {
          const book = results[i];
          const bookWithSource: BookWithSource = {
            id: book.id,
            name: book.name,
            author: book.author,
            cover: book.cover,
            intro: book.intro,
            kind: book.kind,
            wordCount: book.wordCount,
            latestChapter: book.latestChapter,
            bookSourceId: source.id,
            bookSourceName: source.name,
            bookUrl: book.bookUrl,
            lastUpdateTime: book.lastUpdateTime,
            addTime: book.addTime,
            readProgress: book.readProgress,
            lastReadChapter: book.lastReadChapter,
            lastReadChapterIndex: book.lastReadChapterIndex
          };
          mappedResults.push(bookWithSource);
        }
        return mappedResults;
      } catch (error) {
        Logger.error(this.TAG, `书源${source.name}搜索失败：${JSON.stringify(error)}`);
        return [];
      }
    });
    
    const resultsArray = await Promise.allSettled(searchPromises);

    for (let i = 0; i < resultsArray.length; i++) {
      const result = resultsArray[i];
      if (result.status === 'fulfilled') {
        for (let j = 0; j < result.value.length; j++) {
          allResults.push(result.value[j]);
        }
      }
    }

    Logger.debug(this.TAG, `合并所有书源结果: ${allResults.length}本`);

    const uniqueResults = this.removeDuplicateBooks(allResults);
    const sortedResults = this.sortBooksBySourcePriority(uniqueResults);

    Logger.debug(this.TAG, `多书源搜索完成，共找到${sortedResults.length}本唯一书籍`);
    return sortedResults;
  }
  
  private removeDuplicateBooks(books: Array<Book>): Array<Book> {
    const seen = new Set<string>();
    const uniqueBooks: Array<Book> = [];

    for (let i = 0; i < books.length; i++) {
      const book = books[i];
      const key = `${book.name}_${book.author || ''}`.toLowerCase().trim();

      if (!seen.has(key)) {
        seen.add(key);
        uniqueBooks.push(book);
      }
    }

    Logger.info(this.TAG, `去重前: ${books.length}本, 去重后: ${uniqueBooks.length}本`);
    return uniqueBooks;
  }

  private sortBooksBySourcePriority(books: Array<Book>): Array<Book> {
    return books.sort(() => {
      return 0;
    });
  }

  validateSearchResults(books: Array<Book>): Array<Book> {
    const validBooks: Array<Book> = [];
    for (let i = 0; i < books.length; i++) {
      const book = books[i];
      const hasName = book && book.name && book.name.trim().length > 0;
      const hasUrl = book && book.bookUrl && book.bookUrl.trim().length > 0;

      if (!hasName) {
        Logger.debug(this.TAG, '过滤掉没有书名的搜索结果');
        continue;
      }

      if (!hasUrl) {
        Logger.debug(this.TAG, `过滤掉没有URL的书籍: ${book.name}`);
        continue;
      }

      validBooks.push(book);
    }
    return validBooks;
  }
}

export default new SearchEnhancer();
