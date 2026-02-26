/**
 * 搜索规则
 */
export interface SearchRule {
  bookList: string;
  name: string;
  author: string;
  cover: string | undefined;
  intro: string | undefined;
  bookUrl: string;
  nextUrl: string | undefined;
  checkKeyWord?: string;
}

/**
 * 发现规则
 */
export interface ExploreRule {
  url: string;
  bookList: string;
  name: string;
  author: string;
  cover: string | undefined;
  intro: string | undefined;
  bookUrl: string;
  nextUrl?: string;
}

/**
 * 书籍信息规则
 */
export interface BookInfoRule {
  name?: string;
  author?: string;
  intro?: string;
  coverUrl?: string;
  tocUrl?: string;
  lastChapter?: string;
  bookUrl?: string;
  canReName?: string;
  init?: string;
}

/**
 * 章节列表规则
 */
export interface TocRule {
  chapterList: string;
  chapterName: string;
  chapterUrl: string;
  nextUrl: string | undefined;
  isVip?: string;
  isPay?: string;
  updateTime?: string;
  volume?: string;
  preUpdateJs?: string;
}

/**
 * 内容规则
 */
export interface ContentRule {
  content: string;
  nextUrl: string | undefined;
  prevUrl: string | undefined;
  replaceRule?: string;
  webJs?: string;
  sourceRegex?: string;
  payAction?: string;
}

/**
 * 段评规则
 */
export interface ReviewRule {
  reviewList?: string;
  reviewTitle?: string;
  reviewContent?: string;
  reviewAuthor?: string;
  reviewTime?: string;
  reviewUrl?: string;
}

export type BookSourceStatus = 'unknown' | 'available' | 'unavailable' | 'manual_available' | 'manual_unavailable';
export type BookSourceType = 'text' | 'audio' | 'image' | 'file';

export interface BookSourceValidation {
  lastValidationTime: number;
  responseTime: number;
  successKeyword: string;
  failureReason: string;
}

export interface BookSourceGroup {
  name: string;
  show: boolean;
}

export interface RuleVariable {
  key: string;
  value: string;
  comment?: string;
}

export interface LoginConfig {
  loginUrl?: string;
  loginUi?: string;
  loginCheckJs?: string;
}

export interface NetworkConfig {
  header?: string;
  enabledCookieJar?: boolean;
  concurrentRate?: string;
}

export interface BookSourceVisualConfig {
  bookSourceType: BookSourceType;
  bookUrlPattern?: string;
  customOrder: number;
  weight: number;
  respondTime: number;
  lastUpdateTime: number;
}

export interface BookSourceRules {
  searchRule: SearchRule;
  exploreRule?: ExploreRule;
  bookInfoRule?: BookInfoRule;
  tocRule?: TocRule;
  contentRule: ContentRule;
  reviewRule?: ReviewRule;
}

export interface BookSourceMetadata {
  bookSourceGroup?: string;
  bookSourceComment?: string;
  variableComment?: string;
  enabled: boolean;
  enabledExplore: boolean;
}

export interface BookSourceScripting {
  jsLib?: string;
  coverDecodeJs?: string;
}

export interface BookSourceAdvanced {
  keywordEncoding?: string;
  keywordSeparator?: string;
  advancedQuerySupport?: boolean;
}

export interface BookSourceLegacy {
  searchUrl: string;
  exploreUrl?: string;
  ruleType: 'xpath' | 'jsonpath' | 'regex' | 'auto';
}

export interface BookSourceState {
  status?: BookSourceStatus;
  validation?: BookSourceValidation;
}

export interface BookSource {
  id: string;
  name: string;
  url: string;

  metadata: BookSourceMetadata;
  visualConfig: BookSourceVisualConfig;
  rules: BookSourceRules;
  loginConfig?: LoginConfig;
  networkConfig?: NetworkConfig;
  scripting?: BookSourceScripting;
  advanced?: BookSourceAdvanced;
  legacy: BookSourceLegacy;
  state?: BookSourceState;

  sort: number;
  addTime: number;
}

export interface BookSourceCompat {
  id: string;
  name: string;
  url: string;
  enabled: boolean;
  header: string | undefined;
  searchUrl: string;
  searchRule: SearchRule;
  findRule: ExploreRule | undefined;
  chapterRule: TocRule;
  contentRule: ContentRule;
  ruleType: 'xpath' | 'jsonpath' | 'regex' | 'auto';
  sort: number;
  lastUpdateTime: number;
  addTime: number;
  status?: BookSourceStatus;
  validation?: BookSourceValidation;
  keywordEncoding?: string;
  keywordSeparator?: string;
  advancedQuerySupport?: boolean;
}

export class BookSourceConverter {
  static toCompat(source: BookSource): BookSourceCompat {
    return {
      id: source.id,
      name: source.name,
      url: source.url,
      enabled: source.metadata.enabled,
      header: source.networkConfig?.header,
      searchUrl: source.legacy.searchUrl,
      searchRule: source.rules.searchRule,
      findRule: source.rules.exploreRule,
      chapterRule: source.rules.tocRule || {
        chapterList: '',
        chapterName: '',
        chapterUrl: '',
        nextUrl: undefined
      },
      contentRule: source.rules.contentRule,
      ruleType: source.legacy.ruleType,
      sort: source.sort,
      lastUpdateTime: source.visualConfig.lastUpdateTime,
      addTime: source.addTime,
      status: source.state?.status,
      validation: source.state?.validation,
      keywordEncoding: source.advanced?.keywordEncoding,
      keywordSeparator: source.advanced?.keywordSeparator,
      advancedQuerySupport: source.advanced?.advancedQuerySupport
    };
  }

  static fromCompat(compat: BookSourceCompat): BookSource {
    return {
      id: compat.id,
      name: compat.name,
      url: compat.url,
      metadata: {
        enabled: compat.enabled,
        enabledExplore: !!compat.findRule,
        bookSourceGroup: undefined,
        bookSourceComment: undefined,
        variableComment: undefined
      },
      visualConfig: {
        bookSourceType: 'text',
        customOrder: compat.sort,
        weight: 0,
        respondTime: 180000,
        lastUpdateTime: compat.lastUpdateTime
      },
      rules: {
        searchRule: compat.searchRule,
        exploreRule: compat.findRule,
        tocRule: compat.chapterRule,
        contentRule: compat.contentRule
      },
      networkConfig: {
        header: compat.header
      },
      advanced: {
        keywordEncoding: compat.keywordEncoding,
        keywordSeparator: compat.keywordSeparator,
        advancedQuerySupport: compat.advancedQuerySupport
      },
      legacy: {
        searchUrl: compat.searchUrl,
        ruleType: compat.ruleType
      },
      state: {
        status: compat.status,
        validation: compat.validation
      },
      sort: compat.sort,
      addTime: compat.addTime
    };
  }
  static toJson(source: BookSource): string {
    const compat = BookSourceConverter.toCompat(source);
    return JSON.stringify(compat, null, 2);
  }
  static fromJson(json: string): BookSource | null {
    try {
      const compat = JSON.parse(json) as BookSourceCompat;
      return BookSourceConverter.fromCompat(compat);
    } catch (e) {
      return null;
    }
  }
  static toJsonArray(sources: BookSource[]): string {
    const compatArray: BookSourceCompat[] = sources.map((s: BookSource) => BookSourceConverter.toCompat(s));
    return JSON.stringify(compatArray, null, 2);
  }
  static fromJsonArray(json: string): BookSource[] {
    try {
      const compatArray = JSON.parse(json) as BookSourceCompat[];
      return compatArray.map((c: BookSourceCompat) => BookSourceConverter.fromCompat(c));
    } catch (e) {
      return [];
    }
  }
}

export class BookSourceBuilder {
  private source: BookSource;

  constructor(id: string, name: string, url: string) {
    this.source = {
      id,
      name,
      url,
      metadata: {
        enabled: true,
        enabledExplore: true
      },
      visualConfig: {
        bookSourceType: 'text',
        customOrder: 0,
        weight: 0,
        respondTime: 180000,
        lastUpdateTime: Date.now()
      },
      rules: {
        searchRule: {
          bookList: '',
          name: '',
          author: '',
          cover: undefined,
          intro: undefined,
          bookUrl: '',
          nextUrl: undefined
        },
        contentRule: {
          content: '',
          nextUrl: undefined,
          prevUrl: undefined
        }
      },
      legacy: {
        searchUrl: '',
        ruleType: 'auto'
      },
      sort: 0,
      addTime: Date.now()
    };
  }

  setSearchUrl(url: string): BookSourceBuilder {
    this.source.legacy.searchUrl = url;
    return this;
  }
  setSearchRule(rule: Partial<SearchRule>): BookSourceBuilder {
    const currentRule = this.source.rules.searchRule;
    this.source.rules.searchRule = {
      bookList: rule.bookList ?? currentRule.bookList,
      name: rule.name ?? currentRule.name,
      author: rule.author ?? currentRule.author,
      cover: rule.cover ?? currentRule.cover,
      intro: rule.intro ?? currentRule.intro,
      bookUrl: rule.bookUrl ?? currentRule.bookUrl,
      nextUrl: rule.nextUrl ?? currentRule.nextUrl
    };
    return this;
  }

  setExploreUrl(url: string): BookSourceBuilder {
    this.source.legacy.exploreUrl = url;
    return this;
  }
  setExploreRule(rule: Partial<ExploreRule>): BookSourceBuilder {
    const currentRule = this.source.rules.exploreRule;
    if (currentRule) {
      this.source.rules.exploreRule = {
        bookList: rule.bookList ?? currentRule.bookList,
        name: rule.name ?? currentRule.name,
        author: rule.author ?? currentRule.author,
        cover: rule.cover ?? currentRule.cover,
        intro: rule.intro ?? currentRule.intro,
        bookUrl: rule.bookUrl ?? currentRule.bookUrl
      } as ExploreRule;
    } else {
      this.source.rules.exploreRule = rule as ExploreRule;
    }
    return this;
  }
  setTocRule(rule: Partial<TocRule>): BookSourceBuilder {
    const currentRule = this.source.rules.tocRule;
    if (currentRule) {
      this.source.rules.tocRule = {
        chapterList: rule.chapterList ?? currentRule.chapterList,
        chapterName: rule.chapterName ?? currentRule.chapterName,
        chapterUrl: rule.chapterUrl ?? currentRule.chapterUrl,
        nextUrl: rule.nextUrl ?? currentRule.nextUrl,
        isVip: rule.isVip ?? currentRule.isVip,
        isPay: rule.isPay ?? currentRule.isPay,
        updateTime: rule.updateTime ?? currentRule.updateTime,
        volume: rule.volume ?? currentRule.volume,
        preUpdateJs: rule.preUpdateJs ?? currentRule.preUpdateJs
      };
    } else {
      this.source.rules.tocRule = {
        chapterList: rule.chapterList ?? '',
        chapterName: rule.chapterName ?? '',
        chapterUrl: rule.chapterUrl ?? '',
        nextUrl: rule.nextUrl,
        isVip: rule.isVip,
        isPay: rule.isPay,
        updateTime: rule.updateTime,
        volume: rule.volume,
        preUpdateJs: rule.preUpdateJs
      };
    }
    return this;
  }
  setContentRule(rule: Partial<ContentRule>): BookSourceBuilder {
    const currentRule = this.source.rules.contentRule;
    if (currentRule) {
      this.source.rules.contentRule = {
        content: rule.content ?? currentRule.content,
        nextUrl: rule.nextUrl ?? currentRule.nextUrl,
        prevUrl: rule.prevUrl ?? currentRule.prevUrl,
        replaceRule: rule.replaceRule ?? currentRule.replaceRule,
        webJs: rule.webJs ?? currentRule.webJs,
        sourceRegex: rule.sourceRegex ?? currentRule.sourceRegex,
        payAction: rule.payAction ?? currentRule.payAction
      };
    } else {
      this.source.rules.contentRule = {
        content: rule.content ?? '',
        nextUrl: rule.nextUrl,
        prevUrl: rule.prevUrl,
        replaceRule: rule.replaceRule,
        webJs: rule.webJs,
        sourceRegex: rule.sourceRegex,
        payAction: rule.payAction
      };
    }
    return this;
  }
  setHeader(header: string): BookSourceBuilder {
    const currentConfig = this.source.networkConfig;
    if (currentConfig) {
      this.source.networkConfig = {
        header: header,
        enabledCookieJar: currentConfig.enabledCookieJar,
        concurrentRate: currentConfig.concurrentRate
      };
    } else {
      this.source.networkConfig = { header: header };
    }
    return this;
  }

  setGroup(group: string): BookSourceBuilder {
    this.source.metadata.bookSourceGroup = group;
    return this;
  }

  setEnabled(enabled: boolean): BookSourceBuilder {
    this.source.metadata.enabled = enabled;
    return this;
  }

  setRuleType(type: 'xpath' | 'jsonpath' | 'regex' | 'auto'): BookSourceBuilder {
    this.source.legacy.ruleType = type;
    return this;
  }

  setLoginConfig(config: LoginConfig): BookSourceBuilder {
    this.source.loginConfig = config;
    return this;
  }

  setNetworkConfig(config: NetworkConfig): BookSourceBuilder {
    const currentConfig = this.source.networkConfig;
    this.source.networkConfig = {
      header: config.header ?? currentConfig?.header,
      enabledCookieJar: config.enabledCookieJar ?? currentConfig?.enabledCookieJar,
      concurrentRate: config.concurrentRate ?? currentConfig?.concurrentRate
    };
    return this;
  }

  setScripting(scripting: BookSourceScripting): BookSourceBuilder {
    this.source.scripting = scripting;
    return this;
  }

  setAdvanced(advanced: BookSourceAdvanced): BookSourceBuilder {
    const currentAdvanced = this.source.advanced;
    this.source.advanced = {
      keywordEncoding: advanced.keywordEncoding ?? currentAdvanced?.keywordEncoding,
      keywordSeparator: advanced.keywordSeparator ?? currentAdvanced?.keywordSeparator,
      advancedQuerySupport: advanced.advancedQuerySupport ?? currentAdvanced?.advancedQuerySupport
    };
    return this;
  }

  setBookSourceType(type: BookSourceType): BookSourceBuilder {
    this.source.visualConfig.bookSourceType = type;
    return this;
  }

  setComment(comment: string): BookSourceBuilder {
    this.source.metadata.bookSourceComment = comment;
    return this;
  }

  setJsLib(jsLib: string): BookSourceBuilder {
    const currentScripting = this.source.scripting;
    this.source.scripting = {
      jsLib: jsLib,
      coverDecodeJs: currentScripting?.coverDecodeJs
    };
    return this;
  }

  build(): BookSource {
    return {
      id: this.source.id,
      name: this.source.name,
      url: this.source.url,
      metadata: this.source.metadata,
      visualConfig: this.source.visualConfig,
      rules: this.source.rules,
      loginConfig: this.source.loginConfig,
      networkConfig: this.source.networkConfig,
      scripting: this.source.scripting,
      advanced: this.source.advanced,
      legacy: this.source.legacy,
      state: this.source.state,
      sort: this.source.sort,
      addTime: this.source.addTime
    };
  }
}

export default BookSource;
