export interface ReplaceRule {
  id: string;
  name: string;
  group?: string;
  pattern: string;
  replacement: string;
  scope?: string;
  scopeTitle: boolean;
  scopeContent: boolean;
  excludeScope?: string;
  isEnabled: boolean;
  isRegex: boolean;
  timeoutMillisecond: number;
  order: number;
  createTime: number;
  updateTime: number;
}

export interface FilterRule {
  id: string;
  name: string;
  pattern: string;
  enabled: boolean;
  description?: string;
  order: number;
}

export interface ContentFilterConfig {
  replaceRules: ReplaceRule[];
  filterRules: FilterRule[];
  enableAdFilter: boolean;
  enableScriptFilter: boolean;
  enableStyleFilter: boolean;
  chineseConvertType: 0 | 1 | 2;
}

export const DEFAULT_REPLACE_RULES: ReplaceRule[] = [
  {
    id: '1',
    name: '过滤网站提示',
    pattern: '请记住本站域名',
    replacement: '',
    scopeTitle: false,
    scopeContent: true,
    isEnabled: true,
    isRegex: false,
    timeoutMillisecond: 3000,
    order: 1,
    createTime: Date.now(),
    updateTime: Date.now()
  },
  {
    id: '2',
    name: '过滤章节提示',
    pattern: '最新章节',
    replacement: '',
    scopeTitle: false,
    scopeContent: true,
    isEnabled: true,
    isRegex: false,
    timeoutMillisecond: 3000,
    order: 2,
    createTime: Date.now(),
    updateTime: Date.now()
  },
  {
    id: '3',
    name: '过滤手机提示',
    pattern: '手机用户请浏览阅读',
    replacement: '',
    scopeTitle: false,
    scopeContent: true,
    isEnabled: true,
    isRegex: false,
    timeoutMillisecond: 3000,
    order: 3,
    createTime: Date.now(),
    updateTime: Date.now()
  },
  {
    id: '4',
    name: '过滤广告提示',
    pattern: '一秒记住.*?免费阅读',
    replacement: '',
    scopeTitle: false,
    scopeContent: true,
    isEnabled: true,
    isRegex: true,
    timeoutMillisecond: 3000,
    order: 4,
    createTime: Date.now(),
    updateTime: Date.now()
  },
  {
    id: '5',
    name: '过滤分隔线',
    pattern: '－－－\\s*$',
    replacement: '',
    scopeTitle: false,
    scopeContent: true,
    isEnabled: true,
    isRegex: true,
    timeoutMillisecond: 3000,
    order: 5,
    createTime: Date.now(),
    updateTime: Date.now()
  },
  {
    id: '6',
    name: '过滤分页提示',
    pattern: '本章未完.*?下一页',
    replacement: '',
    scopeTitle: false,
    scopeContent: true,
    isEnabled: true,
    isRegex: true,
    timeoutMillisecond: 3000,
    order: 6,
    createTime: Date.now(),
    updateTime: Date.now()
  },
  {
    id: '7',
    name: '过滤无弹窗广告',
    pattern: '无弹窗.*?小说网',
    replacement: '',
    scopeTitle: false,
    scopeContent: true,
    isEnabled: true,
    isRegex: true,
    timeoutMillisecond: 3000,
    order: 7,
    createTime: Date.now(),
    updateTime: Date.now()
  },
  {
    id: '8',
    name: '过滤更新提示',
    pattern: '最快更新.*?无弹窗',
    replacement: '',
    scopeTitle: false,
    scopeContent: true,
    isEnabled: true,
    isRegex: true,
    timeoutMillisecond: 3000,
    order: 8,
    createTime: Date.now(),
    updateTime: Date.now()
  },
  {
    id: '9',
    name: '过滤推荐票提示',
    pattern: '投推荐票.*?月票',
    replacement: '',
    scopeTitle: false,
    scopeContent: true,
    isEnabled: true,
    isRegex: true,
    timeoutMillisecond: 3000,
    order: 9,
    createTime: Date.now(),
    updateTime: Date.now()
  },
  {
    id: '10',
    name: '过滤作者有话说',
    pattern: 'ps:.*$',
    replacement: '',
    scopeTitle: false,
    scopeContent: true,
    isEnabled: false,
    isRegex: true,
    timeoutMillisecond: 3000,
    order: 10,
    createTime: Date.now(),
    updateTime: Date.now()
  }
];

export const DEFAULT_FILTER_RULES: FilterRule[] = [
  {
    id: '1',
    name: '过滤脚本标签',
    pattern: '<script[^>]*>[\\s\\S]*?</script>',
    enabled: true,
    description: '移除所有script标签及其内容',
    order: 1
  },
  {
    id: '2',
    name: '过滤样式标签',
    pattern: '<style[^>]*>[\\s\\S]*?</style>',
    enabled: true,
    description: '移除所有style标签及其内容',
    order: 2
  },
  {
    id: '3',
    name: '过滤HTML注释',
    pattern: '<!--[\\s\\S]*?-->',
    enabled: true,
    description: '移除HTML注释',
    order: 3
  },
  {
    id: '4',
    name: '过滤广告div',
    pattern: '<(div|span|p)[^>]*class="[^"]*ad[^"]*"[^>]*>[\\s\\S]*?</\\1>',
    enabled: true,
    description: '移除包含ad类名的元素',
    order: 4
  },
  {
    id: '5',
    name: '过滤隐藏元素',
    pattern: '<[^>]*style="[^"]*display:\\s*none[^"]*"[^>]*>[\\s\\S]*?</[^>]+>',
    enabled: true,
    description: '移除隐藏的元素',
    order: 5
  }
];

export const AD_KEYWORDS: string[] = [
  '广告', '推广', '赞助', '合作', 'www.', 'http://', 'https://',
  '点击查看', '扫码关注', '关注公众号', '加入书友群', 'QQ群',
  '充值', 'VIP', '会员', '订阅', '打赏', '投推荐票', '月票',
  '无弹窗', '最快更新', '记住本站', '一秒记住', '免费阅读'
];

export const DEFAULT_FILTER_CONFIG: ContentFilterConfig = {
  replaceRules: DEFAULT_REPLACE_RULES,
  filterRules: DEFAULT_FILTER_RULES,
  enableAdFilter: true,
  enableScriptFilter: true,
  enableStyleFilter: true,
  chineseConvertType: 0
};

export function createReplaceRule(
  name: string,
  pattern: string,
  replacement: string = '',
  options?: Partial<ReplaceRule>
): ReplaceRule {
  const now = Date.now();
  return {
    id: `rule_${now}_${Math.random().toString(36).substring(2, 9)}`,
    name,
    pattern,
    replacement,
    scopeTitle: false,
    scopeContent: true,
    isEnabled: true,
    isRegex: false,
    timeoutMillisecond: 3000,
    order: 0,
    createTime: now,
    updateTime: now,
    ...options
  };
}

export function validateReplaceRule(rule: ReplaceRule): { valid: boolean; error?: string } {
  if (!rule.name || rule.name.trim() === '') {
    return { valid: false, error: '规则名称不能为空' };
  }
  
  if (!rule.pattern || rule.pattern.trim() === '') {
    return { valid: false, error: '匹配模式不能为空' };
  }
  
  if (rule.isRegex) {
    try {
      new RegExp(rule.pattern);
    } catch (e) {
      return { valid: false, error: `正则表达式无效: ${e}` };
    }
    
    if (rule.pattern.endsWith('|') && !rule.pattern.endsWith('\\|')) {
      return { valid: false, error: '正则表达式不能以未转义的|结尾' };
    }
  }
  
  if (rule.timeoutMillisecond <= 0) {
    return { valid: false, error: '超时时间必须大于0' };
  }
  
  return { valid: true };
}

export function matchesScope(rule: ReplaceRule, bookName: string, bookOrigin: string): boolean {
  if (!rule.scope || rule.scope.trim() === '') {
    return true;
  }
  
  const scopes = rule.scope.split(',').map((s: string) => s.trim());
  
  for (const scope of scopes) {
    if (scope === bookName || scope === bookOrigin) {
      if (rule.excludeScope) {
        const excludes = rule.excludeScope.split(',').map((s: string) => s.trim());
        if (excludes.includes(bookName) || excludes.includes(bookOrigin)) {
          return false;
        }
      }
      return true;
    }
  }
  
  return false;
}
