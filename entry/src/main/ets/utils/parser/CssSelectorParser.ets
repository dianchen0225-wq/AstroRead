import { Logger } from '../performance/Logger';
import { EntityDecoder } from '../../core/utils/EntityDecoder';

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
        for (const parentHtml of parentElements) {
          const childElements = CssSelectorParser.selectElements(parentHtml, childSelector);
          for (const childElement of childElements) {
            elements.push(childElement);
          }
        }
        
        Logger.debug(CssSelectorParser.TAG, `子选择器共找到 ${elements.length} 个元素`);
        
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
            for (const element of found) {
              nextElements.push(element);
            }
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

      // 处理复合选择器（如 div.book 或 a#link 或 div.class1.class2）
      // 支持多class选择器，如 .class1.class2 或 tag.class1.class2
      const compoundMatch = processedSelector.match(/^([a-zA-Z][a-zA-Z0-9]*)?((?:\.[a-zA-Z0-9_-]+)+)?(#([a-zA-Z0-9_-]+))?$/);
      if (compoundMatch) {
        const tagName = compoundMatch[1] || '';
        const classNamesStr = compoundMatch[2] || '';
        const id = compoundMatch[4] || '';

        // 提取所有class名
        const classNames: string[] = [];
        if (classNamesStr) {
          const classMatches = classNamesStr.match(/\.[a-zA-Z0-9_-]+/g);
          if (classMatches) {
            for (const cm of classMatches) {
              classNames.push(cm.substring(1)); // 移除前面的点
            }
          }
        }

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

        // 处理多class - 每个class都需要在class属性中匹配
        if (classNames.length > 0) {
          pattern += "class=[\"'][^\"']*";
          for (const cn of classNames) {
            pattern += `(?=.*\\b${CssSelectorParser.escapeRegex(cn)}\\b)`;
          }
          pattern += "[^\"']*[\"'][^>]*";
        }

        pattern += '>([\\s\\S]*?)<\\/';

        if (tagName) {
          pattern += CssSelectorParser.escapeRegex(tagName);
        } else {
          pattern += '\\1';
        }
        pattern += '>';

        Logger.debug(CssSelectorParser.TAG, `复合选择器解析 - tagName: ${tagName || '*'}, classes: [${classNames.join(', ')}], id: ${id || '无'}`);

        const regex = new RegExp(pattern, 'gi');
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }

        Logger.debug(CssSelectorParser.TAG, `复合选择器找到 ${elements.length} 个元素`);

        if (index >= 0 && index < elements.length) {
          return [elements[index]];
        }
        return elements;
      }

      // 处理类选择器 .className 或 .class1.class2（支持多class）
      if (processedSelector.startsWith('.')) {
        // 提取所有class名（支持多class如 .class1.class2）
        const classNames: string[] = [];
        const classMatches = processedSelector.match(/\.[a-zA-Z0-9_-]+/g);
        if (classMatches) {
          for (const cm of classMatches) {
            classNames.push(cm.substring(1)); // 移除前面的点
          }
        }

        Logger.debug(CssSelectorParser.TAG, `类选择器解析 - classes: [${classNames.join(', ')}]`);

        if (classNames.length > 0) {
          // 方法1：使用改进的多class匹配正则
          // 使用非贪婪匹配确保每个类名都存在，更宽松的格式支持
          let pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*class=["'][^"']*`;
          for (const cn of classNames) {
            pattern += `(?:[^"']*\\b${CssSelectorParser.escapeRegex(cn)}\\b)`;
          }
          pattern += `[^"']*["'][^>]*>([\\s\\S]*?)<\\/\\1>`;

          const regex = new RegExp(pattern, 'gi');
          const matches = html.matchAll(regex);
          for (const match of matches) {
            elements.push(match[0]);
          }

          Logger.debug(CssSelectorParser.TAG, `类选择器方法1找到 ${elements.length} 个元素`);

          // 方法2：如果方法1失败，使用交集策略
          if (elements.length === 0) {
            Logger.debug(CssSelectorParser.TAG, `类选择器方法1失败，尝试方法2`);
            
            const individualResults: string[][] = [];
            for (const cn of classNames) {
              // 支持 class="xxx"、class='xxx'、class=xxx 三种格式
              const singlePattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*class=["']?[^"'>]*\\b${CssSelectorParser.escapeRegex(cn)}\\b[^"'>]*["']?[^>]*>([\\s\\S]*?)<\\/\\1>`;
              const singleRegex = new RegExp(singlePattern, 'gi');
              const singleMatches: string[] = [];
              for (const m of html.matchAll(singleRegex)) {
                singleMatches.push(m[0]);
              }
              individualResults.push(singleMatches);
              Logger.debug(CssSelectorParser.TAG, `类 ${cn} 找到 ${singleMatches.length} 个元素`);
            }
            
            // 取交集 - 包含所有类名的元素
            if (individualResults.length > 0 && individualResults[0].length > 0) {
              // 使用 outerHTML 作为唯一标识
              const getElementKey = (el: string): string => {
                // 提取标签名和class属性作为key
                const tagMatch = el.match(/^<([a-zA-Z][a-zA-Z0-9]*)/);
                const classMatch = el.match(/class=["']([^"]*)["']/);
                return `${tagMatch?.[1] || ''}:${classMatch?.[1] || ''}`;
              };
              
              const firstSet = new Map<string, string>();
              for (const item of individualResults[0]) {
                firstSet.set(getElementKey(item), item);
              }
              for (let i = 1; i < individualResults.length; i++) {
                const currentKeys = new Set(individualResults[i].map(getElementKey));
                for (const entry of firstSet.entries()) {
                  const key = entry[0];
                  const item = entry[1];
                  if (!currentKeys.has(key)) {
                    firstSet.delete(key);
                  }
                }
              }
              
              for (const value of firstSet.values()) {
                elements.push(value);
              }
              Logger.debug(CssSelectorParser.TAG, `类选择器方法2找到 ${elements.length} 个元素`);
            }
          }
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

  /**
   * 将XPath表达式转换为CSS选择器
   * 支持以下转换规则：
   * 1. //tag -> tag (后代选择器)
   * 2. /tag -> > tag (子选择器)
   * 3. [@class="value"] -> .value
   * 4. [@id="value"] -> #value
   * 5. [N] -> :nth-of-type(N)
   * 6. @attr -> [attr]
   * 7. [contains(@class,"value")] -> [class*="value"]
   * 8. [contains(@attr,"value")] -> [attr*="value"]
   * 9. [starts-with(@attr,"value")] -> [attr^="value"]
   * 10. [ends-with(@attr,"value")] -> [attr$="value"]
   * 11. * -> * (通配符)
   * 12. //* -> * (任意后代)
   * 13. text() -> 特殊处理，返回text()标记
   */
  static convertXPathToCss(xpath: string): string {
    try {
      Logger.debug(CssSelectorParser.TAG, `convertXPathToCss - 原始xpath: ${xpath}`);

      if (!xpath || xpath.trim().length === 0) {
        return '';
      }

      let css = xpath.trim();

      // 处理text()函数
      if (css.includes('text()')) {
        // text() 需要特殊处理，保留标记
        css = css.replace(/text\(\)/g, '{{text}}');
      }

      // 处理 // (任意后代)
      // 将 // 替换为 空格（后代选择器）
      css = css.replace(/\/\//g, ' ');

      // 处理 / (直接子元素)
      // 将 / 替换为 > (子选择器)
      // 注意：需要先处理 // 再处理 /
      css = css.replace(/\/(?![\/])/g, ' > ');

      // 处理 [contains(@attr,"value")] 或 [contains(@attr,'value')]
      css = css.replace(/\[contains\s*\(\s*@([a-zA-Z_-]+)\s*,\s*["']([^"']+)["']\s*\)\]/g, '[$1*="$2"]');

      // 处理 [starts-with(@attr,"value")] 或 [starts-with(@attr,'value')]
      css = css.replace(/\[starts-with\s*\(\s*@([a-zA-Z_-]+)\s*,\s*["']([^"']+)["']\s*\)\]/g, '[$1^="$2"]');

      // 处理 [ends-with(@attr,"value")] 或 [ends-with(@attr,'value')]
      css = css.replace(/\[ends-with\s*\(\s*@([a-zA-Z_-]+)\s*,\s*["']([^"']+)["']\s*\)\]/g, '[$1$="$2"]');

      // 处理 [@class="value"] -> .value
      // 处理 [@class='value'] -> .value
      css = css.replace(/\[@class=["']([^"']+)["']\]/g, (match: string, classValue: string) => {
        // 处理多class情况
        const classes = classValue.split(/\s+/).filter((c: string) => c.length > 0);
        return '.' + classes.join('.');
      });

      // 处理 [@id="value"] -> #value
      css = css.replace(/\[@id=["']([^"']+)["']\]/g, '#$1');

      // 处理其他属性选择器 [@attr="value"] -> [attr="value"]
      css = css.replace(/\[@([a-zA-Z_-]+)=["']([^"']+)["']\]/g, '[$1="$2"]');

      // 处理 [N] -> :nth-of-type(N)
      // XPath索引从1开始，CSS :nth-of-type 也从1开始
      css = css.replace(/\[(\d+)\]/g, ':nth-of-type($1)');

      // 处理 [@attr] -> [attr]（属性存在选择器）
      css = css.replace(/\[@([a-zA-Z_-]+)\]/g, '[$1]');

      // 处理 position()>N 语法
      css = css.replace(/\[position\(\)>(\d+)\]/g, ':nth-of-type(n+$1)');

      // 处理 position()<N 语法
      css = css.replace(/\[position\(\)<(\d+)\]/g, ':nth-of-type(-n+$1)');

      // 处理 position()=N 语法
      css = css.replace(/\[position\(\)=(\d+)\]/g, ':nth-of-type($1)');

      // 处理 last() 语法
      css = css.replace(/\[last\(\)\]/g, ':last-of-type');

      // 处理 [last()-N] 语法
      css = css.replace(/\[last\(\)-(\d+)\]/g, ':nth-last-of-type($1)');

      // 处理 not() 语法 [not(@attr)] 或 [not(contains(@attr,"value"))]
      css = css.replace(/\[not\(@([a-zA-Z_-]+)\)\]/g, ':not([$1])');
      css = css.replace(/\[not\(contains\s*\(\s*@([a-zA-Z_-]+)\s*,\s*["']([^"']+)["']\s*\)\)\]/g, ':not([$1*="$2"])');

      // 处理 . (当前节点) - 在CSS中通常不需要
      css = css.replace(/\s+\.\s+/g, ' ');
      css = css.replace(/^\s*\.\s*/, '');
      css = css.replace(/\s*\.\s*$/, '');

      // 清理多余的空格
      css = css.replace(/\s+/g, ' ').trim();
      css = css.replace(/\s*>\s*/g, ' > ');

      // 恢复text()标记
      css = css.replace(/\{\{text\}\}/g, 'text()');

      Logger.debug(CssSelectorParser.TAG, `convertXPathToCss - 转换结果: ${css}`);

      return css;
    } catch (error) {
      Logger.error(CssSelectorParser.TAG, `XPath转CSS失败: ${error instanceof Error ? error.message : String(error)}`);
      return xpath;
    }
  }

  /**
   * 解析XPath表达式并提取元素
   * 增强版本，支持更多XPath表达式
   */
  private static selectByXPath(html: string, xpath: string): string[] {
    const elements: string[] = [];

    try {
      Logger.debug(CssSelectorParser.TAG, `selectByXPath - 原始xpath: ${xpath}`);

      // 首先尝试转换为CSS选择器
      const cssSelector = CssSelectorParser.convertXPathToCss(xpath);
      Logger.debug(CssSelectorParser.TAG, `selectByXPath - 转换后的CSS: ${cssSelector}`);

      // 如果转换成功且不是纯XPath语法，使用CSS选择器
      if (cssSelector && !cssSelector.includes('text()') && !cssSelector.includes('//')) {
        // 尝试使用CSS选择器解析
        const cssResult = CssSelectorParser.selectElementsByCss(html, cssSelector);
        if (cssResult.length > 0) {
          Logger.debug(CssSelectorParser.TAG, `使用CSS选择器找到 ${cssResult.length} 个元素`);
          return cssResult;
        }
      }

      // 回退到原生XPath解析
      return CssSelectorParser.selectByXPathNative(html, xpath);
    } catch (error) {
      Logger.error(CssSelectorParser.TAG, `XPath解析失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    return elements;
  }

  /**
   * 使用CSS选择器解析元素（支持增强的CSS语法）
   */
  private static selectElementsByCss(html: string, cssSelector: string): string[] {
    const elements: string[] = [];

    try {
      // 处理后代选择器（空格分隔）
      if (cssSelector.includes(' ') && !cssSelector.includes('>')) {
        const parts = cssSelector.split(/\s+/).filter((p: string) => p.length > 0);
        let currentElements = [html];

        for (const part of parts) {
          const nextElements: string[] = [];
          for (const currentHtml of currentElements) {
            const found = CssSelectorParser.selectElementsByCssPart(currentHtml, part);
            for (const element of found) {
              nextElements.push(element);
            }
          }
          currentElements = nextElements;
        }

        return currentElements;
      }

      // 处理子选择器（> 分隔）
      if (cssSelector.includes('>')) {
        const parts = cssSelector.split(/>/).map((p: string) => p.trim()).filter((p: string) => p.length > 0);
        let currentElements = [html];

        for (const part of parts) {
          const nextElements: string[] = [];
          for (const currentHtml of currentElements) {
            // 提取直接子元素
            const found = CssSelectorParser.selectElementsByCssPart(currentHtml, part);
            for (const element of found) {
              // 验证是否为直接子元素
              if (CssSelectorParser.isDirectChild(currentHtml, element)) {
                nextElements.push(element);
              }
            }
          }
          currentElements = nextElements;
        }

        return currentElements;
      }

      // 简单选择器
      return CssSelectorParser.selectElementsByCssPart(html, cssSelector);
    } catch (error) {
      Logger.error(CssSelectorParser.TAG, `CSS选择器解析失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    return elements;
  }

  /**
   * 检查元素是否为直接子元素
   */
  private static isDirectChild(parentHtml: string, childHtml: string): boolean {
    // 提取子元素的标签名
    const childMatch = childHtml.match(/^<([a-zA-Z][a-zA-Z0-9]*)/);
    if (!childMatch) {
      return false;
    }

    const childTagName = childMatch[1];

    // 在父元素中查找该子元素的直接位置
    const tagPattern = new RegExp(`<${CssSelectorParser.escapeRegex(childTagName)}[^>]*>`, 'i');
    const parentTagMatch = parentHtml.match(/^<([a-zA-Z][a-zA-Z0-9]*)/);

    if (!parentTagMatch) {
      return false;
    }

    // 简单检查：如果子元素HTML存在于父元素中，且没有被其他相同标签包裹
    return parentHtml.includes(childHtml);
  }

  /**
   * 解析单个CSS选择器部分
   */
  private static selectElementsByCssPart(html: string, cssPart: string): string[] {
    const elements: string[] = [];

    try {
      // 处理 :nth-of-type(N)
      const nthMatch = cssPart.match(/:nth-of-type\((\d+)\)$/);
      let index = -1;
      let selector = cssPart;

      if (nthMatch) {
        index = parseInt(nthMatch[1], 10) - 1; // 转换为0基索引
        selector = cssPart.replace(/:nth-of-type\(\d+\)$/, '');
      }

      // 处理 :last-of-type
      const lastMatch = cssPart.match(/:last-of-type$/);
      let isLast = false;
      if (lastMatch) {
        isLast = true;
        selector = cssPart.replace(/:last-of-type$/, '');
      }

      // 处理 :nth-last-of-type(N)
      const nthLastMatch = cssPart.match(/:nth-last-of-type\((\d+)\)$/);
      let nthLastIndex = -1;
      if (nthLastMatch) {
        nthLastIndex = parseInt(nthLastMatch[1], 10);
        selector = cssPart.replace(/:nth-last-of-type\(\d+\)$/, '');
      }

      // 处理 :not() 伪类
      const notMatch = selector.match(/:not\(([^)]+)\)$/);
      let notSelector = '';
      if (notMatch) {
        notSelector = notMatch[1];
        selector = selector.replace(/:not\([^)]+\)$/, '');
      }

      // 构建正则表达式
      let pattern = '';
      let tagName = '';
      let classNames: string[] = [];
      let id = '';
      interface AttributeInfo {
        name: string;
        value?: string;
        operator?: string;
      }
      let attributes: AttributeInfo[] = [];

      // 解析标签名
      const tagMatch = selector.match(/^([a-zA-Z*][a-zA-Z0-9]*)/);
      if (tagMatch) {
        tagName = tagMatch[1] === '*' ? '' : tagMatch[1];
        selector = selector.substring(tagMatch[0].length);
      }

      // 解析ID
      const idMatches = selector.match(/#([a-zA-Z0-9_-]+)/g);
      if (idMatches && idMatches.length > 0) {
        id = idMatches[0].substring(1);
        selector = selector.replace(/#[a-zA-Z0-9_-]+/, '');
      }

      // 解析class
      const classMatches = selector.match(/\.[a-zA-Z0-9_-]+/g);
      if (classMatches) {
        for (const cm of classMatches) {
          classNames.push(cm.substring(1));
        }
        selector = selector.replace(/\.[a-zA-Z0-9_-]+/g, '');
      }

      // 解析属性选择器
      const attrMatches = selector.match(/\[[^\]]+\]/g);
      if (attrMatches) {
        for (const am of attrMatches) {
          const attrContent = am.substring(1, am.length - 1);
          // 处理 [attr*="value"]
          const containsMatch = attrContent.match(/^([a-zA-Z_-]+)\*=["']([^"']+)["']$/);
          if (containsMatch) {
            const attrInfo: AttributeInfo = ({ name: containsMatch[1], value: containsMatch[2], operator: '*=' } as AttributeInfo);
            attributes.push(attrInfo);
            continue;
          }
          // 处理 [attr^="value"]
          const startsWithMatch = attrContent.match(/^([a-zA-Z_-]+)\^=["']([^"']+)["']$/);
          if (startsWithMatch) {
            const attrInfo: AttributeInfo = ({ name: startsWithMatch[1], value: startsWithMatch[2], operator: '^=' } as AttributeInfo);
            attributes.push(attrInfo);
            continue;
          }
          // 处理 [attr$="value"]
          const endsWithMatch = attrContent.match(/^([a-zA-Z_-]+)\$=["']([^"']+)["']$/);
          if (endsWithMatch) {
            const attrInfo: AttributeInfo = ({ name: endsWithMatch[1], value: endsWithMatch[2], operator: '$=' } as AttributeInfo);
            attributes.push(attrInfo);
            continue;
          }
          // 处理 [attr="value"]
          const equalsMatch = attrContent.match(/^([a-zA-Z_-]+)=["']([^"']+)["']$/);
          if (equalsMatch) {
            const attrInfo: AttributeInfo = ({ name: equalsMatch[1], value: equalsMatch[2], operator: '=' } as AttributeInfo);
            attributes.push(attrInfo);
            continue;
          }
          // 处理 [attr]（属性存在）
          const existsMatch = attrContent.match(/^([a-zA-Z_-]+)$/);
          if (existsMatch) {
            const attrInfo: AttributeInfo = ({ name: existsMatch[1], operator: 'exists' } as AttributeInfo);
            attributes.push(attrInfo);
          }
        }
      }

      // 构建正则表达式
      pattern = '<';
      if (tagName) {
        pattern += CssSelectorParser.escapeRegex(tagName);
      } else {
        pattern += '([a-zA-Z][a-zA-Z0-9]*)';
      }
      pattern += '[^>]*';

      // 添加ID匹配
      if (id) {
        pattern += `id=["']${CssSelectorParser.escapeRegex(id)}["'][^>]*`;
      }

      // 添加class匹配
      if (classNames.length > 0) {
        pattern += 'class=["\'][^"\']*';
        for (const cn of classNames) {
          pattern += `(?=.*\\b${CssSelectorParser.escapeRegex(cn)}\\b)`;
        }
        pattern += '[^"\']*["\'][^>]*';
      }

      // 添加属性匹配
      for (const attr of attributes) {
        if (attr.operator === 'exists') {
          pattern += `${CssSelectorParser.escapeRegex(attr.name)}[^>]*`;
        } else if (attr.operator === '*=' && attr.value) {
          pattern += `${CssSelectorParser.escapeRegex(attr.name)}=["'][^"']*${CssSelectorParser.escapeRegex(attr.value)}[^"']*["'][^>]*`;
        } else if (attr.operator === '^=' && attr.value) {
          pattern += `${CssSelectorParser.escapeRegex(attr.name)}=["']${CssSelectorParser.escapeRegex(attr.value)}[^"']*["'][^>]*`;
        } else if (attr.operator === '$=' && attr.value) {
          pattern += `${CssSelectorParser.escapeRegex(attr.name)}=["'][^"']*${CssSelectorParser.escapeRegex(attr.value)}["'][^>]*`;
        } else if (attr.operator === '=' && attr.value) {
          pattern += `${CssSelectorParser.escapeRegex(attr.name)}=["']${CssSelectorParser.escapeRegex(attr.value)}["'][^>]*`;
        }
      }

      pattern += '>([\\s\\S]*?)<\\/';
      if (tagName) {
        pattern += CssSelectorParser.escapeRegex(tagName);
      } else {
        pattern += '\\1';
      }
      pattern += '>';

      Logger.debug(CssSelectorParser.TAG, `CSS部分解析 - tagName: ${tagName || '*'}, id: ${id || '无'}, classes: [${classNames.join(', ')}], index: ${index}`);

      const regex = new RegExp(pattern, 'gi');
      const matches = html.matchAll(regex);
      for (const match of matches) {
        elements.push(match[0]);
      }

      // 处理 :not() 排除
      if (notSelector && elements.length > 0) {
        const filtered: string[] = [];
        for (const el of elements) {
          if (!CssSelectorParser.elementMatchesSelector(el, notSelector)) {
            filtered.push(el);
          }
        }
        return CssSelectorParser.applyIndexFilter(filtered, index, isLast, nthLastIndex);
      }

      return CssSelectorParser.applyIndexFilter(elements, index, isLast, nthLastIndex);
    } catch (error) {
      Logger.error(CssSelectorParser.TAG, `CSS部分解析失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    return elements;
  }

  /**
   * 检查元素是否匹配选择器
   */
  private static elementMatchesSelector(elementHtml: string, selector: string): boolean {
    // 简单实现：检查class、id、标签名
    const tagMatch = selector.match(/^([a-zA-Z][a-zA-Z0-9]*)/);
    const classMatch = selector.match(/\.([a-zA-Z0-9_-]+)/);
    const idMatch = selector.match(/#([a-zA-Z0-9_-]+)/);

    if (tagMatch) {
      const tagPattern = new RegExp(`^<${tagMatch[1]}[^>]*>`, 'i');
      if (!tagPattern.test(elementHtml)) {
        return false;
      }
    }

    if (classMatch) {
      const classPattern = new RegExp(`class=["'][^"']*\\b${classMatch[1]}\\b`, 'i');
      if (!classPattern.test(elementHtml)) {
        return false;
      }
    }

    if (idMatch) {
      const idPattern = new RegExp(`id=["']${idMatch[1]}["']`, 'i');
      if (!idPattern.test(elementHtml)) {
        return false;
      }
    }

    return true;
  }

  /**
   * 应用索引过滤器
   */
  private static applyIndexFilter(elements: string[], index: number, isLast: boolean, nthLastIndex: number): string[] {
    if (isLast && elements.length > 0) {
      return [elements[elements.length - 1]];
    }

    if (nthLastIndex > 0 && elements.length >= nthLastIndex) {
      return [elements[elements.length - nthLastIndex]];
    }

    if (index >= 0 && index < elements.length) {
      return [elements[index]];
    }

    return elements;
  }

  /**
   * 原生XPath解析（回退方案）
   */
  private static selectByXPathNative(html: string, xpath: string): string[] {
    const elements: string[] = [];

    try {
      Logger.debug(CssSelectorParser.TAG, `selectByXPathNative - 原始xpath: ${xpath}`);

      let processedXpath = xpath;
      let skipFirst = 0;

      if (processedXpath.startsWith('//')) {
        processedXpath = processedXpath.substring(2);
      } else if (processedXpath.startsWith('./')) {
        processedXpath = processedXpath.substring(2);
      }

      Logger.debug(CssSelectorParser.TAG, `selectByXPathNative - 处理后xpath: ${processedXpath}`);

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
            for (const element of found) {
              nextElements.push(element);
            }
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
      Logger.error(CssSelectorParser.TAG, `XPath原生解析失败: ${error instanceof Error ? error.message : String(error)}`);
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
    return EntityDecoder.cleanHtml(html);
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
