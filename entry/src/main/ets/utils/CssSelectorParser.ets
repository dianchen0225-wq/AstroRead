import { Logger } from './Logger';
import { EntityDecoder } from '../core/utils/EntityDecoder';
import { StringBuilderPool } from './ObjectPool';

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

      // 移除@js:前缀
      if (processedSelector.startsWith('@js:') || processedSelector.startsWith('<js>')) {
        Logger.warn(CssSelectorParser.TAG, 'JavaScript规则暂不支持');
        return elements;
      }

      // 移除@css:前缀（标准格式）
      if (processedSelector.startsWith('@css:')) {
        processedSelector = processedSelector.substring(5).trim();
      }

      // 处理||或运算符（标准格式：尝试多个选择器，返回第一个成功的结果）
      if (processedSelector.includes('||')) {
        const orSelectors = processedSelector.split('||').map((s: string) => s.trim()).filter((s: string) => s.length > 0);
        Logger.debug(CssSelectorParser.TAG, `检测到||或运算符，共${orSelectors.length}个选择器: ${orSelectors.join(', ')}`);
        
        for (const orSelector of orSelectors) {
          const result = CssSelectorParser.selectElements(html, orSelector);
          if (result.length > 0) {
            Logger.info(CssSelectorParser.TAG, `||或运算符匹配成功: ${orSelector}, 找到${result.length}个元素`);
            return result;
          }
        }
        Logger.warn(CssSelectorParser.TAG, `||或运算符所有选择器均未匹配`);
        return elements;
      }

      let skipFirst = 0;

      // 处理@class.前缀（标准格式简写）
      if (processedSelector.startsWith('class.')) {
        processedSelector = '.' + processedSelector.substring(6);
      }

      // 处理@tag.前缀（标准格式简写）
      if (processedSelector.startsWith('tag.')) {
        processedSelector = processedSelector.substring(4);
        Logger.debug(CssSelectorParser.TAG, `标准格式 tag.前缀转换: ${selector} -> ${processedSelector}`);
      }

      // 处理id.前缀（标准格式简写）
      if (processedSelector.startsWith('id.')) {
        processedSelector = '#' + processedSelector.substring(3);
        Logger.debug(CssSelectorParser.TAG, `标准格式 id.前缀转换: ${selector} -> ${processedSelector}`);
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

        Logger.debug(CssSelectorParser.TAG, `子选择器解析 - 父: ${parentSelector}, 子: ${childSelector}`);

        const parentElements = CssSelectorParser.selectElements(html, parentSelector);
        Logger.debug(CssSelectorParser.TAG, `父选择器找到 ${parentElements.length} 个元素`);

        // 使用 Set 去重，避免相同子元素被多次添加
        const uniqueChildElements = new Set<string>();

        for (let i = 0; i < parentElements.length; i++) {
          const parentHtml = parentElements[i];
          Logger.debug(CssSelectorParser.TAG, `解析第 ${i + 1}/${parentElements.length} 个父元素的子元素`);

          const childElements = CssSelectorParser.selectElements(parentHtml, childSelector);

          for (const child of childElements) {
            // 标准化后去重（移除多余空白）
            const normalizedChild = child.replace(/>\s+</g, '><').trim();
            if (!uniqueChildElements.has(normalizedChild)) {
              uniqueChildElements.add(normalizedChild);
              elements.push(child);
            }
          }
        }

        Logger.debug(CssSelectorParser.TAG, `子选择器共找到 ${elements.length} 个元素（去重后）`);

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

      // 处理后代选择器（如 div.book a 或 .list .item h3）
      // 修复：支持所有类型的后代选择器
      if (processedSelector.includes(' ')) {
        const parts = processedSelector.split(/\s+/).filter((p: string) => p.length > 0);
        if (parts.length > 1) {
          Logger.debug(CssSelectorParser.TAG, `后代选择器解析: ${parts.join(' -> ')}`);
          let currentElements = [html];

          for (let i = 0; i < parts.length; i++) {
            const part = parts[i];
            const nextElements: string[] = [];
            const seen = new Set<string>(); // 去重

            for (const currentHtml of currentElements) {
              const found = CssSelectorParser.selectElements(currentHtml, part);
              for (const element of found) {
                // 标准化去重
                const normalized = element.replace(/>\s+</g, '><').trim();
                if (!seen.has(normalized)) {
                  seen.add(normalized);
                  nextElements.push(element);
                }
              }
            }
            currentElements = nextElements;
            Logger.debug(CssSelectorParser.TAG, `后代选择器第 ${i + 1} 步 "${part}" 找到 ${currentElements.length} 个元素`);

            if (currentElements.length === 0) {
              break;
            }
          }

          if (index >= 0 && index < currentElements.length) {
            return [currentElements[index]];
          }
          return currentElements;
        }
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

        // 使用 StringBuilderPool 优化字符串拼接
        const pattern = StringBuilderPool.build((builder) => {
          builder.append('<');
          if (tagName) {
            builder.append(CssSelectorParser.escapeRegex(tagName));
          } else {
            builder.append('([a-zA-Z][a-zA-Z0-9]*)');
          }
          builder.append('[^>]*');

          if (id) {
            builder.append(`id=["']${CssSelectorParser.escapeRegex(id)}["'][^>]*`);
          }

          if (className) {
            builder.append(`class=["'][^"']*\\b${CssSelectorParser.escapeRegex(className)}\\b[^"']*["'][^>]*`);
          }

          builder.append('>([\\s\\S]*?)<\\/');

          if (tagName) {
            builder.append(CssSelectorParser.escapeRegex(tagName));
          } else {
            builder.append('\\1');
          }
          builder.append('>');
        });

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
        Logger.debug(CssSelectorParser.TAG, `ID选择器解析 - id: ${id}`);
        
        const regex = new RegExp(
          `<([a-zA-Z][a-zA-Z0-9]*)[^>]*\\bid\\s*=\\s*["']${CssSelectorParser.escapeRegex(id)}["'][^>]*>([\\s\\S]*?)(?:<\\/\\1>|(?=<[a-zA-Z]|$))`,
          'gi'
        );
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }
        
        if (elements.length === 0) {
          Logger.debug(CssSelectorParser.TAG, `ID选择器尝试宽松匹配`);
          const looseRegex = new RegExp(
            `<[^>]*\\bid\\s*=\\s*["']${CssSelectorParser.escapeRegex(id)}["'][^>]*>([\\s\\S]*?)(?=<[a-zA-Z][^>]*\\bid\\s*=|$)`,
            'gi'
          );
          const looseMatches = html.matchAll(looseRegex);
          for (const match of looseMatches) {
            elements.push(match[0]);
          }
        }
        
        Logger.debug(CssSelectorParser.TAG, `ID选择器找到 ${elements.length} 个元素`);
      }
      // 处理标签选择器
      else {
        const tagName = processedSelector.split(/[.\s#\[@]/)[0];
        if (tagName && tagName.length > 0) {
          Logger.debug(CssSelectorParser.TAG, `标签选择器解析 - tagName: ${tagName}`);
          const regex = new RegExp(
            `<${CssSelectorParser.escapeRegex(tagName)}[^>]*>([\\s\\S]*?)<\\/${CssSelectorParser.escapeRegex(tagName)}>`,
            'gi'
          );
          const matches = html.matchAll(regex);
          for (const match of matches) {
            elements.push(match[0]);
          }
          Logger.debug(CssSelectorParser.TAG, `标签选择器找到 ${elements.length} 个元素`);
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

      // 移除id.前缀
      if (processedRule.startsWith('id.')) {
        processedRule = '#' + processedRule.substring(3);
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
      // 标准格式支持多个替换规则用|分隔
      let replacePatterns: string[] = [];
      if (processedRule.includes('##')) {
        const parts = processedRule.split('##');
        processedRule = parts[0];
        if (parts.length > 1) {
          const patternsStr = parts.slice(1).join('##');
          replacePatterns = patternsStr.split('|').map((p: string) => p.trim()).filter((p: string) => p.length > 0);
        }
      }

      // 处理{{}}模板（标准格式）
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

        Logger.debug(CssSelectorParser.TAG, `属性选择器解析 - selector: ${selector}, attr: ${attr}`);

        let elements: string[];
        if (selector) {
          elements = CssSelectorParser.selectElements(html, selector);
        } else {
          elements = [html];
        }

        Logger.debug(CssSelectorParser.TAG, `选择器找到 ${elements.length} 个元素`);

        if (skipFirst > 0 && elements.length > skipFirst) {
          elements = elements.slice(skipFirst);
        }

        if (elements.length > 0) {
          const elementIndex = index >= 0 && index < elements.length ? index : 0;
          const elementHtml = elements[elementIndex];

          if (attr === 'text' || attr === 'text()') {
            let text = CssSelectorParser.extractTextContent(elementHtml);
            text = CssSelectorParser.applyReplacePatterns(text, replacePatterns);
            return text.trim();
          } else if (attr === 'textNodes') {
            let text = CssSelectorParser.extractTextNodes(elementHtml);
            text = CssSelectorParser.applyReplacePatterns(text, replacePatterns);
            return text.trim();
          } else if (attr === 'href') {
            const hrefMatch = elementHtml.match(/href=["']([^"']*)["']/i);
            let href = hrefMatch ? hrefMatch[1] : '';
            href = CssSelectorParser.applyReplacePatterns(href, replacePatterns);
            return href;
          } else if (attr === 'src') {
            const srcMatch = elementHtml.match(/src=["']([^"']*)["']/i);
            let src = srcMatch ? srcMatch[1] : '';
            src = CssSelectorParser.applyReplacePatterns(src, replacePatterns);
            return src;
          } else {
            const attrRegex = new RegExp(`${CssSelectorParser.escapeRegex(attr)}=["']([^"']*)["']`, 'i');
            const attrMatch = elementHtml.match(attrRegex);
            let value = attrMatch ? attrMatch[1] : '';
            value = CssSelectorParser.applyReplacePatterns(value, replacePatterns);
            return value;
          }
        }
      }

      // 处理纯选择器（无@属性）
      let elements = CssSelectorParser.selectElements(html, processedRule);
      if (elements.length > 0) {
        const elementIndex = index >= 0 && index < elements.length ? index : 0;
        let text = CssSelectorParser.extractTextContent(elements[elementIndex]);
        text = CssSelectorParser.applyReplacePatterns(text, replacePatterns);
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

    // 递归提取所有文本节点
    let text = html;

    // 1. 移除 script/style 标签及其内容
    text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
    text = text.replace(/<noscript[^>]*>[\s\S]*?<\/noscript>/gi, '');
    text = text.replace(/<iframe[^>]*>[\s\S]*?<\/iframe>/gi, '');

    // 2. 将某些标签替换为换行，提高可读性
    text = text.replace(/<(br|hr)\s*\/?>/gi, '\n');
    text = text.replace(/<\/\s*(p|div|h[1-6]|li|tr|section|article|header|footer)[^>]*>/gi, '\n');

    // 3. 移除所有 HTML 标签，但保留标签之间的内容
    text = text.replace(/<[^>]+>/g, '');

    // 4. 解码 HTML 实体
    text = EntityDecoder.decode(text);

    // 5. 清理多余空白和换行
    text = text.replace(/\n\s*\n/g, '\n');
    text = text.replace(/[ \t]+/g, ' ');

    return text.trim();
  }

  /**
   * 提取所有文本节点内容（标准格式的@textNodes）
   * 递归提取HTML中所有文本内容，保留换行
   */
  static extractTextNodes(html: string): string {
    if (!html) {
      return '';
    }

    let text = html;
    
    text = text.replace(/<br\s*\/?>/gi, '\n');
    text = text.replace(/<\/p>/gi, '\n');
    text = text.replace(/<\/div>/gi, '\n');
    text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
    text = text.replace(/<!--[\s\S]*?-->/g, '');
    text = text.replace(/<[^>]+>/g, '');
    
    text = EntityDecoder.decode(text);
    
    text = text.replace(/\n\s*\n/g, '\n');
    text = text.replace(/[ \t]+/g, ' ');
    
    return text;
  }

  /**
   * 应用多个替换规则（标准格式，用|分隔）
   */
  static applyReplacePatterns(text: string, patterns: string[]): string {
    if (!text || patterns.length === 0) {
      return text;
    }

    let result = text;
    for (const pattern of patterns) {
      if (!pattern) continue;
      
      try {
        const regex = new RegExp(pattern, 'g');
        result = result.replace(regex, '');
      } catch (e) {
        Logger.warn(CssSelectorParser.TAG, `替换规则正则错误: ${pattern}, 错误: ${e}`);
        result = result.replace(new RegExp(CssSelectorParser.escapeRegex(pattern), 'g'), '');
      }
    }
    
    return result;
  }

  static escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
}
