import { Logger } from './Logger';
import { EntityDecoder } from '../core/utils/EntityDecoder';

export class CssSelectorParser {
  private static readonly TAG = 'CssSelectorParser';

  static selectElements(html: string, selector: string): string[] {
    const elements: string[] = [];

    try {
      if (!html || !selector) {
        Logger.warn(CssSelectorParser.TAG, `selectElements参数无效 - html: ${html ? '有内容' : '空'}, selector: ${selector || '空'}`);
        return elements;
      }

      Logger.debug(CssSelectorParser.TAG, `selectElements - selector: ${selector}, html长度: ${html.length}`);

      let processedSelector = selector.trim();
      let skipFirst = 0;

      // 移除@js:前缀
      if (processedSelector.startsWith('@js:') || processedSelector.startsWith('<js>')) {
        Logger.warn(CssSelectorParser.TAG, 'JavaScript规则暂不支持');
        return elements;
      }

      // 移除@css:前缀（Legado格式）
      if (processedSelector.startsWith('@css:')) {
        processedSelector = processedSelector.substring(5).trim();
      }

      // 处理@class.前缀（Legado格式简写）
      if (processedSelector.startsWith('class.')) {
        processedSelector = '.' + processedSelector.substring(6);
      }

      // 处理@tag.前缀（Legado格式简写）
      if (processedSelector.startsWith('tag.')) {
        processedSelector = processedSelector.substring(4);
      }

      // 处理XPath格式（简化处理，转换为正则）
      if (processedSelector.startsWith('//') || processedSelector.startsWith('./')) {
        Logger.debug(CssSelectorParser.TAG, `使用XPath解析: ${processedSelector}`);
        return CssSelectorParser.selectByXPath(html, processedSelector);
      }

      // 处理!N跳过前N个元素（如 tag.li!0 或 .class!1）
      const skipMatch = processedSelector.match(/!(\d+)$/);
      if (skipMatch) {
        skipFirst = parseInt(skipMatch[1], 10);
        processedSelector = processedSelector.substring(0, processedSelector.lastIndexOf('!'));
      }

      // 处理子选择器（如 .class@tag 或 .class@tag.div）
      if (processedSelector.includes('@')) {
        const atIndex = processedSelector.indexOf('@');
        const parentSelector = processedSelector.substring(0, atIndex).trim();
        const childSelector = processedSelector.substring(atIndex + 1).trim();

        const parentElements = CssSelectorParser.selectElements(html, parentSelector);
        for (const parentHtml of parentElements) {
          const childElements = CssSelectorParser.selectElements(parentHtml, childSelector);
          elements.push(...childElements);
        }
        
        if (skipFirst > 0 && elements.length > skipFirst) {
          return elements.slice(skipFirst);
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
      
      if (skipFirst > 0 && elements.length > skipFirst) {
        return elements.slice(skipFirst);
      }
    } catch (error) {
      Logger.error(CssSelectorParser.TAG, `选择元素失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    return elements;
  }

  private static selectByXPath(html: string, xpath: string): string[] {
    const elements: string[] = [];

    try {
      Logger.debug(CssSelectorParser.TAG, `selectByXPath - 原始xpath: ${xpath}`);

      let processedXpath = xpath;
      let skipFirst = 0;
      
      if (processedXpath.startsWith('//')) {
        processedXpath = processedXpath.substring(2);
      } else if (processedXpath.startsWith('./')) {
        processedXpath = processedXpath.substring(2);
      }

      Logger.debug(CssSelectorParser.TAG, `selectByXPath - 处理后xpath: ${processedXpath}`);

      // 处理 position()>N 语法，如 tr[position()>1]
      const posMatch = processedXpath.match(/\[position\(\)>(\d+)\]/);
      if (posMatch) {
        skipFirst = parseInt(posMatch[1], 10);
        processedXpath = processedXpath.replace(/\[position\(\)>\d+\]/, '');
      }

      // 处理路径分隔符 /，如 table/tr 或 div/a
      if (processedXpath.includes('/') && !processedXpath.startsWith('[')) {
        const parts = processedXpath.split('/').filter((p: string) => p.length > 0);
        Logger.debug(CssSelectorParser.TAG, `XPath路径分割: ${parts.join(' -> ')}`);
        let currentElements = [html];

        for (const part of parts) {
          const nextElements: string[] = [];
          for (const currentHtml of currentElements) {
            const found = CssSelectorParser.selectByXPathSimple(currentHtml, part);
            nextElements.push(...found);
          }
          currentElements = nextElements;
          Logger.debug(CssSelectorParser.TAG, `处理路径部分 "${part}" 后找到 ${currentElements.length} 个元素`);
          
          if (currentElements.length === 0) {
            Logger.warn(CssSelectorParser.TAG, `XPath路径部分 "${part}" 未找到匹配元素`);
            break;
          }
        }

        if (skipFirst > 0 && currentElements.length > skipFirst) {
          return currentElements.slice(skipFirst);
        }
        return currentElements;
      }

      // 简单XPath解析
      const result = CssSelectorParser.selectByXPathSimple(html, processedXpath);
      Logger.debug(CssSelectorParser.TAG, `XPath简单解析找到 ${result.length} 个元素`);
      
      if (skipFirst > 0 && result.length > skipFirst) {
        return result.slice(skipFirst);
      }
      return result;
    } catch (error) {
      Logger.error(CssSelectorParser.TAG, `XPath解析失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    return elements;
  }

  private static selectByXPathSimple(html: string, xpathPart: string): string[] {
    const elements: string[] = [];

    try {
      Logger.debug(CssSelectorParser.TAG, `selectByXPathSimple - xpathPart: ${xpathPart}`);

      // 解析XPath表达式，支持:
      // tagName
      // tagName[@attr="value"]
      // tagName[N] (索引)
      // tagName[contains(@class,"value")]
      // * (通配符)

      let tagName = '';
      let attrCondition = '';
      let index = -1;

      // 匹配 tagName[@attr="value"] 或 tagName[N] 或 tagName[contains(@class,"value")]
      const complexMatch = xpathPart.match(/^([a-zA-Z*]+)(?:\[([^\]]+)\])?$/);
      
      if (complexMatch) {
        tagName = complexMatch[1] === '*' ? '' : complexMatch[1];
        const condition = complexMatch[2] || '';

        if (condition) {
          // 检查是否是纯数字索引
          const indexMatch = condition.match(/^(\d+)$/);
          if (indexMatch) {
            index = parseInt(indexMatch[1], 10) - 1; // XPath索引从1开始
          } else {
            attrCondition = condition;
          }
        }
      } else {
        tagName = xpathPart;
      }

      Logger.debug(CssSelectorParser.TAG, `XPath解析 - tagName: ${tagName || '*'}, attrCondition: ${attrCondition || '无'}, index: ${index}`);

      let pattern: string;

      if (attrCondition) {
        // 处理 @class="value" 或 contains(@class,"value")
        const attrMatch = attrCondition.match(/@([a-zA-Z-]+)=["']([^"']*)["']/);
        const containsMatch = attrCondition.match(/contains\s*\(\s*@([a-zA-Z-]+)\s*,\s*["']([^"']*)["']\s*\)/);
        
        Logger.debug(CssSelectorParser.TAG, `属性匹配 - attrMatch: ${attrMatch ? '是' : '否'}, containsMatch: ${containsMatch ? '是' : '否'}`);
        
        if (attrMatch) {
          const attrName = attrMatch[1];
          const attrValue = attrMatch[2];

          if (tagName) {
            pattern = `<${CssSelectorParser.escapeRegex(tagName)}[^>]*${CssSelectorParser.escapeRegex(attrName)}=["']${CssSelectorParser.escapeRegex(attrValue)}["'][^>]*>([\\s\\S]*?)<\\/${CssSelectorParser.escapeRegex(tagName)}>`;
          } else {
            pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*${CssSelectorParser.escapeRegex(attrName)}=["']${CssSelectorParser.escapeRegex(attrValue)}["'][^>]*>([\\s\\S]*?)<\\/\\1>`;
          }
        } else if (containsMatch) {
          const attrName = containsMatch[1];
          const attrValue = containsMatch[2];

          if (tagName) {
            pattern = `<${CssSelectorParser.escapeRegex(tagName)}[^>]*${CssSelectorParser.escapeRegex(attrName)}=["'][^"']*${CssSelectorParser.escapeRegex(attrValue)}[^"']*["'][^>]*>([\\s\\S]*?)<\\/${CssSelectorParser.escapeRegex(tagName)}>`;
          } else {
            pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*${CssSelectorParser.escapeRegex(attrName)}=["'][^"']*${CssSelectorParser.escapeRegex(attrValue)}[^"']*["'][^>]*>([\\s\\S]*?)<\\/\\1>`;
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

      // 处理索引
      if (index >= 0 && index < elements.length) {
        return [elements[index]];
      }
    } catch (error) {
      Logger.error(CssSelectorParser.TAG, `XPath简单解析失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    return elements;
  }

  static extractValue(html: string, rule: string): string {
    try {
      if (!html || !rule) {
        return '';
      }

      let processedRule = rule.trim();
      let skipFirst = 0;

      // 移除@css:前缀
      if (processedRule.startsWith('@css:')) {
        processedRule = processedRule.substring(5).trim();
      }

      // 移除@class.前缀
      if (processedRule.startsWith('class.')) {
        processedRule = '.' + processedRule.substring(6);
      }

      // 移除@tag.前缀
      if (processedRule.startsWith('tag.')) {
        processedRule = processedRule.substring(4);
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

      // 处理!N跳过前N个元素
      const skipMatch = processedRule.match(/!(\d+)$/);
      if (skipMatch) {
        skipFirst = parseInt(skipMatch[1], 10);
        processedRule = processedRule.substring(0, processedRule.lastIndexOf('!'));
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

        if (skipFirst > 0 && elements.length > skipFirst) {
          elements = elements.slice(skipFirst);
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
