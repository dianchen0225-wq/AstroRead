/**
 * 书源安全沙箱
 * 提供书源安全扫描和风险评估功能
 * 用户可选择无视风险继续导入
 */

import { BookSource } from '../models/BookSource';
import { Logger } from './Logger';

export type SecurityRiskLevel = 'low' | 'medium' | 'high' | 'critical';

export interface SecurityRisk {
  level: SecurityRiskLevel;
  type: string;
  description: string;
  location?: string;
}

export interface SecurityScanResult {
  isSafe: boolean;
  riskLevel: SecurityRiskLevel;
  risks: SecurityRisk[];
  summary: string;
}

class PatternItem {
  pattern: RegExp;
  type: string;
  desc: string;

  constructor(pattern: RegExp, type: string, desc: string) {
    this.pattern = pattern;
    this.type = type;
    this.desc = desc;
  }
}

export class SourceSandbox {
  private static TAG: string = 'SourceSandbox';

  private static CRITICAL_PATTERNS: PatternItem[] = [];

  private static HIGH_PATTERNS: PatternItem[] = [];

  private static MEDIUM_PATTERNS: PatternItem[] = [];

  private static SSRF_PATTERNS: RegExp[] = [];

  private static SUSPICIOUS_HEADERS: string[] = [];

  static {
    SourceSandbox.CRITICAL_PATTERNS = [
      new PatternItem(/\beval\s*\(/gi, '代码执行', '使用eval()动态执行代码'),
      new PatternItem(/\bFunction\s*\(/gi, '代码执行', '使用Function构造函数'),
      new PatternItem(/\brequire\s*\(/gi, '模块加载', '尝试加载外部模块'),
      new PatternItem(/\bimport\s+/gi, '模块加载', '尝试导入模块'),
      new PatternItem(/process\s*\./gi, '系统访问', '尝试访问进程对象'),
      new PatternItem(/global\s*\./gi, '全局访问', '尝试访问全局对象'),
    ];

    SourceSandbox.HIGH_PATTERNS = [
      new PatternItem(/\bfetch\s*\(/gi, '网络请求', '使用fetch API'),
      new PatternItem(/\bXMLHttpRequest\b/gi, '网络请求', '使用XMLHttpRequest'),
      new PatternItem(/\bWebSocket\b/gi, '网络请求', '使用WebSocket'),
      new PatternItem(/\bWorker\b/gi, '后台任务', '创建Web Worker'),
      new PatternItem(/\bdocument\.\s*(cookie|domain|write)/gi, '文档操作', '操作DOM文档'),
      new PatternItem(/\bwindow\.\s*(location|open|eval)/gi, '窗口操作', '操作窗口对象'),
      new PatternItem(/localStorage|sessionStorage/gi, '存储访问', '访问本地存储'),
    ];

    SourceSandbox.MEDIUM_PATTERNS = [
      new PatternItem(/javascript:/gi, 'JS协议', '包含javascript:协议'),
      new PatternItem(/<script[\s\S]*?>[\s\S]*?<\/script>/gi, '脚本标签', '包含script标签'),
      new PatternItem(/on(load|error|click|mouse|key|focus|blur)\s*=/gi, '事件处理', '包含内联事件处理'),
      new PatternItem(/\bsetTimeout\s*\(/gi, '定时器', '使用setTimeout'),
      new PatternItem(/\bsetInterval\s*\(/gi, '定时器', '使用setInterval'),
      new PatternItem(/@js:/gi, 'JS规则', '包含JavaScript规则'),
    ];

    SourceSandbox.SSRF_PATTERNS = [
      /^localhost$/i,
      /^127\.\d+\.\d+\.\d+$/,
      /^0\.0\.0\.0$/,
      /^10\.\d+\.\d+\.\d+$/,
      /^172\.(1[6-9]|2\d|3[01])\.\d+\.\d+$/,
      /^192\.168\.\d+\.\d+$/,
      /^169\.254\.\d+\.\d+$/,
      /^::1$/,
      /^::$/,
      /^fc00:/i,
      /^fe80:/i,
      /\.local$/i,
      /\.internal$/i,
      /metadata\.google\.internal$/i,
      /metadata\.azure$/i,
    ];

    SourceSandbox.SUSPICIOUS_HEADERS = [
      'cookie', 'authorization', 'proxy-authorization',
      'x-forwarded-for', 'x-real-ip', 'x-api-key',
      'set-cookie', 'www-authenticate', 'x-auth-token',
      'proxy-authorization', 'x-csrf-token'
    ];
  }

  static scanSourceContent(content: string): SecurityScanResult {
    const risks: SecurityRisk[] = [];

    for (let i = 0; i < SourceSandbox.CRITICAL_PATTERNS.length; i++) {
      const item = SourceSandbox.CRITICAL_PATTERNS[i];
      const matches = content.match(item.pattern);
      if (matches) {
        risks.push({
          level: 'critical',
          type: item.type,
          description: item.desc,
          location: `发现 ${matches.length} 处`
        });
      }
    }

    for (let i = 0; i < SourceSandbox.HIGH_PATTERNS.length; i++) {
      const item = SourceSandbox.HIGH_PATTERNS[i];
      const matches = content.match(item.pattern);
      if (matches) {
        risks.push({
          level: 'high',
          type: item.type,
          description: item.desc,
          location: `发现 ${matches.length} 处`
        });
      }
    }

    for (let i = 0; i < SourceSandbox.MEDIUM_PATTERNS.length; i++) {
      const item = SourceSandbox.MEDIUM_PATTERNS[i];
      const matches = content.match(item.pattern);
      if (matches) {
        risks.push({
          level: 'medium',
          type: item.type,
          description: item.desc,
          location: `发现 ${matches.length} 处`
        });
      }
    }

    const riskLevel = SourceSandbox.calculateRiskLevel(risks);
    const summary = SourceSandbox.generateSummary(risks, riskLevel);

    return {
      isSafe: riskLevel === 'low',
      riskLevel,
      risks,
      summary
    };
  }

  static scanBookSource(source: BookSource): SecurityScanResult {
    const risks: SecurityRisk[] = [];

    const allContent = SourceSandbox.extractSourceContent(source);
    const contentRisks = SourceSandbox.scanSourceContent(allContent);
    risks.push(...contentRisks.risks);

    if (source.url) {
      const urlRisk = SourceSandbox.checkUrlRisk(source.url, '书源URL');
      if (urlRisk) risks.push(urlRisk);
    }

    if (source.searchUrl) {
      const urlRisk = SourceSandbox.checkUrlRisk(source.searchUrl, '搜索URL');
      if (urlRisk) risks.push(urlRisk);
    }

    if (source.header) {
      const headerRisks = SourceSandbox.checkHeaderRisks(source.header);
      risks.push(...headerRisks);
    }

    if (source.searchRule) {
      const ruleRisks = SourceSandbox.checkRuleRisks(source.searchRule, '搜索规则');
      risks.push(...ruleRisks);
    }

    if (source.chapterRule) {
      const ruleRisks = SourceSandbox.checkRuleRisks(source.chapterRule, '章节规则');
      risks.push(...ruleRisks);
    }

    if (source.contentRule) {
      const ruleRisks = SourceSandbox.checkRuleRisks(source.contentRule, '内容规则');
      risks.push(...ruleRisks);
    }

    const riskLevel = SourceSandbox.calculateRiskLevel(risks);
    const summary = SourceSandbox.generateSummary(risks, riskLevel);

    return {
      isSafe: riskLevel === 'low',
      riskLevel,
      risks,
      summary
    };
  }

  static scanSourcesBatch(sources: BookSource[]): Map<string, SecurityScanResult> {
    const results = new Map<string, SecurityScanResult>();

    for (let i = 0; i < sources.length; i++) {
      const source = sources[i];
      const result = SourceSandbox.scanBookSource(source);
      results.set(source.id || source.name, result);
    }

    return results;
  }

  private static extractSourceContent(source: BookSource): string {
    const parts: string[] = [];

    if (source.searchUrl) parts.push(source.searchUrl);
    if (source.header) parts.push(source.header);
    if (source.searchRule) {
      parts.push(JSON.stringify(source.searchRule));
    }
    if (source.chapterRule) {
      parts.push(JSON.stringify(source.chapterRule));
    }
    if (source.contentRule) {
      parts.push(JSON.stringify(source.contentRule));
    }
    if (source.findRule) {
      parts.push(JSON.stringify(source.findRule));
    }

    return parts.join(' ');
  }

  private static checkUrlRisk(url: string, location: string): SecurityRisk | null {
    try {
      const urlPattern = /^(https?:\/\/)([^\/:]+)(:\d+)?(\/.*)?$/;
      const match = url.match(urlPattern);

      if (!match) return null;

      const hostname = match[2].toLowerCase();

      for (let i = 0; i < SourceSandbox.SSRF_PATTERNS.length; i++) {
        const pattern = SourceSandbox.SSRF_PATTERNS[i];
        if (pattern.test(hostname)) {
          return {
            level: 'high',
            type: 'SSRF风险',
            description: `检测到内部网络地址: ${hostname}`,
            location
          };
        }
      }

      return null;
    } catch (error) {
      return null;
    }
  }

  private static checkHeaderRisks(headerString: string): SecurityRisk[] {
    const risks: SecurityRisk[] = [];

    try {
      const headers = JSON.parse(headerString) as Record<string, string>;

      const keys = Object.keys(headers);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        const value = headers[key];
        const lowerKey = key.toLowerCase();

        if (SourceSandbox.SUSPICIOUS_HEADERS.includes(lowerKey)) {
          risks.push({
            level: 'high',
            type: '敏感请求头',
            description: `检测到敏感请求头: ${key}`,
            location: '请求头配置'
          });
        }

        if (/[\r\n]/.test(key) || /[\r\n]/.test(value)) {
          risks.push({
            level: 'high',
            type: '注入风险',
            description: '请求头包含换行符，可能存在注入风险',
            location: `请求头: ${key}`
          });
        }
      }
    } catch (error) {
      risks.push({
        level: 'medium',
        type: '格式错误',
        description: '请求头JSON格式无效',
        location: '请求头配置'
      });
    }

    return risks;
  }

  private static checkRuleRisks(rule: object, location: string): SecurityRisk[] {
    const risks: SecurityRisk[] = [];
    const ruleString = JSON.stringify(rule);

    for (let i = 0; i < SourceSandbox.CRITICAL_PATTERNS.length; i++) {
      const item = SourceSandbox.CRITICAL_PATTERNS[i];
      if (item.pattern.test(ruleString)) {
        risks.push({
          level: 'critical',
          type: item.type,
          description: `${location}中${item.desc}`,
          location
        });
      }
    }

    for (let i = 0; i < SourceSandbox.HIGH_PATTERNS.length; i++) {
      const item = SourceSandbox.HIGH_PATTERNS[i];
      if (item.pattern.test(ruleString)) {
        risks.push({
          level: 'high',
          type: item.type,
          description: `${location}中${item.desc}`,
          location
        });
      }
    }

    return risks;
  }

  private static calculateRiskLevel(risks: SecurityRisk[]): SecurityRiskLevel {
    if (risks.some(r => r.level === 'critical')) return 'critical';
    if (risks.some(r => r.level === 'high')) return 'high';
    if (risks.some(r => r.level === 'medium')) return 'medium';
    return 'low';
  }

  private static generateSummary(risks: SecurityRisk[], level: SecurityRiskLevel): string {
    if (risks.length === 0) {
      return '未检测到安全风险';
    }

    const levelText: Record<SecurityRiskLevel, string> = {
      'low': '低风险',
      'medium': '中等风险',
      'high': '高风险',
      'critical': '严重风险'
    };

    const counts: Record<SecurityRiskLevel, number> = {
      'critical': 0,
      'high': 0,
      'medium': 0,
      'low': 0
    };

    for (let i = 0; i < risks.length; i++) {
      const risk = risks[i];
      counts[risk.level]++;
    }

    const parts: string[] = [];
    if (counts.critical > 0) parts.push(`严重 ${counts.critical}`);
    if (counts.high > 0) parts.push(`高危 ${counts.high}`);
    if (counts.medium > 0) parts.push(`中危 ${counts.medium}`);

    return `检测到 ${risks.length} 项风险 (${parts.join('、')}) - 总体风险等级: ${levelText[level]}`;
  }

  static getRiskLevelColor(level: SecurityRiskLevel): string {
    switch (level) {
      case 'critical': return '#FF0000';
      case 'high': return '#FF6B00';
      case 'medium': return '#FFB800';
      case 'low': return '#00C853';
      default: return '#999999';
    }
  }

  static getRiskLevelText(level: SecurityRiskLevel): string {
    switch (level) {
      case 'critical': return '严重风险';
      case 'high': return '高风险';
      case 'medium': return '中等风险';
      case 'low': return '低风险';
      default: return '未知';
    }
  }
}

export default SourceSandbox;
