/**
  * ContentPurifier - 内容净化工具
  * 用于清理和格式化HTML内容
  */

import { ParserCore } from './ParserCore';

interface ReplaceRuleItem {
  from: string;
  to: string;
}

interface ReplaceConfig {
  removeTags?: string[];
  replace?: ReplaceRuleItem[];
  removeHtmlTags?: boolean;
}

export function purifyContent(content: string, replaceRule?: string): string {
  if (!content) return '';

  let purified = content;

  purified = purified.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
  purified = purified.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
  purified = purified.replace(/<!--[\s\S]*?-->/g, '');
  purified = purified.replace(/<[^>]+>/g, '');

  if (replaceRule) {
    try {
      const config: ReplaceConfig = JSON.parse(replaceRule) as ReplaceConfig;

      if (config.removeTags && Array.isArray(config.removeTags)) {
        for (const tag of config.removeTags) {
          const regex = new RegExp(`<${tag}[^>]*>[\\s\\S]*?<\\/${tag}>`, 'gi');
          purified = purified.replace(regex, '');
        }
      }

      if (config.replace && Array.isArray(config.replace)) {
        for (const item of config.replace) {
          if (item.from && item.to !== undefined) {
            try {
              const regex = new RegExp(item.from, 'g');
              purified = purified.replace(regex, item.to);
            } catch {
              purified = purified.replace(new RegExp(ParserCore.escapeRegex(item.from), 'g'), item.to);
            }
          }
        }
      }

      if (config.removeHtmlTags) {
        purified = purified.replace(/<[^>]+>/g, '');
      }
    } catch {
    }
  }

  purified = ParserCore.decodeHtmlEntities(purified);

  purified = purified.replace(/\n{3,}/g, '\n\n');
  purified = purified.replace(/[ \t]+/g, ' ');
  purified = purified.trim();

  return purified;
}
