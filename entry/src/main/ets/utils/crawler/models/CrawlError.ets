export enum CrawlErrorCode {
  RULE_SYNTAX_ERROR = 800,
  RULE_TYPE_UNSUPPORTED = 801,
  RULE_RUNTIME_ERROR = 802,
  RULE_EMPTY_RESULT = 803,
  RULE_DEGRADED_FAILED = 804,
  RULE_VALIDATION_FAILED = 805,
  RULE_CHAIN_TOO_LONG = 806,
  RULE_CONTENT_TOO_LONG = 807,

  QUEUE_FULL = 810,
  CONCURRENCY_LIMIT_REACHED = 811,
  RATE_LIMIT_EXCEEDED = 812,
  CONNECTION_POOL_EXHAUSTED = 813,

  RETRY_EXHAUSTED = 820,
  RETRY_NOT_RETRYABLE = 821,
  BACKOFF_OVERFLOW = 822,

  PROXY_EXHAUSTED = 830,
  PROXY_REQUIRED = 831,
  PROXY_UNAVAILABLE = 832,
  JS_RENDER_TIMEOUT = 833,
  JS_RENDER_UNAVAILABLE = 834,
  JS_RENDER_ERROR = 835,
  FINGERPRINT_ERROR = 836,
  DOMAIN_BLOCKED = 837,
  CAPTCHA_DETECTED = 838
}

export class CrawlError {
  code: CrawlErrorCode;
  message: string;
  details?: string;
  timestamp: number;

  constructor(code: CrawlErrorCode, message: string, details?: string) {
    this.code = code;
    this.message = message;
    this.details = details;
    this.timestamp = Date.now();
  }

  static create(code: CrawlErrorCode, message: string, details?: string): CrawlError {
    return new CrawlError(code, message, details);
  }

  getLocalizedMessage(): string {
    const messages: Map<CrawlErrorCode, string> = new Map([
      [CrawlErrorCode.RULE_SYNTAX_ERROR, '规则语法错误'],
      [CrawlErrorCode.RULE_TYPE_UNSUPPORTED, '不支持的规则类型'],
      [CrawlErrorCode.RULE_RUNTIME_ERROR, '规则运行时错误'],
      [CrawlErrorCode.RULE_EMPTY_RESULT, '规则解析结果为空'],
      [CrawlErrorCode.RULE_DEGRADED_FAILED, '规则降级后仍无法解析'],
      [CrawlErrorCode.RULE_VALIDATION_FAILED, '规则校验失败'],
      [CrawlErrorCode.RULE_CHAIN_TOO_LONG, '规则链过长（上限20）'],
      [CrawlErrorCode.RULE_CONTENT_TOO_LONG, '规则内容过长（上限5000字符）'],
      [CrawlErrorCode.QUEUE_FULL, '任务队列已满'],
      [CrawlErrorCode.CONCURRENCY_LIMIT_REACHED, '并发度已达上限'],
      [CrawlErrorCode.RATE_LIMIT_EXCEEDED, '请求频率超限'],
      [CrawlErrorCode.CONNECTION_POOL_EXHAUSTED, '连接池耗尽'],
      [CrawlErrorCode.RETRY_EXHAUSTED, '重试次数耗尽'],
      [CrawlErrorCode.RETRY_NOT_RETRYABLE, '不可重试的错误'],
      [CrawlErrorCode.BACKOFF_OVERFLOW, '退避延迟溢出'],
      [CrawlErrorCode.PROXY_EXHAUSTED, '可用代理已耗尽'],
      [CrawlErrorCode.PROXY_REQUIRED, '该网站需要代理访问'],
      [CrawlErrorCode.PROXY_UNAVAILABLE, '代理不可用'],
      [CrawlErrorCode.JS_RENDER_TIMEOUT, 'JS渲染超时'],
      [CrawlErrorCode.JS_RENDER_UNAVAILABLE, 'JS渲染引擎不可用'],
      [CrawlErrorCode.JS_RENDER_ERROR, 'JS渲染错误'],
      [CrawlErrorCode.FINGERPRINT_ERROR, '指纹随机化错误'],
      [CrawlErrorCode.DOMAIN_BLOCKED, '域名被封禁'],
      [CrawlErrorCode.CAPTCHA_DETECTED, '检测到验证码']
    ]);
    return messages.get(this.code) ?? this.message;
  }
}
