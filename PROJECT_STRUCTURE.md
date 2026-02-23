# AstroRead 项目文件结构文档

> 生成日期: 2026-02-25
> 版本: 1.0.0

## 📁 目录结构概览

```
AstroRead/
├── 📂 AppScope/                    # 应用全局资源
├── 📂 docs/                        # 项目文档
├── 📂 entry/                       # 入口模块
│   └── src/main/ets/
│       ├── 📂 pages/               # 页面层
│       ├── 📂 components/          # 组件层
│       ├── 📂 viewModels/          # 视图模型层
│       ├── 📂 models/              # 数据模型层
│       ├── 📂 services/            # 服务层 (新)
│       ├── 📂 repositories/        # 数据仓库层 (新)
│       ├── 📂 core/                # 核心层
│       ├── 📂 common/              # 公共资源
│       └── 📂 tests/               # 测试层
├── 📂 hvigor/                      # 构建配置
├── 📂 oh_modules/                  # 依赖包
├── 📂 scripts/                     # 工具脚本 (新)
└── 📄 配置文件
```

---

## 📱 页面层 (pages/)

| 文件名 | 分类 | 用途 | 关联模块 |
|--------|------|------|----------|
| MainPage.ets | main | 主页面，底部导航 | 全局 |
| HomePage.ets | main | 首页 | 书籍推荐 |
| BookshelfPage.ets | book | 书架页 | 书籍管理 |
| BookDetailPage.ets | book | 书籍详情 | 书籍信息 |
| ReadPage.ets | book | 阅读页 | 阅读器 |
| SearchPage.ets | main | 搜索页 | 搜索引擎 |
| SourcePage.ets | source | 书源管理 | 书源服务 |
| SettingsPage.ets | settings | 设置页 | 配置管理 |
| ImportPage.ets | book | 导入页 | 文件导入 |
| LocalBookPage.ets | book | 本地书籍 | 本地存储 |
| ContentFilterPage.ets | settings | 内容过滤 | 过滤器 |
| DebugLogPage.ets | test | 调试日志 | 调试工具 |
| PerformanceMonitorPage.ets | test | 性能监控 | 性能工具 |
| HttpClientTestPage.ets | test | HTTP测试 | 网络服务 |
| ParserFacadeTestPage.ets | test | 解析器测试 | 解析服务 |

---

## 🧩 组件层 (components/)

### base/ - 基础组件
| 文件名 | 用途 |
|--------|------|
| AppButton.ets | 统一按钮组件 |
| AppCard.ets | 卡片容器组件 |
| AppInput.ets | 输入框组件 |
| AppNavigation.ets | 导航组件 |

### book/ - 书籍组件
| 文件名 | 用途 |
|--------|------|
| BookCard.ets | 书籍卡片 |
| BookCoverImage.ets | 书籍封面 |

### reader/ - 阅读器组件
| 文件名 | 用途 |
|--------|------|
| EpubReader.ets | EPUB阅读器 |
| WebReader.ets | 网页阅读器 |
| WebReaderUsageExample.ets | 使用示例 |

### common/ - 通用组件
| 文件名 | 用途 |
|--------|------|
| OptimizedList.ets | 优化列表 |
| ThemeToggle.ets | 主题切换 |
| BookSourceDebuggerComponent.ets | 书源调试 |

---

## 📊 视图模型层 (viewModels/)

| 文件名 | 用途 | 关联模型 |
|--------|------|----------|
| BookViewModel.ets | 书籍业务逻辑 | Book |
| BookSourceViewModel.ets | 书源业务逻辑 | BookSource |
| BookmarkViewModel.ets | 书签业务逻辑 | Bookmark |
| CategoryViewModel.ets | 分类业务逻辑 | BookCategory |
| ChapterViewModel.ets | 章节业务逻辑 | Chapter |
| ReadConfigViewModel.ets | 阅读配置逻辑 | ReadConfig |
| ViewModelManager.ets | VM管理器 | - |

---

## 📋 数据模型层 (models/)

| 文件名 | 用途 | 主要属性 |
|--------|------|----------|
| Book.ets | 书籍模型 | id, name, author, cover, chapters |
| BookSource.ets | 书源模型 | id, name, url, rules |
| SearchResult.ets | 搜索结果 | books, total, page |
| EnhancedSearchResult.ets | 增强搜索结果 | 扩展SearchResult |
| ReadConfig.ets | 阅读配置 | fontSize, theme, mode |
| Bookmark.ets | 书签模型 | bookId, chapterId, position |
| BookCategory.ets | 分类模型 | id, name, books |
| ContentFilter.ets | 内容过滤 | rules, patterns |
| LocalBook.ets | 本地书籍 | path, format, progress |

---

## 🔧 服务层 (services/)

### http/ - HTTP服务
| 文件名 | 用途 | 依赖 |
|--------|------|------|
| HttpClient.ets | HTTP客户端 | - |
| HttpClientConfig.ets | 客户端配置 | - |
| RequestBuilder.ets | 请求构建 | - |
| ResponseParser.ets | 响应解析 | - |
| RetryHandler.ets | 重试处理 | - |
| InterceptorManager.ets | 拦截器管理 | - |

### parser/ - 解析服务
| 文件名 | 用途 | 支持格式 |
|--------|------|----------|
| BookSourceParser.ets | 书源解析 | JSON/XML/TXT |
| ContentParser.ets | 内容解析 | HTML |
| HtmlParser.ets | HTML解析 | HTML |
| CssSelectorParser.ets | CSS选择器 | CSS |
| XPathParser.ets | XPath解析 | XPath |
| JsonPathParser.ets | JSONPath解析 | JSONPath |
| RegexParser.ets | 正则解析 | Regex |
| JsParser.ets | JS解析 | JavaScript |
| EpubParser.ets | EPUB解析 | EPUB |
| TxtParser.ets | TXT解析 | TXT |
| RuleEngine.ets | 规则引擎 | - |
| RuleAnalyzer.ets | 规则分析 | - |

### search/ - 搜索服务
| 文件名 | 用途 |
|--------|------|
| SearchEngine.ets | 搜索引擎基类 |
| BookSourceSearchEngine.ets | 书源搜索 |
| EnhancedBookSourceSearchEngine.ets | 增强搜索 |
| SearchCache.ets | 搜索缓存 |
| SearchEnhancer.ets | 搜索增强 |
| SearchQueryParser.ets | 查询解析 |
| SmartSourceSelector.ets | 智能选择器 |

### storage/ - 存储服务
| 文件名 | 用途 |
|--------|------|
| DatabaseManager.ets | 数据库管理 |
| FileManager.ets | 文件管理 |
| BackupManager.ets | 备份管理 |
| CacheManager.ets | 缓存管理 |

### security/ - 安全服务
| 文件名 | 用途 |
|--------|------|
| SecurityUtils.ets | 安全工具 |
| SqlSecurityUtils.ets | SQL安全 |
| SafeRegex.ets | 安全正则 |
| SafeExpressionEngine.ets | 安全表达式 |
| SourceSandbox.ets | 书源沙箱 |
| JsSecurityConfig.ets | JS安全配置 |

### crawler/ - 爬虫服务
| 文件名 | 用途 |
|--------|------|
| CrawlerManager.ets | 爬虫管理 |
| CrawlerMonitor.ets | 爬虫监控 |
| ImageScraperService.ets | 图片抓取 |
| RequestThrottler.ets | 请求节流 |
| RequestEnhancer.ets | 请求增强 |

---

## 🗄️ 数据仓库层 (repositories/)

### local/ - 本地仓库
| 文件名 | 用途 | 对应模型 |
|--------|------|----------|
| BookRepository.ets | 书籍数据 | Book |
| BookSourceRepository.ets | 书源数据 | BookSource |
| BookmarkRepository.ets | 书签数据 | Bookmark |
| ChapterRepository.ets | 章节数据 | Chapter |
| CategoryRepository.ets | 分类数据 | BookCategory |
| ReadConfigRepository.ets | 配置数据 | ReadConfig |

### remote/ - 远程仓库
| 文件名 | 用途 |
|--------|------|
| RemoteBookSourceRepository.ets | 远程书源 |

### interfaces/ - 仓库接口
| 文件名 | 用途 |
|--------|------|
| IBookRepository.ets | 书籍仓库接口 |
| IBookSourceRepository.ets | 书源仓库接口 |
| IBookmarkRepository.ets | 书签仓库接口 |

---

## 🔩 核心层 (core/)

### interfaces/ - 接口定义
| 文件名 | 用途 |
|--------|------|
| IParser.ets | 解析器接口 |
| IContentParser.ets | 内容解析器接口 |
| ISearchEngine.ets | 搜索引擎接口 |

### errors/ - 错误处理
| 文件名 | 用途 |
|--------|------|
| AppError.ets | 应用错误 |
| ParserError.ets | 解析错误 |
| HttpError.ets | HTTP错误 |

### utils/ - 核心工具
| 文件名 | 用途 |
|--------|------|
| Result.ets | 结果类型 |
| EntityDecoder.ets | 实体解码 |
| TextCleaner.ets | 文本清理 |
| PositionTracker.ets | 位置追踪 |

### di/ - 依赖注入
| 文件名 | 用途 |
|--------|------|
| ServiceContainer.ets | 服务容器 |

---

## 🌐 公共资源 (common/)

### constants/ - 常量
| 文件名 | 用途 |
|--------|------|
| AppConstants.ets | 应用常量 |

### styles/ - 样式
| 文件名 | 用途 |
|--------|------|
| ComponentStyles.ets | 组件样式 |
| ResponsiveUtils.ets | 响应式工具 |

### themes/ - 主题
| 文件名 | 用途 |
|--------|------|
| ThemeManager.ets | 主题管理 |
| DesignSystem.ets | 设计系统 |

### utils/ - 通用工具
| 文件名 | 用途 |
|--------|------|
| NavigationManager.ets | 导航管理 |
| ToastUtils.ets | Toast提示 |
| StringUtils.ets | 字符串工具 |
| HtmlUtils.ets | HTML工具 |
| IdGenerator.ets | ID生成器 |

---

## 🧪 测试层 (tests/)

### unit/ - 单元测试
| 文件名 | 测试目标 |
|--------|----------|
| ParserCore.test.ets | ParserCore |
| Result.test.ets | Result |
| ScriptEngine.test.ets | ScriptEngine |
| SafeRegex.test.ets | SafeRegex |
| SecurityUtils.test.ets | SecurityUtils |
| Semaphore.test.ets | Semaphore |

### integration/ - 集成测试
| 文件名 | 测试目标 |
|--------|----------|
| HttpClient.test.ets | HttpClient |
| NetworkConfig.test.ets | NetworkConfig |

### e2e/ - 端到端测试
| 文件名 | 测试目标 |
|--------|----------|
| BookSourceParser.test.ets | 书源解析流程 |

---

## 📚 项目文档 (docs/)

| 文件名 | 用途 |
|--------|------|
| README.md | 项目说明 |
| API-Reference.md | API参考 |
| API-Documentation-Standard.md | API文档规范 |
| HttpClient-API.md | HttpClient API |
| ParserFacade-API.md | ParserFacade API |
| CODE_STYLE.md | 代码风格指南 |
| GC_OPTIMIZATION.md | GC优化指南 |
| ISSUES_AND_FIXES.md | 问题与修复记录 |
| 技术实施方案.md | 技术方案 |
| 解析模块整合方案.md | 解析模块方案 |
| 搜索功能优化方案.md | 搜索优化方案 |
| 搜索功能优化测试报告.md | 测试报告 |
| CONVERSATION_RECORD_SECURITY_FIX_2026-02-24.md | 安全修复记录 |

---

## 🔧 工具脚本 (scripts/)

| 文件名 | 用途 |
|--------|------|
| copy_and_convert.py | 文件复制转换 |
| fix_imports.py | 导入修复 |
| fix_final_imports.py | 最终导入修复 |
| fix_remaining_imports.py | 剩余导入修复 |
| fix_imports_outside_utils.py | 外部导入修复 |

---

## ⚙️ 配置文件

### 项目级配置
| 文件名 | 用途 |
|--------|------|
| build-profile.json5 | 项目构建配置 |
| oh-package.json5 | 项目依赖配置 |
| oh-package-lock.json5 | 依赖锁定 |
| hvigorfile.ts | Hvigor构建脚本 |
| code-linter.json5 | 代码检查配置 |
| .eslintrc.js | ESLint配置 |
| .gitignore | Git忽略配置 |

### 模块级配置
| 文件路径 | 用途 |
|----------|------|
| entry/build-profile.json5 | 模块构建配置 |
| entry/oh-package.json5 | 模块依赖配置 |
| entry/hvigorfile.ts | 模块构建脚本 |
| entry/obfuscation-rules.txt | 混淆规则 |

### 应用配置
| 文件路径 | 用途 |
|----------|------|
| AppScope/app.json5 | 应用全局配置 |
| entry/src/main/module.json5 | 模块配置 |
| entry/src/main/syscap.json | 系统能力配置 |

---

## 📊 统计信息

| 类别 | 文件数量 |
|------|----------|
| 页面文件 | 16 |
| 组件文件 | 14 |
| 视图模型 | 7 |
| 数据模型 | 9 |
| 服务文件 | 50+ |
| 仓库文件 | 10+ |
| 核心文件 | 15+ |
| 公共资源 | 10+ |
| 测试文件 | 15+ |
| 文档文件 | 13 |
| 配置文件 | 15+ |
| **总计** | **170+** |

---

## 📝 命名规范

### 文件命名
- **PascalCase**: `BookSourceParser.ets`
- **接口前缀**: `IParser.ets`, `IBookSource`
- **测试后缀**: `*.test.ets`
- **索引文件**: `index.ets`

### 目录命名
- **camelCase**: `bookSource/`, `contentParser/`
- **复数形式**: `services/`, `repositories/`, `utils/`

### 类命名
- **PascalCase**: `class BookSourceParser`
- **接口**: `interface IParser`
- **枚举**: `enum SourceStatus`

---

## 🔄 迁移记录

### 已完成的迁移
1. ✅ Python脚本 → `scripts/`
2. ✅ 删除备份文件
3. ✅ 创建服务层索引
4. ✅ 创建仓库层索引
5. ✅ 创建公共资源索引

### 待完成的迁移
1. ⏳ utils/ → services/ (按功能分类)
2. ⏳ utils/database/ → repositories/local/
3. ⏳ network/ → services/http/
4. ⏳ 分散的测试文件 → tests/
5. ⏳ 更新所有导入路径

---

## 📌 注意事项

1. **不要修改**: `oh_modules/`、`build/`、`.hvigor/` 等自动生成的目录
2. **保持同步**: 修改文件路径后需更新相关导入语句
3. **备份重要**: 大规模迁移前建议创建Git提交点
4. **渐进迁移**: 建议按模块逐步迁移，避免一次性改动过大

---

*本文档由自动化工具生成，最后更新: 2026-02-25*
