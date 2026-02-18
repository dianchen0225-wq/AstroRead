export interface ReplaceRule {
  id: string;
  pattern: string;
  replacement: string;
  enabled: boolean;
  description?: string;
}

export interface FilterRule {
  id: string;
  pattern: string;
  enabled: boolean;
  description?: string;
}

export interface ContentFilterConfig {
  replaceRules: ReplaceRule[];
  filterRules: FilterRule[];
  enableAdFilter: boolean;
  enableScriptFilter: boolean;
  enableStyleFilter: boolean;
}

export const DEFAULT_FILTER_CONFIG: ContentFilterConfig = {
  replaceRules: [
    { id: '1', pattern: '请记住本站域名', replacement: '', enabled: true, description: '过滤网站提示' },
    { id: '2', pattern: '最新章节', replacement: '', enabled: true, description: '过滤章节提示' },
    { id: '3', pattern: '手机用户请浏览阅读', replacement: '', enabled: true, description: '过滤手机提示' },
    { id: '4', pattern: '一秒记住.*?免费阅读', replacement: '', enabled: true, description: '过滤广告提示' },
    { id: '5', pattern: '－－－\\s*$', replacement: '', enabled: true, description: '过滤分隔线' },
    { id: '6', pattern: '本章未完.*?下一页', replacement: '', enabled: true, description: '过滤分页提示' }
  ],
  filterRules: [
    { id: '1', pattern: '<script[^>]*>.*?</script>', enabled: true, description: '过滤脚本标签' },
    { id: '2', pattern: '<style[^>]*>.*?</style>', enabled: true, description: '过滤样式标签' },
    { id: '3', pattern: '<!--.*?-->', enabled: true, description: '过滤HTML注释' },
    { id: '4', pattern: '<(div|span|p)[^>]*class="[^"]*ad[^"]*"[^>]*>.*?</\\1>', enabled: true, description: '过滤广告div' },
    { id: '5', pattern: '<a[^>]*href="[^"]*"(?!chapter)[^>]*>.*?</a>', enabled: false, description: '过滤非章节链接' }
  ],
  enableAdFilter: true,
  enableScriptFilter: true,
  enableStyleFilter: true
};

export const AD_KEYWORDS: string[] = [
  '广告', '推广', '赞助', '合作', 'www.', 'http://', 'https://',
  '点击查看', '扫码关注', '关注公众号', '加入书友群', 'QQ群',
  '充值', 'VIP', '会员', '订阅', '打赏', '投推荐票'
];
