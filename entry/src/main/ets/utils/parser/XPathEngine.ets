import { Logger } from "../performance/Logger";
import { EntityDecoder } from "../../core/utils/EntityDecoder";

export interface XPathNode {
  type: 'element' | 'text' | 'attribute';
  tagName?: string;
  attributes?: Map<string, string>;
  children?: XPathNode[];
  textContent?: string;
  parent?: XPathNode;
  html?: string;
  startIndex: number;
  endIndex: number;
}

export interface XPathResult {
  nodes: XPathNode[];
  values: string[];
}

type XPathAxis = 
  | 'child' 
  | 'parent' 
  | 'ancestor' 
  | 'ancestor-or-self'
  | 'descendant' 
  | 'descendant-or-self'
  | 'following-sibling' 
  | 'preceding-sibling'
  | 'following'
  | 'preceding'
  | 'self';

interface XPathStep {
  axis: XPathAxis;
  nodeTest: string;
  predicates: Predicate[];
}

interface Predicate {
  type: 'position' | 'attribute' | 'text' | 'function' | 'compound';
  value?: string | number;
  operator?: string;
  operand?: string | number;
  functionName?: string;
  args?: (string | number | Predicate)[];
}

interface CacheEntry {
  result: XPathResult;
  timestamp: number;
}

export class XPathEngine {
  private static readonly TAG = 'XPathEngine';
  private static instance: XPathEngine | null = null;
  
  private readonly regexCache: Map<string, RegExp> = new Map();
  private readonly resultCache: Map<string, CacheEntry> = new Map();
  private static readonly MAX_CACHE_SIZE = 100;
  private static readonly CACHE_TTL = 5 * 60 * 1000;
  private static readonly SAMPLE_INTERVAL = 500;

  private constructor() {}

  static getInstance(): XPathEngine {
    if (!XPathEngine.instance) {
      XPathEngine.instance = new XPathEngine();
    }
    return XPathEngine.instance;
  }

  clearCache(): void {
    this.resultCache.clear();
    this.regexCache.clear();
  }

  private generateCacheKey(html: string, xpath: string): string {
    const htmlHash = this.sampleHash(html);
    const xpathHash = this.simpleHash(xpath);
    return `${htmlHash}_${xpathHash}`;
  }

  private sampleHash(content: string): string {
    if (content.length <= 1500) {
      return this.simpleHash(content);
    }
    
    let sample = '';
    const len = content.length;
    const step = XPathEngine.SAMPLE_INTERVAL;
    
    for (let i = 0; i < len; i += step) {
      const end = Math.min(i + 50, len);
      sample += content.substring(i, end);
    }
    
    return this.simpleHash(sample) + '_' + len;
  }

  private simpleHash(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return hash.toString(16);
  }

  private pruneCache(): void {
    if (this.resultCache.size <= XPathEngine.MAX_CACHE_SIZE) {
      return;
    }
    
    const now = Date.now();
    const entries = Array.from(this.resultCache.entries());
    
    entries.sort((a, b) => a[1].timestamp - b[1].timestamp);
    
    const toRemove = entries.slice(0, Math.floor(entries.length / 2));
    for (let i = 0; i < toRemove.length; i++) {
      this.resultCache.delete(toRemove[i][0]);
    }
  }

  evaluate(html: string, xpath: string): XPathResult {
    const emptyResult: XPathResult = { nodes: [], values: [] };
    
    if (!html || !xpath) {
      return emptyResult;
    }

    const cacheKey = this.generateCacheKey(html, xpath);
    const cached = this.resultCache.get(cacheKey);
    if (cached) {
      if (Date.now() - cached.timestamp < XPathEngine.CACHE_TTL) {
        return cached.result;
      }
      this.resultCache.delete(cacheKey);
    }

    try {
      const steps = this.parseXPath(xpath);
      if (steps.length === 0) {
        return emptyResult;
      }

      let currentNodes: XPathNode[] = this.parseHtmlToNodes(html);
      
      for (const step of steps) {
        currentNodes = this.evaluateStep(currentNodes, step, html);
        if (currentNodes.length === 0) {
          break;
        }
      }

      const values: string[] = [];
      for (const node of currentNodes) {
        values.push(this.nodeToString(node));
      }

      const result: XPathResult = { nodes: currentNodes, values };
      
      this.pruneCache();
      this.resultCache.set(cacheKey, { result, timestamp: Date.now() });

      return result;
    } catch (error) {
      Logger.error(XPathEngine.TAG, `XPath evaluation failed: ${xpath}, error: ${error}`);
      return emptyResult;
    }
  }

  selectElements(html: string, xpath: string): string[] {
    const result = this.evaluate(html, xpath);
    return result.values;
  }

  selectFirst(html: string, xpath: string): string {
    const result = this.evaluate(html, xpath);
    return result.values.length > 0 ? result.values[0] : '';
  }

  extractAttribute(html: string, xpath: string, attrName: string): string {
    const attrXpath = xpath.endsWith('/') ? xpath + '@' + attrName : xpath + '/@' + attrName;
    const result = this.evaluate(html, attrXpath);
    return result.values.length > 0 ? result.values[0] : '';
  }

  private parseXPath(xpath: string): XPathStep[] {
    const steps: XPathStep[] = [];
    let processed = xpath.trim();

    if (processed.startsWith('//')) {
      steps.push({
        axis: 'descendant-or-self',
        nodeTest: '*',
        predicates: []
      });
      processed = processed.substring(2);
    } else if (processed.startsWith('/')) {
      processed = processed.substring(1);
    }

    const parts = this.splitXPathPath(processed);
    
    for (const part of parts) {
      const step = this.parseStep(part);
      if (step) {
        steps.push(step);
      }
    }

    return steps;
  }

  private splitXPathPath(xpath: string): string[] {
    const parts: string[] = [];
    let current = '';
    let depth = 0;
    let inString = false;
    let stringChar = '';

    for (let i = 0; i < xpath.length; i++) {
      const char = xpath[i];

      if (!inString && (char === '"' || char === "'")) {
        inString = true;
        stringChar = char;
        current += char;
      } else if (inString && char === stringChar) {
        inString = false;
        current += char;
      } else if (!inString && char === '[') {
        depth++;
        current += char;
      } else if (!inString && char === ']') {
        depth--;
        current += char;
      } else if (!inString && char === '/' && depth === 0) {
        if (current.trim()) {
          parts.push(current.trim());
        }
        current = '';
      } else {
        current += char;
      }
    }

    if (current.trim()) {
      parts.push(current.trim());
    }

    return parts;
  }

  private parseStep(part: string): XPathStep | null {
    if (!part) return null;

    let axis: XPathAxis = 'child';
    let nodeTest = part;
    let predicates: Predicate[] = [];

    if (part.startsWith('@')) {
      return {
        axis: 'self',
        nodeTest: part,
        predicates: []
      };
    }

    const axisMatch = part.match(/^(child|parent|ancestor|ancestor-or-self|descendant|descendant-or-self|following-sibling|preceding-sibling|following|preceding|self)::(.+)$/i);
    if (axisMatch) {
      axis = axisMatch[1].toLowerCase() as XPathAxis;
      nodeTest = axisMatch[2];
    }

    const predicateMatches = nodeTest.match(/\[([^\]]+)\]/g);
    if (predicateMatches) {
      for (const match of predicateMatches) {
        const predContent = match.slice(1, -1);
        const predicate = this.parsePredicate(predContent);
        if (predicate) {
          predicates.push(predicate);
        }
      }
      nodeTest = nodeTest.replace(/\[[^\]]+\]/g, '');
    }

    return { axis, nodeTest: nodeTest.trim(), predicates };
  }

  private parsePredicate(content: string): Predicate | null {
    const trimmed = content.trim();

    const positionMatch = trimmed.match(/^(\d+)$/);
    if (positionMatch) {
      return { type: 'position', value: parseInt(positionMatch[1]) };
    }

    const lastMatch = trimmed.match(/^last\(\)$/i);
    if (lastMatch) {
      return { type: 'position', value: 'last' };
    }

    const positionFuncMatch = trimmed.match(/^position\(\)\s*([<>=!]+)\s*(\d+)$/);
    if (positionFuncMatch) {
      return { 
        type: 'position', 
        value: trimmed,
        operator: positionFuncMatch[1],
        operand: parseInt(positionFuncMatch[2])
      };
    }

    const attrMatch = trimmed.match(/^@([a-zA-Z0-9_-]+)\s*=\s*["']([^"']*)["']$/);
    if (attrMatch) {
      return { 
        type: 'attribute', 
        value: attrMatch[1],
        operator: '=',
        operand: attrMatch[2]
      };
    }

    const containsMatch = trimmed.match(/^contains\s*\(\s*(?:@([a-zA-Z0-9_-]+)|text\(\))\s*,\s*["']([^"']*)["']\s*\)$/i);
    if (containsMatch) {
      return {
        type: 'function',
        functionName: 'contains',
        args: containsMatch[1] ? ['@' + containsMatch[1], containsMatch[2]] : ['text()', containsMatch[2]]
      };
    }

    const startsWithMatch = trimmed.match(/^starts-with\s*\(\s*(?:@([a-zA-Z0-9_-]+)|text\(\))\s*,\s*["']([^"']*)["']\s*\)$/i);
    if (startsWithMatch) {
      return {
        type: 'function',
        functionName: 'starts-with',
        args: startsWithMatch[1] ? ['@' + startsWithMatch[1], startsWithMatch[2]] : ['text()', startsWithMatch[2]]
      };
    }

    const textMatch = trimmed.match(/^text\(\)$/i);
    if (textMatch) {
      return { type: 'text' };
    }

    const attrExistsMatch = trimmed.match(/^@([a-zA-Z0-9_-]+)$/);
    if (attrExistsMatch) {
      return { type: 'attribute', value: attrExistsMatch[1] };
    }

    return { type: 'compound', value: trimmed };
  }

  private evaluateStep(nodes: XPathNode[], step: XPathStep, originalHtml: string): XPathNode[] {
    let result: XPathNode[] = [];

    for (const node of nodes) {
      const expanded = this.expandByAxis(node, step.axis, originalHtml);
      const filtered = this.filterByNodeTest(expanded, step.nodeTest);
      const withPredicates = this.filterByPredicates(filtered, step.predicates);
      result.push(...withPredicates);
    }

    return result;
  }

  private expandByAxis(node: XPathNode, axis: XPathAxis, originalHtml: string): XPathNode[] {
    switch (axis) {
      case 'self':
        return [node];
      
      case 'child':
        return node.children || [];
      
      case 'parent':
        return node.parent ? [node.parent] : [];
      
      case 'descendant':
        return this.getDescendants(node, false);
      
      case 'descendant-or-self':
        return this.getDescendants(node, true);
      
      case 'ancestor':
        return this.getAncestors(node, false);
      
      case 'ancestor-or-self':
        return this.getAncestors(node, true);
      
      case 'following-sibling':
        return this.getSiblings(node, false, true);
      
      case 'preceding-sibling':
        return this.getSiblings(node, false, false);
      
      case 'following':
        return this.getFollowing(node);
      
      case 'preceding':
        return this.getPreceding(node);
      
      default:
        return [];
    }
  }

  private getDescendants(node: XPathNode, includeSelf: boolean): XPathNode[] {
    const result: XPathNode[] = [];
    
    if (includeSelf) {
      result.push(node);
    }

    const stack = [...(node.children || [])];
    while (stack.length > 0) {
      const current = stack.pop()!;
      result.push(current);
      if (current.children) {
        stack.push(...current.children);
      }
    }

    return result;
  }

  private getAncestors(node: XPathNode, includeSelf: boolean): XPathNode[] {
    const result: XPathNode[] = [];
    
    if (includeSelf) {
      result.push(node);
    }

    let current = node.parent;
    while (current) {
      result.push(current);
      current = current.parent;
    }

    return result;
  }

  private getSiblings(node: XPathNode, includeSelf: boolean, following: boolean): XPathNode[] {
    if (!node.parent || !node.parent.children) {
      return includeSelf ? [node] : [];
    }

    const siblings = node.parent.children;
    const nodeIndex = siblings.indexOf(node);
    
    if (nodeIndex === -1) {
      return includeSelf ? [node] : [];
    }

    if (following) {
      return siblings.slice(nodeIndex + (includeSelf ? 0 : 1));
    } else {
      return siblings.slice(0, nodeIndex + (includeSelf ? 1 : 0));
    }
  }

  private getFollowing(node: XPathNode): XPathNode[] {
    const result: XPathNode[] = [];
    
    const followingSiblings = this.getSiblings(node, false, true);
    for (const sibling of followingSiblings) {
      result.push(...this.getDescendants(sibling, true));
    }

    let current = node.parent;
    while (current) {
      const parentSiblings = this.getSiblings(current, false, true);
      for (const sibling of parentSiblings) {
        result.push(...this.getDescendants(sibling, true));
      }
      current = current.parent;
    }

    return result;
  }

  private getPreceding(node: XPathNode): XPathNode[] {
    const result: XPathNode[] = [];
    
    const precedingSiblings = this.getSiblings(node, false, false);
    for (const sibling of precedingSiblings) {
      result.push(...this.getDescendants(sibling, true));
    }

    let current = node.parent;
    while (current) {
      const parentSiblings = this.getSiblings(current, false, false);
      for (const sibling of parentSiblings) {
        result.push(...this.getDescendants(sibling, true));
      }
      current = current.parent;
    }

    return result.reverse();
  }

  private filterByNodeTest(nodes: XPathNode[], nodeTest: string): XPathNode[] {
    if (nodeTest === '*' || nodeTest === 'node()') {
      return nodes.filter(n => n.type === 'element');
    }

    if (nodeTest === 'text()') {
      return nodes.filter(n => n.type === 'text');
    }

    if (nodeTest.startsWith('@')) {
      const attrName = nodeTest.substring(1);
      return nodes.filter(n => {
        if (n.type !== 'element' || !n.attributes) return false;
        return n.attributes.has(attrName);
      });
    }

    return nodes.filter(n => 
      n.type === 'element' && n.tagName?.toLowerCase() === nodeTest.toLowerCase()
    );
  }

  private filterByPredicates(nodes: XPathNode[], predicates: Predicate[]): XPathNode[] {
    if (predicates.length === 0) {
      return nodes;
    }

    let result = nodes;
    
    for (const predicate of predicates) {
      result = this.applyPredicate(result, predicate);
    }

    return result;
  }

  private applyPredicate(nodes: XPathNode[], predicate: Predicate): XPathNode[] {
    switch (predicate.type) {
      case 'position':
        return this.applyPositionPredicate(nodes, predicate);
      
      case 'attribute':
        return this.applyAttributePredicate(nodes, predicate);
      
      case 'text':
        return nodes.filter(n => n.type === 'text' || (n.textContent && n.textContent.trim().length > 0));
      
      case 'function':
        return this.applyFunctionPredicate(nodes, predicate);
      
      case 'compound':
        return this.applyCompoundPredicate(nodes, predicate);
      
      default:
        return nodes;
    }
  }

  private applyPositionPredicate(nodes: XPathNode[], predicate: Predicate): XPathNode[] {
    if (typeof predicate.value === 'number') {
      const index = predicate.value - 1;
      return index >= 0 && index < nodes.length ? [nodes[index]] : [];
    }

    if (predicate.value === 'last') {
      return nodes.length > 0 ? [nodes[nodes.length - 1]] : [];
    }

    if (predicate.operator && typeof predicate.operand === 'number') {
      return nodes.filter((_, index) => {
        const pos = index + 1;
        switch (predicate.operator) {
          case '>': return pos > predicate.operand!;
          case '<': return pos < predicate.operand!;
          case '>=': return pos >= predicate.operand!;
          case '<=': return pos <= predicate.operand!;
          case '=': return pos === predicate.operand!;
          case '!=': return pos !== predicate.operand!;
          default: return true;
        }
      });
    }

    return nodes;
  }

  private applyAttributePredicate(nodes: XPathNode[], predicate: Predicate): XPathNode[] {
    const attrName = predicate.value as string;
    
    if (!predicate.operator) {
      return nodes.filter(n => {
        if (n.type !== 'element' || !n.attributes) return false;
        return n.attributes.has(attrName);
      });
    }

    const attrValue = predicate.operand as string;
    return nodes.filter(n => {
      if (n.type !== 'element' || !n.attributes) return false;
      const actualValue = n.attributes.get(attrName);
      if (actualValue === undefined) return false;
      return actualValue === attrValue;
    });
  }

  private applyFunctionPredicate(nodes: XPathNode[], predicate: Predicate): XPathNode[] {
    const funcName = predicate.functionName?.toLowerCase();
    const args = predicate.args || [];

    switch (funcName) {
      case 'contains':
        return this.applyContainsPredicate(nodes, args);
      
      case 'starts-with':
        return this.applyStartsWithPredicate(nodes, args);
      
      case 'normalize-space':
        return nodes.filter(n => {
          const text = this.getNodeText(n).trim();
          return text.length > 0;
        });
      
      default:
        return nodes;
    }
  }

  private applyContainsPredicate(nodes: XPathNode[], args: (string | number | Predicate)[]): XPathNode[] {
    if (args.length < 2) return nodes;

    const target = String(args[0]);
    const search = String(args[1]);

    return nodes.filter(n => {
      if (target.startsWith('@')) {
        const attrName = target.substring(1);
        const attrValue = n.attributes?.get(attrName) || '';
        return attrValue.includes(search);
      } else if (target === 'text()') {
        const text = this.getNodeText(n);
        return text.includes(search);
      }
      return false;
    });
  }

  private applyStartsWithPredicate(nodes: XPathNode[], args: (string | number | Predicate)[]): XPathNode[] {
    if (args.length < 2) return nodes;

    const target = String(args[0]);
    const search = String(args[1]);

    return nodes.filter(n => {
      if (target.startsWith('@')) {
        const attrName = target.substring(1);
        const attrValue = n.attributes?.get(attrName) || '';
        return attrValue.startsWith(search);
      } else if (target === 'text()') {
        const text = this.getNodeText(n);
        return text.startsWith(search);
      }
      return false;
    });
  }

  private applyCompoundPredicate(nodes: XPathNode[], predicate: Predicate): XPathNode[] {
    const expr = predicate.value as string;
    
    const andMatch = expr.match(/^(.+)\s+and\s+(.+)$/i);
    if (andMatch) {
      const leftPred = this.parsePredicate(andMatch[1]);
      const rightPred = this.parsePredicate(andMatch[2]);
      if (leftPred && rightPred) {
        return this.applyPredicate(this.applyPredicate(nodes, leftPred), rightPred);
      }
    }

    const orMatch = expr.match(/^(.+)\s+or\s+(.+)$/i);
    if (orMatch) {
      const leftPred = this.parsePredicate(orMatch[1]);
      const rightPred = this.parsePredicate(orMatch[2]);
      if (leftPred && rightPred) {
        const leftResult = this.applyPredicate([...nodes], leftPred);
        const rightResult = this.applyPredicate([...nodes], rightPred);
        const combined = new Set<XPathNode>([...leftResult, ...rightResult]);
        return Array.from(combined);
      }
    }

    return nodes;
  }

  private parseHtmlToNodes(html: string): XPathNode[] {
    const root: XPathNode = {
      type: 'element',
      tagName: 'root',
      attributes: new Map(),
      children: [],
      startIndex: 0,
      endIndex: html.length
    };

    this.parseHtmlRecursive(html, root);
    return [root];
  }

  private parseHtmlRecursive(html: string, parent: XPathNode): void {
    const tagPattern = /<([a-zA-Z][a-zA-Z0-9_-]*)([^>]*)>|<\/([a-zA-Z][a-zA-Z0-9_-]*)>|([^<]+)/g;
    const stack: XPathNode[] = [parent];
    let lastIndex = 0;
    let match: RegExpExecArray | null;

    while ((match = tagPattern.exec(html)) !== null) {
      const fullMatch = match[0];
      const openTag = match[1];
      const attributes = match[2];
      const closeTag = match[3];
      const textContent = match[4];
      const currentIndex = match.index;

      if (textContent !== undefined && textContent.trim()) {
        const textNode: XPathNode = {
          type: 'text',
          textContent: EntityDecoder.decode(textContent),
          parent: stack[stack.length - 1],
          startIndex: currentIndex,
          endIndex: currentIndex + fullMatch.length
        };
        if (stack[stack.length - 1].children) {
          stack[stack.length - 1].children!.push(textNode);
        }
      } else if (openTag !== undefined) {
        const attrMap = this.parseAttributes(attributes || '');
        const elementNode: XPathNode = {
          type: 'element',
          tagName: openTag.toLowerCase(),
          attributes: attrMap,
          children: [],
          parent: stack[stack.length - 1],
          html: fullMatch,
          startIndex: currentIndex,
          endIndex: currentIndex + fullMatch.length
        };
        
        if (stack[stack.length - 1].children) {
          stack[stack.length - 1].children!.push(elementNode);
        }

        const selfClosingTags = ['br', 'hr', 'img', 'input', 'meta', 'link', 'area', 'base', 'col', 'embed', 'param', 'source', 'track', 'wbr'];
        if (!selfClosingTags.includes(openTag.toLowerCase()) && !attributes?.endsWith('/')) {
          stack.push(elementNode);
        }
      } else if (closeTag !== undefined) {
        const tagName = closeTag.toLowerCase();
        let found = false;
        for (let i = stack.length - 1; i >= 1; i--) {
          if (stack[i].tagName === tagName) {
            stack[i].endIndex = currentIndex + fullMatch.length;
            stack.splice(i);
            found = true;
            break;
          }
        }
      }

      lastIndex = currentIndex + fullMatch.length;
    }

    while (stack.length > 1) {
      stack.pop();
    }
  }

  private parseAttributes(attrString: string): Map<string, string> {
    const attrs = new Map<string, string>();
    const attrPattern = /([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*["']([^"']*)["']/g;
    let match: RegExpExecArray | null;

    while ((match = attrPattern.exec(attrString)) !== null) {
      const name = match[1].toLowerCase();
      const value = EntityDecoder.decode(match[2]);
      attrs.set(name, value);
    }

    return attrs;
  }

  private getNodeText(node: XPathNode): string {
    if (node.type === 'text') {
      return node.textContent || '';
    }

    if (node.children) {
      const texts: string[] = [];
      for (const child of node.children) {
        texts.push(this.getNodeText(child));
      }
      return texts.join('');
    }

    return '';
  }

  private nodeToString(node: XPathNode): string {
    if (node.type === 'text') {
      return node.textContent || '';
    }

    if (node.type === 'attribute') {
      return node.textContent || '';
    }

    if (node.type === 'element') {
      return this.getNodeText(node).trim();
    }

    return '';
  }

  getNodeHtml(node: XPathNode, originalHtml: string): string {
    if (node.html) {
      return node.html;
    }
    
    if (node.startIndex !== undefined && node.endIndex !== undefined) {
      return originalHtml.substring(node.startIndex, node.endIndex);
    }

    return '';
  }

  getAttributeValue(node: XPathNode, attrName: string): string {
    if (node.type !== 'element' || !node.attributes) {
      return '';
    }
    return node.attributes.get(attrName.toLowerCase()) || '';
  }
}

export default XPathEngine.getInstance();
