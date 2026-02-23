/**
 * RuleAnalyzer 单元测试
 */

import { describe, it, expect } from '@ohos/hypium';
import { RuleAnalyzer } from '../RuleAnalyzer';

export default function ruleAnalyzerTest() {
  describe('RuleAnalyzer', () => {
    
    describe('splitRule', () => {
      it('should split rule with && operator', () => {
        const analyzer = new RuleAnalyzer('rule1&&rule2&&rule3');
        const rules = analyzer.splitRule('&&', '||', '%%');
        
        expect(rules.length).assertEqual(3);
        expect(rules[0]).assertEqual('rule1');
        expect(rules[1]).assertEqual('rule2');
        expect(rules[2]).assertEqual('rule3');
        expect(analyzer.elementsType).assertEqual('&&');
      });
      
      it('should split rule with || operator', () => {
        const analyzer = new RuleAnalyzer('rule1||rule2||rule3');
        const rules = analyzer.splitRule('&&', '||', '%%');
        
        expect(rules.length).assertEqual(3);
        expect(rules[0]).assertEqual('rule1');
        expect(rules[1]).assertEqual('rule2');
        expect(rules[2]).assertEqual('rule3');
        expect(analyzer.elementsType).assertEqual('||');
      });
      
      it('should split rule with %% operator', () => {
        const analyzer = new RuleAnalyzer('rule1%%rule2%%rule3');
        const rules = analyzer.splitRule('&&', '||', '%%');
        
        expect(rules.length).assertEqual(3);
        expect(rules[0]).assertEqual('rule1');
        expect(rules[1]).assertEqual('rule2');
        expect(rules[2]).assertEqual('rule3');
        expect(analyzer.elementsType).assertEqual('%%');
      });
      
      it('should handle mixed operators', () => {
        const analyzer = new RuleAnalyzer('rule1&&rule2||rule3');
        const rules = analyzer.splitRule('&&', '||', '%%');
        
        expect(rules.length).assertEqual(3);
        expect(rules[0]).assertEqual('rule1');
        expect(rules[1]).assertEqual('rule2');
        expect(rules[2]).assertEqual('rule3');
      });
      
      it('should handle rules with quotes', () => {
        const analyzer = new RuleAnalyzer('rule1&&"rule2&&inside"&&rule3');
        const rules = analyzer.splitRule('&&', '||', '%%');
        
        expect(rules.length).assertEqual(3);
        expect(rules[0]).assertEqual('rule1');
        expect(rules[1]).assertEqual('"rule2&&inside"');
        expect(rules[2]).assertEqual('rule3');
      });
      
      it('should handle empty rules', () => {
        const analyzer = new RuleAnalyzer('');
        const rules = analyzer.splitRule('&&', '||', '%%');
        
        expect(rules.length).assertEqual(0);
      });
      
      it('should handle single rule', () => {
        const analyzer = new RuleAnalyzer('singleRule');
        const rules = analyzer.splitRule('&&', '||', '%%');
        
        expect(rules.length).assertEqual(1);
        expect(rules[0]).assertEqual('singleRule');
      });
    });
    
    describe('chompRuleBalanced', () => {
      it('should match balanced braces', () => {
        const analyzer = new RuleAnalyzer('{inner}');
        analyzer.setPos(0);
        const result = analyzer.chompRuleBalanced('{', '}');
        
        expect(result).assertTrue();
        expect(analyzer.getPos()).assertEqual(7);
      });
      
      it('should match nested braces', () => {
        const analyzer = new RuleAnalyzer('{outer{inner}}');
        analyzer.setPos(0);
        const result = analyzer.chompRuleBalanced('{', '}');
        
        expect(result).assertTrue();
        expect(analyzer.getPos()).assertEqual(14);
      });
      
      it('should handle quotes inside braces', () => {
        const analyzer = new RuleAnalyzer('{"key": "value"}');
        analyzer.setPos(0);
        const result = analyzer.chompRuleBalanced('{', '}');
        
        expect(result).assertTrue();
        expect(analyzer.getPos()).assertEqual(16);
      });
      
      it('should handle escaped characters', () => {
        const analyzer = new RuleAnalyzer('{key: "val\\}ue"}');
        analyzer.setPos(0);
        const result = analyzer.chompRuleBalanced('{', '}');
        
        expect(result).assertTrue();
        expect(analyzer.getPos()).assertEqual(16);
      });
      
      it('should return false for unbalanced braces', () => {
        const analyzer = new RuleAnalyzer('{unclosed');
        analyzer.setPos(0);
        const result = analyzer.chompRuleBalanced('{', '}');
        
        expect(result).assertFalse();
      });
    });
    
    describe('chompCodeBalanced', () => {
      it('should match balanced brackets', () => {
        const analyzer = new RuleAnalyzer('[index]');
        analyzer.setPos(0);
        const result = analyzer.chompCodeBalanced('[', ']');
        
        expect(result).assertTrue();
        expect(analyzer.getPos()).assertEqual(7);
      });
      
      it('should match nested brackets', () => {
        const analyzer = new RuleAnalyzer('[[nested]]');
        analyzer.setPos(0);
        const result = analyzer.chompCodeBalanced('[', ']');
        
        expect(result).assertTrue();
        expect(analyzer.getPos()).assertEqual(10);
      });
      
      it('should handle mixed brackets', () => {
        const analyzer = new RuleAnalyzer('[{object}]');
        analyzer.setPos(0);
        const result = analyzer.chompCodeBalanced('[', ']');
        
        expect(result).assertTrue();
        expect(analyzer.getPos()).assertEqual(10);
      });
    });
    
    describe('innerRule', () => {
      it('should replace inner rules', () => {
        const analyzer = new RuleAnalyzer('{$.name} is {$.value}');
        const result = analyzer.innerRule('{$.', (rule) => {
          return `[${rule}]`;
        });
        
        expect(result).assertEqual('[name] is [value]');
      });
      
      it('should handle nested braces', () => {
        const analyzer = new RuleAnalyzer('{$.{nested}}');
        const result = analyzer.innerRule('{$.', (rule) => {
          return `[${rule}]`;
        });
        
        expect(result).assertEqual('[{nested}]');
      });
      
      it('should handle no matches', () => {
        const analyzer = new RuleAnalyzer('no inner rules');
        const result = analyzer.innerRule('{$.', (rule) => {
          return `[${rule}]`;
        });
        
        expect(result).assertEqual('no inner rules');
      });
    });
    
    describe('isInQuotes', () => {
      it('should detect single quotes', () => {
        const analyzer = new RuleAnalyzer("'test'");
        const result = (analyzer as any).isInQuotes(3);
        
        expect(result).assertTrue();
      });
      
      it('should detect double quotes', () => {
        const analyzer = new RuleAnalyzer('"test"');
        const result = (analyzer as any).isInQuotes(3);
        
        expect(result).assertTrue();
      });
      
      it('should handle escaped quotes', () => {
        const analyzer = new RuleAnalyzer('"test\\"escaped"');
        const result = (analyzer as any).isInQuotes(10);
        
        expect(result).assertTrue();
      });
    });
    
    describe('real world examples', () => {
      it('should handle book source search rule', () => {
        const rule = 'class.book-list@tag.li&&class.book-name@text()||class.book-title@text()';
        const analyzer = new RuleAnalyzer(rule);
        const rules = analyzer.splitRule('&&', '||', '%%');
        
        expect(rules.length).assertEqual(3);
        expect(rules[0]).assertEqual('class.book-list@tag.li');
        expect(rules[1]).assertEqual('class.book-name@text()');
        expect(rules[2]).assertEqual('class.book-title@text()');
      });
      
      it('should handle complex nested rule', () => {
        const rule = '{"name": "$.title", "author": "$.author"}##regex##replace';
        const analyzer = new RuleAnalyzer(rule);
        const rules = analyzer.splitRule('&&', '||', '%%');
        
        expect(rules.length).assertEqual(2);
      });
      
      it('should handle cross operator for chapters', () => {
        const rule = 'chapter1%%chapter2%%chapter3';
        const analyzer = new RuleAnalyzer(rule);
        const rules = analyzer.splitRule('&&', '||', '%%');
        
        expect(rules.length).assertEqual(3);
        expect(analyzer.elementsType).assertEqual('%%');
      });
    });
  });
}
