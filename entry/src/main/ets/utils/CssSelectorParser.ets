/**
 * CSS选择器解析器
 * 支持阅读APP的CSS选择器语法
 */

/**
 * CSS选择器解析器类
 */
export class CssSelectorParser {
  /**
   * 选择元素（支持CSS选择器语法）
   */
  static selectElements(html: string, selector: string): string[] {
    const elements: string[] = [];
    
    try {
      // 处理选择器
      let processedSelector = selector.trim();
      
      // 移除@js:前缀
      if (processedSelector.startsWith('@js:') || processedSelector.startsWith('<js>')) {
        return elements; // JavaScript规则暂不支持
      }
      
      // 处理子选择器（如 .class@tag）
      if (processedSelector.includes('@')) {
        const parts = processedSelector.split('@');
        const parentSelector = parts[0].trim();
        const childSelector = parts[1].trim();
        
        // 先选择父元素
        const parentElements = CssSelectorParser.selectElements(html, parentSelector);
        for (const parentHtml of parentElements) {
          // 再从父元素中选择子元素
          const childElements = CssSelectorParser.selectElements(parentHtml, childSelector);
          elements.push(...childElements);
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
    } catch (error) {
      console.error('选择元素失败:', error);
    }
    
    return elements;
  }

  /**
   * 提取值（支持@属性、text等）
   */
  static extractValue(html: string, rule: string): string {
    try {
      let processedRule = rule.trim();
      
      // 处理##替换规则（如：##简介：）
      let replacePattern = '';
      if (processedRule.includes('##')) {
        const parts = processedRule.split('##');
        processedRule = parts[0];
        replacePattern = parts[1] || '';
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
        
        // 先选择元素
        let elements: string[];
        if (selector) {
          elements = CssSelectorParser.selectElements(html, selector);
        } else {
          elements = [html];
        }
        
        if (elements.length > 0) {
          const elementIndex = index >= 0 && index < elements.length ? index : 0;
          const elementHtml = elements[elementIndex];
          
          // 提取属性
          if (attr === 'text' || attr === 'text()') {
            let text = CssSelectorParser.extractTextContent(elementHtml);
            if (replacePattern) {
              text = text.replace(new RegExp(CssSelectorParser.escapeRegex(replacePattern), 'g'), '');
            }
            return text.trim();
          } else if (attr === 'href') {
            const hrefMatch = elementHtml.match(/href=["']([^"']*)["']/i);
            return hrefMatch ? hrefMatch[1] : '';
          } else if (attr === 'src') {
            const srcMatch = elementHtml.match(/src=["']([^"']*)["']/i);
            return srcMatch ? srcMatch[1] : '';
          } else {
            // 通用属性提取
            const attrRegex = new RegExp(`${CssSelectorParser.escapeRegex(attr)}=["']([^"']*)["']`, 'i');
            const attrMatch = elementHtml.match(attrRegex);
            return attrMatch ? attrMatch[1] : '';
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
      console.error('提取值失败:', error);
      return '';
    }
  }

  /**
   * 提取文本内容
   */
  static extractTextContent(html: string): string {
    return html
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * 转义正则表达式特殊字符
   */
  static escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
}
