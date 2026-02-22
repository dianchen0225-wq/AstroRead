# 代码重构指南

本文档汇总了项目中存在的代码重复问题及优化方案。

## 已完成的优化

### 1. 公共工具类抽取 ✅

**新增文件：**
- `entry/src/main/ets/utils/HtmlUtils.ets` - HTML解析相关工具函数
- `entry/src/main/ets/utils/StringUtils.ets` - 字符串处理工具函数
- `entry/src/main/ets/utils/ParserCore.ets` - 解析核心模块（支持TaskPool）
- `entry/src/main/ets/utils/index.ets` - 工具类统一导出

**功能覆盖：**
- HTML实体解码
- HTML标签清理和文本提取
- URL解析和拼接
- 简单CSS选择器支持
- 字符串格式化、验证、转换
- 并发解析函数（用于@Concurrent任务）

**使用示例：**
```typescript
import { HtmlUtils, StringUtils, ParserCore } from '../utils';

// HTML处理
const text = HtmlUtils.extractText(html);
const decoded = HtmlUtils.decodeHtmlEntities(text);
const absoluteUrl = HtmlUtils.resolveUrl(baseUrl, relativeUrl);

// 字符串处理
const truncated = StringUtils.truncate(longText, 100);
const uuid = StringUtils.generateUUID();
const similarity = StringUtils.similarity(str1, str2);

// 解析核心
const chapters = ParserCore.parseChapterList(html, listRule, titleRule, urlRule, baseUrl);
const books = ParserCore.parseBookList(html, listRule, nameRule, authorRule);
```

## 待完成的优化

### 2. UI组件统一 🔄

**问题描述：**
- `UIComponents.ets` 与独立组件文件（`AppButton.ets`、`AppCard.ets`等）存在重复
- 两套实现略有差异，维护困难

**优化方案：**
1. 保留独立组件文件作为标准实现
2. 删除 `UIComponents.ets` 中的重复组件
3. 在 `index.ets` 中统一导出

**建议操作：**
```bash
# 1. 对比 UIComponents.ets 和独立组件的差异
# 2. 将差异合并到独立组件中
# 3. 删除 UIComponents.ets
# 4. 更新所有引用
```

### 3. 异步解析器优化 🔄

**问题描述：**
- `AsyncChapterParser`、`AsyncContentParser`、`AsyncCssSelectorParser` 内联了重复代码
- 与同步解析器（`CssSelectorParser`、`HTMLParser`）逻辑不一致

**优化方案：**
1. 使用 `ParserCore` 中的并发函数
2. 在 `@Concurrent` 任务中导入 `ParserCore` 模块

**迁移示例：**
```typescript
// 优化前 - 内联重复代码
@Concurrent
function parseChapterAsync(html: string, rules: Rules): Chapter[] {
  // 重复的解析逻辑...
}

// 优化后 - 使用公共模块
@Concurrent
function parseChapterAsync(html: string, rules: Rules): Chapter[] {
  // 导入并使用 ParserCore
  const { ParserCore } = require('../utils/ParserCore');
  return ParserCore.parseChapterList(html, rules.list, rules.title, rules.url, rules.baseUrl);
}
```

### 4. 书源管理统一 🔄

**问题描述：**
- `BookSourceManager` 和 `BookSourceViewModel` 职责重叠
- 两套管理途径可能导致状态不一致

**优化方案：**
1. 将 `BookSourceViewModel` 中的操作委托给 `BookSourceManager`
2. `BookSourceManager` 作为书源数据的唯一可信源
3. 统一数据流向：View -> ViewModel -> Manager -> Database

**架构调整：**
```
View (SearchPage)
  ↓
ViewModel (BookSourceViewModel) - 业务逻辑编排
  ↓
Manager (BookSourceManager) - 数据管理核心
  ↓
Database (DatabaseManager) - 持久化存储
```

### 5. 设计系统统一 🔄

**问题描述：**
- `DesignSystem` 定义了基础常量
- `ComponentStyles` 可能重复定义部分常量

**优化方案：**
1. 确保所有样式常量来自 `DesignSystem`
2. `ComponentStyles` 仅使用 `@Extend` 封装样式组合
3. 删除 `ComponentStyles` 中的硬编码值

### 6. 网络请求模块合并 🔄

**问题描述：**
- `NetworkAdapter` 和 `HttpClient` 功能重叠
- `HttpClient` 功能更全，但部分模块仍使用 `NetworkAdapter`

**优化方案：**
1. 逐步将 `NetworkAdapter` 的调用迁移到 `HttpClient`
2. 将 `NetworkAdapter` 标记为废弃（@deprecated）
3. 统一使用 `HttpClient` 的高级功能（拦截器、缓存等）

**迁移计划：**
```typescript
// 阶段1: 标记废弃
/**
 * @deprecated 请使用 HttpClient 替代
 */
export class NetworkAdapter { ... }

// 阶段2: 逐步迁移调用方
// 阶段3: 删除 NetworkAdapter
```

### 7. 规则引擎合并 🔄

**问题描述：**
- `AnalyzeRule` 和 `RuleEngine` 功能高度相似
- `EnhancedJSEngine` 专注于JS规则

**优化方案：**
1. 合并 `AnalyzeRule` 和 `RuleEngine` 为统一的 `RuleEngine`
2. 将 `EnhancedJSEngine` 作为JS规则的子模块
3. 统一规则解析入口

**新架构：**
```
RuleEngine
  ├── CssSelectorEngine
  ├── XPathEngine
  ├── JsonPathEngine
  ├── RegexEngine
  └── JsEngine (原 EnhancedJSEngine)
```

### 8. 文件清理 🔄

**问题描述：**
- 存在 `.txt` 和 `.ets` 重复文件
- 可能是打包或合并时的残留

**清理清单：**
- [ ] 删除所有 `.txt` 副本（保留 `.ets`）
- [ ] 检查 `MainPage.ets.txt` 等重复文件
- [ ] 验证删除后项目仍可正常编译

## 重构优先级

### 高优先级
1. ✅ 公共工具类抽取
2. ✅ 异步解析器优化
3. 🔄 UI组件统一
4. 🔄 书源管理统一

### 中优先级
5. 🔄 设计系统统一
6. 🔄 网络请求模块合并
7. 🔄 规则引擎合并

### 低优先级
8. 🔄 文件清理

## 重构原则

1. **向后兼容**：保持现有API不变，逐步迁移
2. **测试覆盖**：每次重构后运行测试套件
3. **小步快跑**：每次只重构一个模块
4. **代码审查**：重要重构需要代码审查
5. **文档更新**：同步更新相关文档

## 测试验证

重构后需要验证：
- [ ] 单元测试通过
- [ ] 集成测试通过
- [ ] UI测试通过
- [ ] 性能测试无退化
- [ ] 内存泄漏检查

## 参考文档

- [ArkTS语言规范](https://developer.harmonyos.com/)
- [HarmonyOS UI框架](https://developer.harmonyos.com/)
- [TypeScript最佳实践](https://www.typescriptlang.org/docs/)
