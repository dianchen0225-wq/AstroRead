import { Logger } from './Logger';
import { EntityDecoder } from '../core/utils/EntityDecoder';

export class CssSelectorParser {
  private static readonly TAG = 'CssSelectorParser';

  static selectElements(html: string, selector: string): string[] {
    const elements: string[] = [];

    try {
      if (!html || !selector) {
        return elements;
      }

      let processedSelector = selector.trim();

      // 移除@js:前缀
      if (processedSelector.startsWith('@js:') || processedSelector.startsWith('<js>')) {
        Logger.warn(CssSelectorParser.TAG, 'JavaScript规则暂不支持');
        return elements;
      }

      // 移除@css:前缀（Legado格式）
      if (processedSelector.startsWith('@css:')) {
        processedSelector = processedSelector.substring(5).trim();
      }

      // 移除@class.前缀（Legado格式简写）
      if (processedSelector.startsWith('class.')) {
        processedSelector = '.' + processedSelector.substring(6);
      }

      // 处理XPath格式（简化处理，转换为正则）
      if (processedSelector.startsWith('//') || processedSelector.startsWith('./')) {
        return CssSelectorParser.selectByXPath(html, processedSelector);
      }

      // 处理子选择器（如 .class@tag 或 .class.0）
      if (processedSelector.includes('@')) {
        const atIndex = processedSelector.indexOf('@');
        const parentSelector = processedSelector.substring(0, atIndex).trim();
        const childSelector = processedSelector.substring(atIndex + 1).trim();

        const parentElements = CssSelectorParser.selectElements(html, parentSelector);
        for (const parentHtml of parentElements) {
          const childElements = CssSelectorParser.selectElements(parentHtml, childSelector);
          elements.push(...childElements);
        }
        return elements;
      }

      // 处理索引选择器（如 .class.0）
      let index = -1;
      const indexMatch = processedSelector.match(/\.(\d+)$/);
      if (indexMatch) {
        index = parseInt(indexMatch[1], 10);
        processedSelector = processedSelector.substring(0, processedSelector.lastIndexOf('.'));
      }

      // 处理后代选择器（如 div.book a）
      if (processedSelector.includes(' ') && !processedSelector.startsWith('.') && !processedSelector.startsWith('#')) {
        const parts = processedSelector.split(/\s+/);
        let currentElements = [html];

        for (const part of parts) {
          const nextElements: string[] = [];
          for (const currentHtml of currentElements) {
            const found = CssSelectorParser.selectElements(currentHtml, part);
            nextElements.push(...found);
          }
          currentElements = nextElements;
        }

        if (index >= 0 && index < currentElements.length) {
          return [currentElements[index]];
        }
        return currentElements;
      }

      // 处理属性选择器（如 [class="book"]）
      if (processedSelector.startsWith('[')) {
        const attrMatch = processedSelector.match(/^\[([a-zA-Z-]+)=(["'])([^"']*)\2\]$/);
        if (attrMatch) {
          const attrName = attrMatch[1];
          const attrValue = attrMatch[3];
          const regex = new RegExp(
            `<([a-zA-Z][a-zA-Z0-9]*)[^>]*${CssSelectorParser.escapeRegex(attrName)}=["']${CssSelectorParser.escapeRegex(attrValue)}["'][^>]*>([\\s\\S]*?)<\\/\\1>`,
            'gi'
          );
          const matches = html.matchAll(regex);
          for (const match of matches) {
            elements.push(match[0]);
          }
          return elements;
        }
      }

      // 处理复合选择器（如 div.book 或 a#link）
      const compoundMatch = processedSelector.match(/^([a-zA-Z][a-zA-Z0-9]*)?(\.([a-zA-Z0-9_-]+))?(#([a-zA-Z0-9_-]+))?$/);
      if (compoundMatch) {
        const tagName = compoundMatch[1] || '';
        const className = compoundMatch[3] || '';
        const id = compoundMatch[5] || '';

        let pattern = '<';
        if (tagName) {
          pattern += CssSelectorParser.escapeRegex(tagName);
        } else {
          pattern += '([a-zA-Z][a-zA-Z0-9]*)';
        }
        pattern += '[^>]*';

        if (id) {
          pattern += `id=["']${CssSelectorParser.escapeRegex(id)}["'][^>]*`;
        }

        if (className) {
          pattern += `class=["'][^"']*\\b${CssSelectorParser.escapeRegex(className)}\\b[^"']*["'][^>]*`;
        }

        pattern += '>([\\s\\S]*?)<\\/';

        if (tagName) {
          pattern += CssSelectorParser.escapeRegex(tagName);
        } else {
          pattern += '\\1';
        }
        pattern += '>';

        const regex = new RegExp(pattern, 'gi');
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }

        if (index >= 0 && index < elements.length) {
          return [elements[index]];
        }
        return elements;
      }

      // 处理类选择器 .className
      if (processedSelector.startsWith('.')) {
        const className = processedSelector.substring(1).split(/[.\s#\[]/)[0];
        const regex = new RegExp(
          `<([a-zA-Z][a-zA-Z0-9]*)[^>]*class=["'][^"']*\\b${CssSelectorParser.escapeRegex(className)}\\b[^"']*["'][^>]*>([\\s\\S]*?)<\\/\\1>`,
          'gi'
        );
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }
      }
      // 处理ID选择器 #id
      else if (processedSelector.startsWith('#')) {
        const id = processedSelector.substring(1).split(/[.\s#\[]/)[0];
        const regex = new RegExp(
          `<([a-zA-Z][a-zA-Z0-9]*)[^>]*id=["']${CssSelectorParser.escapeRegex(id)}["'][^>]*>([\\s\\S]*?)<\\/\\1>`,
          'gi'
        );
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }
      }
      // 处理标签选择器
      else {
        const tagName = processedSelector.split(/[.\s#\[@]/)[0];
        if (tagName && tagName.length > 0) {
          const regex = new RegExp(
            `<${CssSelectorParser.escapeRegex(tagName)}[^>]*>([\\s\\S]*?)<\\/${CssSelectorParser.escapeRegex(tagName)}>`,
            'gi'
          );
          const matches = html.matchAll(regex);
          for (const match of matches) {
            elements.push(match[0]);
          }
        }
      }

      if (index >= 0 && index < elements.length) {
        return [elements[index]];
      }
    } catch (error) {
      Logger.error(CssSelectorParser.TAG, `选择元素失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    return elements;
  }

  private static selectByXPath(html: string, xpath: string): string[] {
    const elements: string[] = [];

    try {
      // 简化的XPath解析，支持常见格式
      // 例如: //div[@class="book"] 或 //a[@class="title"]

      let processedXpath = xpath;
      if (processedXpath.startsWith('//')) {
        processedXpath = processedXpath.substring(2);
      } else if (processedXpath.startsWith('./')) {
        processedXpath = processedXpath.substring(2);
      }

      // 解析XPath表达式
      const xpathMatch = processedXpath.match(/^([a-zA-Z*]+)(?:\[([^\]]+)\])?$/);

      if (xpathMatch) {
        const tagName = xpathMatch[1] === '*' ? '' : xpathMatch[1];
        const condition = xpathMatch[2] || '';

        let pattern: string;

        if (condition) {
          // 处理属性条件，如 @class="book"
          const attrMatch = condition.match(/@([a-zA-Z-]+)=["']([^"']*)["']/);
          if (attrMatch) {
            const attrName = attrMatch[1];
            const attrValue = attrMatch[2];

            if (tagName) {
              pattern = `<${CssSelectorParser.escapeRegex(tagName)}[^>]*${CssSelectorParser.escapeRegex(attrName)}=["']${CssSelectorParser.escapeRegex(attrValue)}["'][^>]*>([\\s\\S]*?)<\\/${CssSelectorParser.escapeRegex(tagName)}>`;
            } else {
              pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*${CssSelectorParser.escapeRegex(attrName)}=["']${CssSelectorParser.escapeRegex(attrValue)}["'][^>]*>([\\s\\S]*?)<\\/\\1>`;
            }
          } else {
            // 其他条件，使用通用匹配
            if (tagName) {
              pattern = `<${CssSelectorParser.escapeRegex(tagName)}[^>]*>([\\s\\S]*?)<\\/${CssSelectorParser.escapeRegex(tagName)}>`;
            } else {
              pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*>([\\s\\S]*?)<\\/\\1>`;
            }
          }
        } else {
          if (tagName) {
            pattern = `<${CssSelectorParser.escapeRegex(tagName)}[^>]*>([\\s\\S]*?)<\\/${CssSelectorParser.escapeRegex(tagName)}>`;
          } else {
            pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*>([\\s\\S]*?)<\\/\\1>`;
          }
        }

        const regex = new RegExp(pattern, 'gi');
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }
      }
    } catch (error) {
      Logger.error(CssSelectorParser.TAG, `XPath解析失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    return elements;
  }

  static extractValue(html: string, rule: string): string {
    try {
      if (!html || !rule) {
        return '';
      }

      let processedRule = rule.trim();

      // 移除@css:前缀
      if (processedRule.startsWith('@css:')) {
        processedRule = processedRule.substring(5).trim();
      }

      // 移除@class.前缀
      if (processedRule.startsWith('class.')) {
        processedRule = '.' + processedRule.substring(6);
      }

      // 处理XPath格式
      if (processedRule.startsWith('//') || processedRule.startsWith('./')) {
        const elements = CssSelectorParser.selectByXPath(html, processedRule);
        if (elements.length > 0) {
          return CssSelectorParser.extractTextContent(elements[0]);
        }
        return '';
      }

      // 处理##替换规则（如：##简介：）
      let replacePattern = '';
      if (processedRule.includes('##')) {
        const parts = processedRule.split('##');
        processedRule = parts[0];
        replacePattern = parts[1] || '';
      }

      // 处理{{}}模板（Legado格式）
      if (processedRule.includes('{{')) {
        return CssSelectorParser.processTemplate(html, processedRule);
      }

      // 处理索引选择器（如 .class.0）
      let index = -1;
      const indexMatch = processedRule.match(/\.(\d+)$/);
      if (indexMatch) {
        index = parseInt(indexMatch[1], 10);
        processedRule = processedRule.substring(0, processedRule.lastIndexOf('.'));
      }

      // 处理@属性选择器
      if (processedRule.includes('@')) {
        const atIndex = processedRule.lastIndexOf('@');
        const selector = processedRule.substring(0, atIndex).trim();
        const attr = processedRule.substring(atIndex + 1).trim();

        let elements: string[];
        if (selector) {
          elements = CssSelectorParser.selectElements(html, selector);
        } else {
          elements = [html];
        }

        if (elements.length > 0) {
          const elementIndex = index >= 0 && index < elements.length ? index : 0;
          const elementHtml = elements[elementIndex];

          if (attr === 'text' || attr === 'text()') {
            let text = CssSelectorParser.extractTextContent(elementHtml);
            if (replacePattern) {
              text = text.replace(new RegExp(CssSelectorParser.escapeRegex(replacePattern), 'g'), '');
            }
            return text.trim();
          } else if (attr === 'href') {
            const hrefMatch = elementHtml.match(/href=["']([^"']*)["']/i);
            let href = hrefMatch ? hrefMatch[1] : '';
            if (replacePattern) {
              href = href.replace(new RegExp(CssSelectorParser.escapeRegex(replacePattern), 'g'), '');
            }
            return href;
          } else if (attr === 'src') {
            const srcMatch = elementHtml.match(/src=["']([^"']*)["']/i);
            let src = srcMatch ? srcMatch[1] : '';
            if (replacePattern) {
              src = src.replace(new RegExp(CssSelectorParser.escapeRegex(replacePattern), 'g'), '');
            }
            return src;
          } else {
            const attrRegex = new RegExp(`${CssSelectorParser.escapeRegex(attr)}=["']([^"']*)["']`, 'i');
            const attrMatch = elementHtml.match(attrRegex);
            let value = attrMatch ? attrMatch[1] : '';
            if (replacePattern) {
              value = value.replace(new RegExp(CssSelectorParser.escapeRegex(replacePattern), 'g'), '');
            }
            return value;
          }
        }
      }

      // 处理纯选择器（无@属性）
      let elements = CssSelectorParser.selectElements(html, processedRule);
      if (elements.length > 0) {
        const elementIndex = index >= 0 && index < elements.length ? index : 0;
        let text = CssSelectorParser.extractTextContent(elements[elementIndex]);
        if (replacePattern) {
          text = text.replace(new RegExp(CssSelectorParser.escapeRegex(replacePattern), 'g'), '');
        }
        return text.trim();
      }

      return '';
    } catch (error) {
      Logger.error(CssSelectorParser.TAG, `提取值失败: ${error instanceof Error ? error.message : String(error)}`);
      return '';
    }
  }

  private static processTemplate(html: string, template: string): string {
    try {
      let result = template;

      const templateMatches = template.matchAll(/\{\{([^}]+)\}\}/g);
      for (const match of templateMatches) {
        const placeholder = match[0];
        const innerRule = match[1].trim();

        const value = CssSelectorParser.extractValue(html, innerRule);
        result = result.replace(placeholder, value);
      }

      return result;
    } catch (error) {
      Logger.error(CssSelectorParser.TAG, `模板处理失败: ${error instanceof Error ? error.message : String(error)}`);
      return template;
    }
  }

  static extractTextContent(html: string): string {
    if (!html) {
      return '';
    }
    return EntityDecoder.cleanHtml(html);
  }

  static escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
}
