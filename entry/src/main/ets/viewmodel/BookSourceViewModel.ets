import { BookSource, SearchRule, FindRule, ChapterRule, ContentRule } from '../models/BookSource';
import { databaseManager } from '../utils/DatabaseManager';
import { NetworkManager } from '../utils/NetworkManager';
import { IdGenerator } from '../utils/IdGenerator';

/**
 * 导入结果接口
 */
export interface ImportResult {
  success: boolean;
  message: string;
  count?: number;
}

/**
 * 搜索规则接口
 */
export interface SearchRuleRaw {
  bookList?: string;
  list?: string;
  name?: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl?: string;
  url?: string;
  nextUrl?: string;
}

/**
 * 发现规则接口
 */
export interface FindRuleRaw {
  url?: string;
  bookList?: string;
  list?: string;
  name?: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl?: string;
}

/**
 * 章节规则接口
 */
export interface ChapterRuleRaw {
  chapterList?: string;
  list?: string;
  chapterName?: string;
  name?: string;
  chapterUrl?: string;
  url?: string;
  nextUrl?: string;
}

/**
 * 内容规则接口
 */
export interface ContentRuleRaw {
  content?: string;
  nextUrl?: string;
  prevUrl?: string;
  replaceRule?: string;
}

/**
 * AstroRead 搜索规则接口
 */
export interface AstroReadSearchRule {
  bookList?: string;
  list?: string;
  name?: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl?: string;
  url?: string;
  nextUrl?: string;
}

/**
 * AstroRead 发现规则接口
 */
export interface AstroReadExploreRule {
  url?: string;
  bookList?: string;
  list?: string;
  name?: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl?: string;
}

/**
 * AstroRead 章节规则接口
 */
export interface AstroReadTocRule {
  chapterList?: string;
  list?: string;
  chapterName?: string;
  name?: string;
  chapterUrl?: string;
  url?: string;
  nextUrl?: string;
}

/**
 * AstroRead 内容规则接口
 */
export interface AstroReadContentRule {
  content?: string;
  nextUrl?: string;
  prevUrl?: string;
  replaceRule?: string;
}

/**
 * 书源原始数据接口
 */
export interface BookSourceRawData {
  id?: string;
  name?: string;
  url?: string;
  baseUrl?: string;
  enabled?: boolean;
  header?: string;
  headers?: string;
  searchUrl?: string;
  search?: string;
  searchRule?: SearchRuleRaw;
  findRule?: FindRuleRaw;
  chapterRule?: ChapterRuleRaw;
  contentRule?: ContentRuleRaw;
  ruleType?: string;
  sort?: number;
  lastUpdateTime?: number;
  addTime?: number;
  // AstroRead 格式字段
  bookSourceName?: string;
  bookSourceUrl?: string;
  ruleSearch?: AstroReadSearchRule;
  ruleExplore?: AstroReadExploreRule;
  exploreUrl?: string;
  ruleToc?: AstroReadTocRule;
  ruleContent?: AstroReadContentRule;
  customOrder?: number;
}

/**
 * 书源视图模型
 * 负责管理书源相关的业务逻辑和状态
 */
export class BookSourceViewModel {
  private bookSources: BookSource[] = [];
  private readonly databaseManager = databaseManager;

  /**
   * 加载所有启用的书源
   */
  async loadEnabledBookSources(): Promise<BookSource[]> {
    try {
      this.bookSources = await this.databaseManager.getAllEnabledBookSources();
      return this.bookSources;
    } catch (error) {
      console.error('Failed to load book sources:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 添加或更新书源
   */
  async upsertBookSource(bookSource: BookSource): Promise<void> {
    try {
      await this.databaseManager.upsertBookSource(bookSource);
      await this.loadEnabledBookSources();
    } catch (error) {
      console.error('Failed to upsert book source:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 切换书源启用状态
   */
  async toggleBookSource(id: string, enabled: boolean): Promise<void> {
    try {
      const source = this.bookSources.find((s: BookSource) => s.id === id);
      if (source) {
        source.enabled = enabled;
        await this.databaseManager.upsertBookSource(source);
        await this.loadEnabledBookSources();
      }
    } catch (error) {
      console.error('Failed to toggle book source:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 导入书源（从JSON文件或URL）
   */
  async importBookSources(sources: BookSource[]): Promise<void> {
    try {
      await this.batchUpsertBookSources(sources);
      await this.loadEnabledBookSources();
    } catch (error) {
      console.error('Failed to import book sources:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 批量添加或更新书源
   */
  async batchUpsertBookSources(sources: BookSource[]): Promise<void> {
    try {
      // 调用数据库管理器的批量操作方法
      // 这里假设 databaseManager 已经实现了批量操作
      // 如果没有实现，则需要在 DatabaseManager 中添加该方法
      await this.databaseManager.batchUpsertBookSources(sources);
      console.log(`Successfully upserted ${sources.length} book sources`);
    } catch (error) {
      console.error('Failed to batch upsert book sources:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 批量删除书源
   */
  async batchDeleteBookSources(_ids: string[]): Promise<void> {
    try {
      // TODO: 实现批量删除逻辑
      await this.loadEnabledBookSources();
    } catch (error) {
      console.error('Failed to batch delete book sources:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 测试书源有效性
   */
  async testBookSource(_bookSource: BookSource): Promise<boolean> {
    try {
      // TODO: 实现书源测试逻辑
      // 使用 NetworkManager 发送测试请求，验证规则是否正确
      return false;
    } catch (error) {
      console.error('Failed to test book source:', error);
      return false;
    }
  }

  /**
   * 删除书源
   */
  async deleteBookSource(id: string): Promise<void> {
    try {
      await this.batchDeleteBookSources([id]);
    } catch (error) {
      console.error('Failed to delete book source:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 导入书源
   * 封装完整的书源导入纯业务逻辑，无任何UI依赖
   */
  async importBookSource(input: string): Promise<ImportResult> {
    try {
      let bookSources: BookSource[] = [];
      const trimmedInput = input.trim();

      // 检测输入类型，使用正则表达式进行更精准的URL检测
      const urlReg = /^https?:\/\/[a-zA-Z0-9-_.]+(:\d+)?(\/[a-zA-Z0-9-_.?&=~:+#\/%]+)*$/;
      let isUrl = urlReg.test(trimmedInput) || trimmedInput.startsWith('http://') || trimmedInput.startsWith('https://');
      let url = trimmedInput;
      
      // 补全协议：仅当包含合法域名但无协议时，才补全HTTPS
      if (!isUrl && /^[a-zA-Z0-9-_.]+(:\d+)?(\/[a-zA-Z0-9-_.?&=~:+#\/%]+)*$/.test(trimmedInput)) {
        url = 'https://' + trimmedInput;
        isUrl = true;
      }

      // 申请存储权限
      const networkManager = NetworkManager.getInstance();
      await networkManager.requestStoragePermission();

      if (isUrl) {
        // 从URL获取书源（使用流式传输处理大量数据）
        console.log('Importing book sources from URL:', url);
        const jsonString = await networkManager.getStream(url);
        
        // 验证响应是否为空
        if (!jsonString || jsonString.trim() === '') {
          throw new Error('获取到的书源数据为空');
        }
        
        console.log('Book source data length:', jsonString.length);
        const data: BookSourceRawData | BookSourceRawData[] = JSON.parse(jsonString) as BookSourceRawData | BookSourceRawData[];

        // 处理书源数据格式
        if (Array.isArray(data)) {
          console.log('Found', data.length, 'book sources in array');
          // 分段处理大量书源
          const batchSize = 50;
          for (let i = 0; i < data.length; i += batchSize) {
            const batch = data.slice(i, i + batchSize);
            console.log(`Processing batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(data.length / batchSize)} (${batch.length} sources)`);
            const batchSources = batch.map<BookSource>((source) => this.createBookSourceFromRaw(source));
            bookSources.push(...batchSources);
          }
        } else if (typeof data === 'object' && data !== null) {
          // 尝试作为单个书源处理
          console.log('Found single book source');
          bookSources = [this.createBookSourceFromRaw(data)];
        } else {
          throw new Error('书源数据格式不正确，应为对象或数组');
        }
      } else {
        // 直接解析JSON字符串
        console.log('Importing book sources from local JSON');
        const data: BookSourceRawData | BookSourceRawData[] = JSON.parse(trimmedInput) as BookSourceRawData | BookSourceRawData[];

        // 处理书源数据格式
        if (Array.isArray(data)) {
          console.log('Found', data.length, 'book sources in array');
          // 分段处理大量书源
          const batchSize = 50;
          for (let i = 0; i < data.length; i += batchSize) {
            const batch = data.slice(i, i + batchSize);
            console.log(`Processing batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(data.length / batchSize)} (${batch.length} sources)`);
            const batchSources = batch.map<BookSource>((source) => this.createBookSourceFromRaw(source));
            bookSources.push(...batchSources);
          }
        } else if (typeof data === 'object' && data !== null) {
          // 尝试作为单个书源处理
          console.log('Found single book source');
          bookSources = [this.createBookSourceFromRaw(data)];
        } else {
          throw new Error('JSON数据格式不正确，应为对象或数组');
        }
      }

      // 检查是否成功解析出书源
      if (bookSources.length === 0) {
        throw new Error('未能解析出书源数据，请检查输入格式');
      }

      // 批量导入书源（分段导入）
      const importBatchSize = 50;
      for (let i = 0; i < bookSources.length; i += importBatchSize) {
        const batch = bookSources.slice(i, i + importBatchSize);
        console.log(`Importing batch ${Math.floor(i / importBatchSize) + 1}/${Math.ceil(bookSources.length / importBatchSize)} (${batch.length} sources)`);
        await this.batchUpsertBookSources(batch);
        // 每批次导入后稍作延迟
        if (i + importBatchSize < bookSources.length) {
          await new Promise<void>(resolve => setTimeout(resolve, 500));
        }
      }

      return {
        success: true,
        message: `导入完成：成功${bookSources.length}个`,
        count: bookSources.length
      };
    } catch (error) {
      console.error('Failed to import book source:', error);
      return {
        success: false,
        message: error instanceof Error ? error.message : '未知错误'
      };
    }
  }

  /**
   * 从原始数据创建书源对象
   */
  private createBookSourceFromRaw(source: BookSourceRawData): BookSource {
    // 映射书源基本信息
    const bookSourceName = source.bookSourceName || source.name || '未知书源';
    const bookSourceUrl = source.bookSourceUrl || source.url || source.baseUrl || '';
    const searchUrl = source.searchUrl || source.search || '';
    const enabled = source.enabled !== false;
    const sort = source.customOrder || source.sort || 0;
    const lastUpdateTime = source.lastUpdateTime || Date.now();
    const addTime = source.addTime || Date.now();
    const header = source.header || source.headers || undefined;

    // 映射搜索规则
    const ruleSearch = source.ruleSearch || source.searchRule || {};
    const searchRule: SearchRule = {
      bookList: ruleSearch.bookList || ruleSearch.list || '',
      name: ruleSearch.name || '',
      author: ruleSearch.author || '',
      cover: ruleSearch.cover || undefined,
      intro: ruleSearch.intro || undefined,
      bookUrl: ruleSearch.bookUrl || ruleSearch.url || '',
      nextUrl: ruleSearch.nextUrl
    };

    // 映射发现规则
    const ruleExplore = source.ruleExplore || source.findRule || {};
    const exploreUrl = source.exploreUrl || ruleExplore.url || '';
    const findRule: FindRule | undefined = exploreUrl ? {
      url: exploreUrl,
      bookList: ruleExplore.bookList || ruleExplore.list || '',
      name: ruleExplore.name || '',
      author: ruleExplore.author || '',
      cover: ruleExplore.cover || undefined,
      intro: ruleExplore.intro || undefined,
      bookUrl: ruleExplore.bookUrl || ruleExplore.url || ''
    } : undefined;

    // 映射章节规则
    const ruleToc = source.ruleToc || source.chapterRule || {};
    const chapterRule: ChapterRule = {
      chapterList: ruleToc.chapterList || ruleToc.list || '',
      chapterName: ruleToc.chapterName || ruleToc.name || '',
      chapterUrl: ruleToc.chapterUrl || ruleToc.url || '',
      nextUrl: ruleToc.nextUrl
    };

    // 映射内容规则
    const ruleContent = source.ruleContent || source.contentRule || {};
    const contentRule: ContentRule = {
      content: ruleContent.content || '',
      nextUrl: ruleContent.nextUrl,
      prevUrl: ruleContent.prevUrl,
      replaceRule: ruleContent.replaceRule
    };

    // 确定规则类型
    let ruleType: 'xpath' | 'jsonpath' | 'regex' = 'xpath';
    if (source.ruleType) {
      if (source.ruleType === 'xpath' || source.ruleType === 'jsonpath' || source.ruleType === 'regex') {
        ruleType = source.ruleType;
      }
    } else {
      // 根据规则内容自动判断
      const allRules = [
        searchRule.bookList, searchRule.name, searchRule.author, searchRule.bookUrl,
        chapterRule.chapterList, chapterRule.chapterName, chapterRule.chapterUrl,
        contentRule.content
      ];
      for (const rule of allRules) {
        if (rule && typeof rule === 'string') {
          if (rule.startsWith('$')) {
            ruleType = 'jsonpath';
            break;
          } else if (rule.startsWith('@js:')) {
            ruleType = 'regex';
            break;
          }
        }
      }
    }

    return {
      id: source.id || IdGenerator.generateUUID(),
      name: bookSourceName,
      url: bookSourceUrl,
      enabled: enabled,
      header: header,
      searchUrl: searchUrl,
      searchRule: searchRule,
      findRule: findRule,
      chapterRule: chapterRule,
      contentRule: contentRule,
      ruleType: ruleType,
      sort: sort,
      lastUpdateTime: lastUpdateTime,
      addTime: addTime
    };
  }
}
