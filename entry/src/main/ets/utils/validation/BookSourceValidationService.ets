/**
 * BookSourceValidationService - 增强版书源验证服务
 * 提供详细的书源验证、错误分类和解决方案建议
 */

import { BookSource } from '../../models/BookSource';
import { Logger } from '../performance/Logger';
import { parseDebugLogger, ParseErrorType, ParseErrorInfo } from '../performance/ParseDebugLogger';
import NetworkAdapter, { NetworkError } from '../network/NetworkAdapter';
import { HTMLParser } from '../parser/HTMLParser';
import { AsyncCssSelectorParser } from '../parser/AsyncCssSelectorParser';
import { EnhancedJSEngine } from '../scripting/EnhancedJSEngine';

export type ValidationErrorCode =
  | 'NETWORK_TIMEOUT'
  | 'NETWORK_DNS_ERROR'
  | 'NETWORK_SSL_ERROR'
  | 'NETWORK_CONNECTION_REFUSED'
  | 'NETWORK_HTTP_ERROR'
  | 'NETWORK_UNKNOWN'
  | 'PARSE_RULE_SYNTAX_ERROR'
  | 'PARSE_RULE_NOT_MATCHED'
  | 'PARSE_EMPTY_RESULT'
  | 'PARSE_JS_EXECUTION_ERROR'
  | 'PARSE_ATTRIBUTE_NOT_FOUND'
  | 'PARSE_URL_RESOLUTION_ERROR'
  | 'PARSE_ENCODING_ERROR'
  | 'CONTENT_ANTI_CRAWLER'
  | 'CONTENT_CAPTCHA_REQUIRED'
  | 'CONTENT_RATE_LIMITED'
  | 'CONTENT_DYNAMIC_LOAD'
  | 'CONTENT_EMPTY_RESPONSE'
  | 'CONTENT_INVALID_FORMAT'
  | 'SOURCE_CONFIG_MISSING_URL'
  | 'SOURCE_CONFIG_MISSING_RULE'
  | 'SOURCE_CONFIG_INVALID_HEADER'
  | 'SOURCE_CONFIG_DISABLED'
  | 'UNKNOWN_ERROR';

export type ValidationErrorCategory = 
  | 'network'
  | 'parse'
  | 'content'
  | 'config'
  | 'unknown';

export interface ValidationErrorCodeInfo {
  code: ValidationErrorCode;
  category: ValidationErrorCategory;
  severity: 'critical' | 'high' | 'medium' | 'low';
  title: string;
  description: string;
  possibleCauses: string[];
  solutions: string[];
  relatedFields?: string[];
}

const ERROR_CODE_DEFINITIONS: Map<ValidationErrorCode, ValidationErrorCodeInfo> = new Map([
  ['NETWORK_TIMEOUT', {
    code: 'NETWORK_TIMEOUT',
    category: 'network',
    severity: 'high',
    title: '网络请求超时',
    description: '请求书源服务器时等待响应超时',
    possibleCauses: [
      '服务器响应过慢',
      '网络连接不稳定',
      '请求被服务器延迟处理',
      '防火墙拦截'
    ],
    solutions: [
      '尝试增加请求超时时间',
      '检查网络连接状态',
      '稍后重试',
      '检查书源URL是否正确'
    ]
  }],
  ['NETWORK_DNS_ERROR', {
    code: 'NETWORK_DNS_ERROR',
    category: 'network',
    severity: 'critical',
    title: 'DNS解析失败',
    description: '无法解析书源域名',
    possibleCauses: [
      '域名已过期或失效',
      'DNS服务器无法访问',
      '域名拼写错误',
      '域名被封锁'
    ],
    solutions: [
      '检查书源URL是否正确',
      '尝试更换DNS服务器',
      '确认书源网站是否仍然运营',
      '尝试使用代理访问'
    ]
  }],
  ['NETWORK_SSL_ERROR', {
    code: 'NETWORK_SSL_ERROR',
    category: 'network',
    severity: 'high',
    title: 'SSL证书错误',
    description: 'HTTPS连接时证书验证失败',
    possibleCauses: [
      '网站证书已过期',
      '证书不被信任',
      '证书配置错误',
      '中间人攻击'
    ],
    solutions: [
      '检查系统时间是否正确',
      '更新系统根证书',
      '联系书源提供者',
      '暂时使用HTTP（不推荐）'
    ]
  }],
  ['NETWORK_CONNECTION_REFUSED', {
    code: 'NETWORK_CONNECTION_REFUSED',
    category: 'network',
    severity: 'critical',
    title: '连接被拒绝',
    description: '服务器拒绝建立连接',
    possibleCauses: [
      '服务器已关闭',
      '端口被封锁',
      'IP被列入黑名单',
      '服务器过载'
    ],
    solutions: [
      '确认书源网站是否正常运营',
      '稍后重试',
      '尝试使用代理',
      '更换其他书源'
    ]
  }],
  ['NETWORK_HTTP_ERROR', {
    code: 'NETWORK_HTTP_ERROR',
    category: 'network',
    severity: 'high',
    title: 'HTTP错误',
    description: '服务器返回HTTP错误状态码',
    possibleCauses: [
      '页面不存在(404)',
      '访问被禁止(403)',
      '服务器内部错误(500)',
      '请求方法不被允许(405)'
    ],
    solutions: [
      '检查书源URL是否正确',
      '检查请求头配置',
      '确认搜索URL模板是否正确',
      '联系书源提供者更新'
    ],
    relatedFields: ['url', 'searchUrl', 'header']
  }],
  ['PARSE_RULE_SYNTAX_ERROR', {
    code: 'PARSE_RULE_SYNTAX_ERROR',
    category: 'parse',
    severity: 'high',
    title: '解析规则语法错误',
    description: '书源配置的解析规则存在语法问题',
    possibleCauses: [
      'CSS选择器语法错误',
      'XPath表达式无效',
      '正则表达式格式错误',
      'JS代码存在语法错误'
    ],
    solutions: [
      '检查规则语法是否正确',
      '参考规则编写文档',
      '使用规则测试工具验证',
      '查看错误详情定位问题'
    ],
    relatedFields: ['searchRule.bookList', 'searchRule.name', 'searchRule.author']
  }],
  ['PARSE_RULE_NOT_MATCHED', {
    code: 'PARSE_RULE_NOT_MATCHED',
    category: 'parse',
    severity: 'high',
    title: '解析规则未匹配',
    description: '规则无法在HTML中找到匹配元素',
    possibleCauses: [
      '网站页面结构已更改',
      'CSS类名或ID已变化',
      '规则与实际内容不匹配',
      '页面使用了动态加载'
    ],
    solutions: [
      '查看原始HTML分析页面结构',
      '更新CSS选择器或XPath',
      '检查是否需要使用JS规则',
      '考虑网站是否改版'
    ],
    relatedFields: ['searchRule.bookList', 'searchRule.name']
  }],
  ['PARSE_EMPTY_RESULT', {
    code: 'PARSE_EMPTY_RESULT',
    category: 'parse',
    severity: 'medium',
    title: '解析结果为空',
    description: '规则匹配成功但提取的内容为空',
    possibleCauses: [
      '目标元素存在但无内容',
      '提取属性不存在',
      '文本内容为空白字符',
      '元素被隐藏或display:none'
    ],
    solutions: [
      '检查目标元素是否有内容',
      '确认属性名称是否正确',
      '尝试提取其他属性或文本',
      '检查是否需要处理空白字符'
    ]
  }],
  ['PARSE_JS_EXECUTION_ERROR', {
    code: 'PARSE_JS_EXECUTION_ERROR',
    category: 'parse',
    severity: 'high',
    title: 'JS执行错误',
    description: '执行JavaScript规则时发生错误',
    possibleCauses: [
      'JS代码存在运行时错误',
      '缺少必要的变量或函数',
      '执行环境不支持某些API',
      '代码逻辑错误'
    ],
    solutions: [
      '检查JS代码逻辑',
      '添加错误处理和日志',
      '确认执行环境支持的API',
      '简化代码逻辑'
    ],
    relatedFields: ['searchRule.name', 'searchRule.author', 'searchRule.bookUrl']
  }],
  ['CONTENT_ANTI_CRAWLER', {
    code: 'CONTENT_ANTI_CRAWLER',
    category: 'content',
    severity: 'high',
    title: '反爬虫检测',
    description: '网站检测到爬虫行为并阻止访问',
    possibleCauses: [
      '请求频率过高',
      'User-Agent被识别为爬虫',
      '缺少必要的请求头',
      'IP被列入黑名单'
    ],
    solutions: [
      '降低请求频率',
      '设置真实的User-Agent',
      '添加Referer等请求头',
      '使用代理或等待一段时间'
    ],
    relatedFields: ['header']
  }],
  ['CONTENT_CAPTCHA_REQUIRED', {
    code: 'CONTENT_CAPTCHA_REQUIRED',
    category: 'content',
    severity: 'high',
    title: '需要验证码',
    description: '网站要求完成验证码验证',
    possibleCauses: [
      '访问频率过高触发验证',
      'IP被标记为可疑',
      '网站启用了验证码保护'
    ],
    solutions: [
      '等待一段时间后重试',
      '在浏览器中完成验证',
      '更换IP或使用代理',
      '联系网站管理员'
    ]
  }],
  ['CONTENT_RATE_LIMITED', {
    code: 'CONTENT_RATE_LIMITED',
    category: 'content',
    severity: 'medium',
    title: '请求频率限制',
    description: '请求过于频繁被服务器限制',
    possibleCauses: [
      '短时间内发送大量请求',
      '未遵守robots.txt',
      '触发了频率限制规则'
    ],
    solutions: [
      '增加请求间隔时间',
      '实现请求队列和限流',
      '等待限制解除后重试'
    ]
  }],
  ['CONTENT_DYNAMIC_LOAD', {
    code: 'CONTENT_DYNAMIC_LOAD',
    category: 'content',
    severity: 'medium',
    title: '动态加载内容',
    description: '页面内容通过JavaScript动态加载',
    possibleCauses: [
      '网站使用SPA框架',
      '内容通过AJAX加载',
      '需要执行JS才能获取内容'
    ],
    solutions: [
      '寻找真实的API接口',
      '使用JS规则提取内容',
      '分析网络请求获取数据源',
      '考虑使用无头浏览器'
    ]
  }],
  ['CONTENT_EMPTY_RESPONSE', {
    code: 'CONTENT_EMPTY_RESPONSE',
    category: 'content',
    severity: 'high',
    title: '响应内容为空',
    description: '服务器返回了空内容',
    possibleCauses: [
      '服务器处理异常',
      '请求参数错误',
      '内容被压缩但未正确处理',
      '响应被截断'
    ],
    solutions: [
      '检查请求参数是否正确',
      '检查Accept-Encoding头',
      '尝试不同的请求方式',
      '联系书源提供者'
    ]
  }],
  ['SOURCE_CONFIG_MISSING_URL', {
    code: 'SOURCE_CONFIG_MISSING_URL',
    category: 'config',
    severity: 'critical',
    title: '缺少URL配置',
    description: '书源缺少必要的URL配置',
    possibleCauses: [
      '书源配置不完整',
      '导入时数据丢失',
      '书源格式错误'
    ],
    solutions: [
      '补充书源URL',
      '重新导入书源',
      '检查书源格式是否正确'
    ],
    relatedFields: ['url', 'searchUrl']
  }],
  ['SOURCE_CONFIG_MISSING_RULE', {
    code: 'SOURCE_CONFIG_MISSING_RULE',
    category: 'config',
    severity: 'critical',
    title: '缺少解析规则',
    description: '书源缺少必要的解析规则配置',
    possibleCauses: [
      '书源配置不完整',
      '规则字段被误删',
      '书源格式错误'
    ],
    solutions: [
      '补充解析规则',
      '参考其他书源配置',
      '重新导入完整的书源'
    ],
    relatedFields: ['searchRule', 'searchRule.bookList', 'searchRule.name']
  }],
  ['SOURCE_CONFIG_DISABLED', {
    code: 'SOURCE_CONFIG_DISABLED',
    category: 'config',
    severity: 'low',
    title: '书源已禁用',
    description: '书源当前处于禁用状态',
    possibleCauses: [
      '用户手动禁用',
      '系统自动禁用失效书源',
      '书源存在安全问题'
    ],
    solutions: [
      '在书源管理中启用该书源',
      '检查书源是否可用',
      '更新书源后重新启用'
    ]
  }],
  ['UNKNOWN_ERROR', {
    code: 'UNKNOWN_ERROR',
    category: 'unknown',
    severity: 'medium',
    title: '未知错误',
    description: '发生了无法识别的错误',
    possibleCauses: [
      '未预期的异常',
      '系统内部错误',
      '资源不足'
    ],
    solutions: [
      '查看详细错误信息',
      '重试操作',
      '联系开发者反馈问题'
    ]
  }]
]);

export interface DetailedValidationResult {
  isValid: boolean;
  sourceId: string;
  sourceName: string;
  validationTime: number;
  overallStatus: 'valid' | 'warning' | 'invalid';
  errors: ValidationErrorDetail[];
  warnings: ValidationWarning[];
  suggestions: string[];
  networkTest?: NetworkTestResult;
  parseTest?: ParseTestResult;
  contentAnalysis?: ContentAnalysisResult;
}

export interface ValidationErrorDetail {
  code: ValidationErrorCode;
  info: ValidationErrorCodeInfo;
  message: string;
  field?: string;
  rule?: string;
  htmlContext?: string;
  lineNumber?: number;
  timestamp: number;
}

export interface ValidationWarning {
  code: string;
  message: string;
  field?: string;
  suggestion: string;
}

export interface NetworkTestResult {
  url: string;
  isReachable: boolean;
  responseTime: number;
  httpStatus: number;
  responseSize: number;
  contentType: string;
  redirectChain: string[];
  error?: string;
}

export interface ParseTestResult {
  bookListRule: string;
  bookListMatched: number;
  fieldResults: FieldParseResult[];
  overallSuccess: boolean;
  errorCount: number;
}

export interface FieldParseResult {
  fieldName: string;
  rule: string;
  ruleType: 'css' | 'xpath' | 'jsonpath' | 'regex' | 'js';
  matched: boolean;
  extractedValue: string;
  error?: string;
  suggestions: string[];
}

export interface ContentAnalysisResult {
  isHtml: boolean;
  isJson: boolean;
  hasDynamicContent: boolean;
  detectedEncoding: string;
  hasAntiCrawler: boolean;
  hasCaptcha: boolean;
  contentPreview: string;
  detectedFramework?: string;
}

export interface ValidationProgress {
  stage: 'network' | 'parse' | 'content' | 'complete';
  message: string;
  progress: number;
}

export type ValidationProgressCallback = (progress: ValidationProgress) => void;

class BookSourceValidationService {
  private static instance: BookSourceValidationService | null = null;
  private readonly TAG = 'BookSourceValidation';
  
  private htmlParser: HTMLParser;
  private asyncCssParser: AsyncCssSelectorParser;
  private jsEngine: EnhancedJSEngine;
  
  private readonly REQUEST_TIMEOUT = 15000;
  private readonly MAX_HTML_PREVIEW = 1000;

  private constructor() {
    this.htmlParser = HTMLParser.getInstance();
    this.asyncCssParser = AsyncCssSelectorParser.getInstance();
    this.jsEngine = EnhancedJSEngine.getInstance();
  }

  static getInstance(): BookSourceValidationService {
    if (!BookSourceValidationService.instance) {
      BookSourceValidationService.instance = new BookSourceValidationService();
    }
    return BookSourceValidationService.instance;
  }

  getErrorInfo(code: ValidationErrorCode): ValidationErrorCodeInfo {
    const info = ERROR_CODE_DEFINITIONS.get(code);
    if (!info) {
      return ERROR_CODE_DEFINITIONS.get('UNKNOWN_ERROR')!;
    }
    return info;
  }

  async validateSource(
    source: BookSource,
    testKeyword: string = '斗罗',
    progressCallback?: ValidationProgressCallback
  ): Promise<DetailedValidationResult> {
    const startTime = Date.now();
    const result: DetailedValidationResult = {
      isValid: true,
      sourceId: source.id,
      sourceName: source.name,
      validationTime: 0,
      overallStatus: 'valid',
      errors: [],
      warnings: [],
      suggestions: []
    };

    parseDebugLogger.startSession(`validate_${source.id}_${Date.now()}`);

    try {
      this.reportProgress(progressCallback, 'config', '检查书源配置...', 0);
      this.validateConfig(source, result);

      if (result.errors.length > 0) {
        result.isValid = false;
        result.overallStatus = 'invalid';
        return this.finalizeResult(result, startTime);
      }

      this.reportProgress(progressCallback, 'network', '测试网络连接...', 25);
      result.networkTest = await this.testNetwork(source);
      
      if (!result.networkTest.isReachable) {
        this.addNetworkError(result, result.networkTest.error || '网络不可达');
        result.isValid = false;
        result.overallStatus = 'invalid';
        return this.finalizeResult(result, startTime);
      }

      this.reportProgress(progressCallback, 'parse', '测试解析规则...', 50);
      result.parseTest = await this.testParseRules(source, testKeyword);
      
      if (result.parseTest.errorCount > 0) {
        this.addParseErrors(result, result.parseTest);
      }

      this.reportProgress(progressCallback, 'content', '分析响应内容...', 75);
      result.contentAnalysis = await this.analyzeContent(source, testKeyword);
      
      if (result.contentAnalysis.hasAntiCrawler) {
        this.addError(result, 'CONTENT_ANTI_CRAWLER', '检测到反爬虫机制');
        result.warnings.push({
          code: 'ANTI_CRAWLER_DETECTED',
          message: '网站可能有反爬虫保护',
          suggestion: '尝试添加或修改请求头配置'
        });
      }

      if (result.contentAnalysis.hasCaptcha) {
        this.addError(result, 'CONTENT_CAPTCHA_REQUIRED', '需要完成验证码验证');
      }

      this.reportProgress(progressCallback, 'complete', '验证完成', 100);

      if (result.errors.length > 0) {
        result.isValid = false;
        result.overallStatus = result.errors.some(e => e.info.severity === 'critical') ? 'invalid' : 'warning';
      }

      this.generateSuggestions(result);

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      this.addError(result, 'UNKNOWN_ERROR', errorMsg);
      result.isValid = false;
      result.overallStatus = 'invalid';
    } finally {
      parseDebugLogger.endSession();
    }

    return this.finalizeResult(result, startTime);
  }

  private reportProgress(
    callback: ValidationProgressCallback | undefined,
    stage: ValidationProgress['stage'],
    message: string,
    progress: number
  ): void {
    if (callback) {
      callback({ stage, message, progress });
    }
  }

  private validateConfig(source: BookSource, result: DetailedValidationResult): void {
    if (!source.enabled) {
      this.addError(result, 'SOURCE_CONFIG_DISABLED', '书源已禁用');
      return;
    }

    if (!source.url || source.url.trim().length === 0) {
      this.addError(result, 'SOURCE_CONFIG_MISSING_URL', '书源URL为空', 'url');
    } else if (!this.isValidUrl(source.url)) {
      this.addError(result, 'SOURCE_CONFIG_MISSING_URL', '书源URL格式无效', 'url');
    }

    if (!source.searchUrl || source.searchUrl.trim().length === 0) {
      this.addWarning(result, 'MISSING_SEARCH_URL', '未配置搜索URL', 'searchUrl', '将使用书源URL进行测试');
    }

    if (!source.searchRule) {
      this.addError(result, 'SOURCE_CONFIG_MISSING_RULE', '缺少搜索规则配置', 'searchRule');
    } else {
      if (!source.searchRule.bookList || source.searchRule.bookList.trim().length === 0) {
        this.addError(result, 'SOURCE_CONFIG_MISSING_RULE', '缺少书籍列表规则', 'searchRule.bookList');
      }
      if (!source.searchRule.name || source.searchRule.name.trim().length === 0) {
        this.addError(result, 'SOURCE_CONFIG_MISSING_RULE', '缺少书名提取规则', 'searchRule.name');
      }
    }

    if (source.header) {
      try {
        const headers = JSON.parse(source.header);
        if (typeof headers !== 'object' || headers === null) {
          this.addError(result, 'SOURCE_CONFIG_INVALID_HEADER', '请求头格式无效', 'header');
        }
      } catch {
        this.addError(result, 'SOURCE_CONFIG_INVALID_HEADER', '请求头JSON解析失败', 'header');
      }
    }
  }

  private async testNetwork(source: BookSource): Promise<NetworkTestResult> {
    const testUrl = this.buildTestUrl(source);
    const result: NetworkTestResult = {
      url: testUrl,
      isReachable: false,
      responseTime: 0,
      httpStatus: 0,
      responseSize: 0,
      contentType: '',
      redirectChain: []
    };

    const startTime = Date.now();

    try {
      const headers = this.buildHeaders(source);
      const response = await NetworkAdapter.get(testUrl, headers);
      
      result.responseTime = Date.now() - startTime;
      result.isReachable = true;
      result.httpStatus = 200;
      result.responseSize = response.length;
      result.contentType = 'text/html';

      Logger.debug(this.TAG, `网络测试成功: ${source.name}, 响应时间: ${result.responseTime}ms`);

    } catch (error) {
      result.responseTime = Date.now() - startTime;
      result.error = this.parseNetworkError(error);
      result.isReachable = false;
      
      Logger.warn(this.TAG, `网络测试失败: ${source.name}, 错误: ${result.error}`);
    }

    return result;
  }

  private async testParseRules(source: BookSource, keyword: string): Promise<ParseTestResult> {
    const result: ParseTestResult = {
      bookListRule: source.searchRule?.bookList || '',
      bookListMatched: 0,
      fieldResults: [],
      overallSuccess: false,
      errorCount: 0
    };

    if (!source.searchRule) {
      result.errorCount = 1;
      return result;
    }

    try {
      const testUrl = this.buildTestUrl(source, keyword);
      const headers = this.buildHeaders(source);
      const html = await NetworkAdapter.get(testUrl, headers);

      const bookListHtml = await this.htmlParser.parseAsync(html, source.searchRule.bookList);
      result.bookListMatched = bookListHtml ? bookListHtml.length : 0;

      if (result.bookListMatched === 0) {
        parseDebugLogger.logBookListExtraction({
          sourceName: source.name,
          sourceId: source.id,
          listRule: source.searchRule.bookList,
          inputHtmlLength: html.length,
          matchedCount: 0,
          extractionStatus: 'failed',
          htmlPreview: html.substring(0, this.MAX_HTML_PREVIEW),
          suggestions: ['检查CSS选择器是否正确', '网站可能已改版', '内容可能动态加载']
        });
        result.errorCount++;
        return result;
      }

      const firstBookHtml = bookListHtml[0];
      
      const fields = ['name', 'author', 'bookUrl', 'cover', 'intro'] as const;
      for (const fieldName of fields) {
        const rule = source.searchRule[fieldName];
        if (!rule) continue;

        const fieldResult = await this.testFieldParse(source, firstBookHtml, fieldName, rule);
        result.fieldResults.push(fieldResult);

        if (!fieldResult.matched && fieldName === 'name') {
          result.errorCount++;
        }
      }

      result.overallSuccess = result.errorCount === 0;

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(this.TAG, `解析规则测试失败: ${errorMsg}`);
      result.errorCount++;
    }

    return result;
  }

  private async testFieldParse(
    source: BookSource,
    html: string,
    fieldName: string,
    rule: string
  ): Promise<FieldParseResult> {
    const startTime = Date.now();
    const result: FieldParseResult = {
      fieldName,
      rule,
      ruleType: this.detectRuleType(rule),
      matched: false,
      extractedValue: '',
      suggestions: []
    };

    try {
      let value = '';

      if (rule.startsWith('@js:') || rule.includes('<js>')) {
        result.ruleType = 'js';
        value = await this.jsEngine.executeRule(html, rule, source.url);
      } else {
        value = await this.asyncCssParser.extractValue(html, rule);
      }

      result.matched = value && value.trim().length > 0;
      result.extractedValue = value;

      parseDebugLogger.logFieldExtraction({
        sourceName: source.name,
        sourceId: source.id,
        fieldName,
        rule,
        ruleType: result.ruleType,
        inputHtml: html.substring(0, 500),
        inputHtmlLength: html.length,
        extractedValue: value,
        extractionStatus: result.matched ? 'success' : 'empty',
        processingTime: Date.now() - startTime,
        matchedElements: result.matched ? 1 : 0
      });

      if (!result.matched) {
        result.suggestions = this.generateFieldSuggestions(fieldName, rule, html);
      }

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      result.error = errorMsg;
      result.suggestions = ['检查规则语法是否正确', '查看错误详情定位问题'];

      parseDebugLogger.logFieldExtraction({
        sourceName: source.name,
        sourceId: source.id,
        fieldName,
        rule,
        ruleType: result.ruleType,
        inputHtml: html.substring(0, 500),
        inputHtmlLength: html.length,
        extractedValue: '',
        extractionStatus: 'error',
        processingTime: Date.now() - startTime,
        errorMessage: errorMsg
      });
    }

    return result;
  }

  private async analyzeContent(source: BookSource, keyword: string): Promise<ContentAnalysisResult> {
    const result: ContentAnalysisResult = {
      isHtml: false,
      isJson: false,
      hasDynamicContent: false,
      detectedEncoding: 'utf-8',
      hasAntiCrawler: false,
      hasCaptcha: false,
      contentPreview: ''
    };

    try {
      const testUrl = this.buildTestUrl(source, keyword);
      const headers = this.buildHeaders(source);
      const content = await NetworkAdapter.get(testUrl, headers);

      result.contentPreview = content.substring(0, this.MAX_HTML_PREVIEW);
      result.isHtml = content.includes('<!DOCTYPE') || content.includes('<html');
      
      try {
        JSON.parse(content);
        result.isJson = true;
      } catch {
        // Not JSON
      }

      const lowerContent = content.toLowerCase();
      result.hasAntiCrawler = 
        lowerContent.includes('captcha') ||
        lowerContent.includes('验证') ||
        lowerContent.includes('请输入验证码') ||
        lowerContent.includes('访问频率过高') ||
        lowerContent.includes('请求过于频繁') ||
        lowerContent.includes('forbidden') ||
        lowerContent.includes('access denied');

      result.hasCaptcha = 
        lowerContent.includes('captcha') ||
        lowerContent.includes('验证码') ||
        lowerContent.includes('recaptcha');

      result.hasDynamicContent = 
        lowerContent.includes('ng-version') ||
        lowerContent.includes('react') ||
        lowerContent.includes('vue') ||
        lowerContent.includes('__NEXT_DATA__') ||
        lowerContent.includes('window.__INITIAL_STATE__');

      if (result.hasDynamicContent) {
        const frameworkMatch = content.match(/ng-version|react|vue|__NEXT_DATA__/);
        if (frameworkMatch) {
          result.detectedFramework = frameworkMatch[0];
        }
      }

    } catch (error) {
      Logger.warn(this.TAG, `内容分析失败: ${error}`);
    }

    return result;
  }

  private addError(
    result: DetailedValidationResult,
    code: ValidationErrorCode,
    message: string,
    field?: string,
    rule?: string
  ): void {
    const info = this.getErrorInfo(code);
    result.errors.push({
      code,
      info,
      message,
      field,
      rule,
      timestamp: Date.now()
    });
  }

  private addWarning(
    result: DetailedValidationResult,
    code: string,
    message: string,
    field?: string,
    suggestion?: string
  ): void {
    result.warnings.push({
      code,
      message,
      field,
      suggestion: suggestion || ''
    });
  }

  private addNetworkError(result: DetailedValidationResult, errorMsg: string): void {
    const lowerError = errorMsg.toLowerCase();
    
    if (lowerError.includes('timeout')) {
      this.addError(result, 'NETWORK_TIMEOUT', errorMsg);
    } else if (lowerError.includes('dns') || lowerError.includes('resolve')) {
      this.addError(result, 'NETWORK_DNS_ERROR', errorMsg);
    } else if (lowerError.includes('ssl') || lowerError.includes('certificate')) {
      this.addError(result, 'NETWORK_SSL_ERROR', errorMsg);
    } else if (lowerError.includes('refused') || lowerError.includes('connection')) {
      this.addError(result, 'NETWORK_CONNECTION_REFUSED', errorMsg);
    } else if (lowerError.includes('403') || lowerError.includes('404') || lowerError.includes('500')) {
      this.addError(result, 'NETWORK_HTTP_ERROR', errorMsg);
    } else {
      this.addError(result, 'NETWORK_UNKNOWN', errorMsg);
    }
  }

  private addParseErrors(result: DetailedValidationResult, parseTest: ParseTestResult): void {
    if (parseTest.bookListMatched === 0) {
      this.addError(
        result,
        'PARSE_RULE_NOT_MATCHED',
        `书籍列表规则未匹配到任何元素`,
        'searchRule.bookList',
        parseTest.bookListRule
      );
    }

    for (const fieldResult of parseTest.fieldResults) {
      if (!fieldResult.matched && fieldResult.fieldName === 'name') {
        this.addError(
          result,
          'PARSE_EMPTY_RESULT',
          `书名提取失败: ${fieldResult.error || '结果为空'}`,
          `searchRule.${fieldResult.fieldName}`,
          fieldResult.rule
        );
      } else if (fieldResult.error) {
        this.addError(
          result,
          fieldResult.ruleType === 'js' ? 'PARSE_JS_EXECUTION_ERROR' : 'PARSE_RULE_SYNTAX_ERROR',
          `${fieldResult.fieldName}解析错误: ${fieldResult.error}`,
          `searchRule.${fieldResult.fieldName}`,
          fieldResult.rule
        );
      }
    }
  }

  private generateSuggestions(result: DetailedValidationResult): void {
    const seenSuggestions = new Set<string>();

    for (const error of result.errors) {
      for (const solution of error.info.solutions) {
        if (!seenSuggestions.has(solution)) {
          seenSuggestions.add(solution);
          result.suggestions.push(solution);
        }
      }
    }

    for (const fieldResult of result.parseTest?.fieldResults || []) {
      for (const suggestion of fieldResult.suggestions) {
        if (!seenSuggestions.has(suggestion)) {
          seenSuggestions.add(suggestion);
          result.suggestions.push(suggestion);
        }
      }
    }
  }

  private generateFieldSuggestions(fieldName: string, rule: string, html: string): string[] {
    const suggestions: string[] = [];

    if (rule.includes('@')) {
      const attrMatch = rule.match(/@(\w+)$/);
      if (attrMatch) {
        suggestions.push(`检查属性 ${attrMatch[1]} 是否存在于目标元素中`);
      }
    }

    if (rule.includes('class.')) {
      suggestions.push('检查CSS类名是否正确，网站可能已更改类名');
    }

    if (rule.startsWith('//')) {
      suggestions.push('XPath规则可能需要调整，建议使用CSS选择器替代');
    }

    if (html.length < 100) {
      suggestions.push('HTML内容过短，可能未正确获取页面');
    }

    if (suggestions.length === 0) {
      suggestions.push('检查规则语法是否正确');
      suggestions.push('查看原始HTML分析页面结构');
    }

    return suggestions;
  }

  private detectRuleType(rule: string): 'css' | 'xpath' | 'jsonpath' | 'regex' | 'js' {
    if (rule.startsWith('@js:') || rule.includes('<js>')) return 'js';
    if (rule.startsWith('//') || rule.startsWith('./')) return 'xpath';
    if (rule.startsWith('$.') || rule.startsWith('$[')) return 'jsonpath';
    if (rule.startsWith('/') || rule.startsWith('##')) return 'regex';
    return 'css';
  }

  private buildTestUrl(source: BookSource, keyword: string = '测试'): string {
    let url = source.searchUrl || source.url;
    
    url = url
      .replace(/\{\{key\}\}/g, encodeURIComponent(keyword))
      .replace(/\{key\}/g, encodeURIComponent(keyword))
      .replace(/<key>/g, encodeURIComponent(keyword))
      .replace(/\$key\$/g, encodeURIComponent(keyword));

    if (!url.startsWith('http')) {
      url = source.url + (url.startsWith('/') ? '' : '/') + url;
    }

    return url;
  }

  private buildHeaders(source: BookSource): Record<string, string> {
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
    };

    if (source.header) {
      try {
        const customHeaders = JSON.parse(source.header);
        const keys = Object.keys(customHeaders);
        for (const key of keys) {
          headers[key] = customHeaders[key];
        }
      } catch {
        // Ignore parse errors
      }
    }

    return headers;
  }

  private parseNetworkError(error: unknown): string {
    if (error instanceof Error) {
      return error.message;
    }
    if (typeof error === 'string') {
      return error;
    }
    return '未知网络错误';
  }

  private isValidUrl(url: string): boolean {
    try {
      return url.startsWith('http://') || url.startsWith('https://');
    } catch {
      return false;
    }
  }

  private finalizeResult(result: DetailedValidationResult, startTime: number): DetailedValidationResult {
    result.validationTime = Date.now() - startTime;
    return result;
  }

  generateValidationReport(result: DetailedValidationResult): string {
    const lines: string[] = [];
    
    lines.push('=== 书源验证报告 ===');
    lines.push(`书源: ${result.sourceName} (${result.sourceId})`);
    lines.push(`验证时间: ${new Date().toLocaleString()}`);
    lines.push(`耗时: ${result.validationTime}ms`);
    lines.push(`状态: ${result.overallStatus.toUpperCase()}`);
    lines.push('');

    if (result.networkTest) {
      lines.push('【网络测试】');
      lines.push(`  URL: ${result.networkTest.url}`);
      lines.push(`  可达: ${result.networkTest.isReachable ? '是' : '否'}`);
      lines.push(`  响应时间: ${result.networkTest.responseTime}ms`);
      lines.push(`  响应大小: ${result.networkTest.responseSize} 字节`);
      if (result.networkTest.error) {
        lines.push(`  错误: ${result.networkTest.error}`);
      }
      lines.push('');
    }

    if (result.parseTest) {
      lines.push('【解析测试】');
      lines.push(`  列表规则: ${result.parseTest.bookListRule}`);
      lines.push(`  匹配数量: ${result.parseTest.bookListMatched}`);
      lines.push(`  字段结果:`);
      for (const field of result.parseTest.fieldResults) {
        const status = field.matched ? '✓' : '✗';
        lines.push(`    ${status} ${field.fieldName}: ${field.extractedValue || '(空)'}`);
        if (field.error) {
          lines.push(`      错误: ${field.error}`);
        }
      }
      lines.push('');
    }

    if (result.contentAnalysis) {
      lines.push('【内容分析】');
      lines.push(`  类型: ${result.contentAnalysis.isJson ? 'JSON' : 'HTML'}`);
      lines.push(`  动态内容: ${result.contentAnalysis.hasDynamicContent ? '是' : '否'}`);
      lines.push(`  反爬虫: ${result.contentAnalysis.hasAntiCrawler ? '检测到' : '未检测到'}`);
      lines.push(`  验证码: ${result.contentAnalysis.hasCaptcha ? '需要' : '不需要'}`);
      lines.push('');
    }

    if (result.errors.length > 0) {
      lines.push('【错误详情】');
      for (const error of result.errors) {
        lines.push(`  [${error.info.severity.toUpperCase()}] ${error.info.title}`);
        lines.push(`    代码: ${error.code}`);
        lines.push(`    描述: ${error.info.description}`);
        lines.push(`    消息: ${error.message}`);
        if (error.field) {
          lines.push(`    字段: ${error.field}`);
        }
        lines.push(`    可能原因:`);
        for (const cause of error.info.possibleCauses) {
          lines.push(`      - ${cause}`);
        }
        lines.push(`    解决方案:`);
        for (const solution of error.info.solutions) {
          lines.push(`      - ${solution}`);
        }
        lines.push('');
      }
    }

    if (result.warnings.length > 0) {
      lines.push('【警告】');
      for (const warning of result.warnings) {
        lines.push(`  - ${warning.message}`);
        if (warning.suggestion) {
          lines.push(`    建议: ${warning.suggestion}`);
        }
      }
      lines.push('');
    }

    if (result.suggestions.length > 0) {
      lines.push('【建议】');
      for (const suggestion of result.suggestions) {
        lines.push(`  - ${suggestion}`);
      }
    }

    return lines.join('\n');
  }

  async validateSourcesBatch(
    sources: BookSource[],
    progressCallback?: (current: number, total: number, sourceName: string) => void
  ): Promise<DetailedValidationResult[]> {
    const results: DetailedValidationResult[] = [];

    for (let i = 0; i < sources.length; i++) {
      const source = sources[i];
      
      if (progressCallback) {
        progressCallback(i + 1, sources.length, source.name);
      }

      const result = await this.validateSource(source);
      results.push(result);

      if (i < sources.length - 1) {
        await new Promise<void>(resolve => setTimeout(resolve, 1000));
      }
    }

    return results;
  }
}

export const bookSourceValidationService = BookSourceValidationService.getInstance();
