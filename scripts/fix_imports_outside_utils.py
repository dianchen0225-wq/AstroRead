import os
import re

# 定义修复规则 - 针对utils目录外的文件
fix_rules = [
    # 旧的utils导入路径改为新的子目录路径
    (r'from\s+["\']\.\./utils/Logger["\']', 'from "../utils/performance/Logger"'),
    (r'from\s+["\']\.\./utils/NetworkManager["\']', 'from "../utils/network/NetworkManager"'),
    (r'from\s+["\']\.\./utils/NetworkAdapter["\']', 'from "../utils/network/NetworkAdapter"'),
    (r'from\s+["\']\.\./utils/NetworkConfig["\']', 'from "../utils/network/NetworkConfig"'),
    (r'from\s+["\']\.\./utils/ContentParser["\']', 'from "../utils/parser/ContentParser"'),
    (r'from\s+["\']\.\./utils/HTMLParser["\']', 'from "../utils/parser/HTMLParser"'),
    (r'from\s+["\']\.\./utils/BookSourceParser["\']', 'from "../utils/parser/BookSourceParser"'),
    (r'from\s+["\']\.\./utils/FileParser["\']', 'from "../utils/parser/FileParser"'),
    (r'from\s+["\']\.\./utils/TXTParser["\']', 'from "../utils/parser/TXTParser"'),
    (r'from\s+["\']\.\./utils/EPUBParser["\']', 'from "../utils/parser/EPUBParser"'),
    (r'from\s+["\']\.\./utils/LocalFileParser["\']', 'from "../utils/parser/LocalFileParser"'),
    (r'from\s+["\']\.\./utils/SearchEngine["\']', 'from "../utils/search/SearchEngine"'),
    (r'from\s+["\']\.\./utils/BookSourceSearchEngine["\']', 'from "../utils/search/BookSourceSearchEngine"'),
    (r'from\s+["\']\.\./utils/EnhancedBookSourceSearchEngine["\']', 'from "../utils/search/EnhancedBookSourceSearchEngine"'),
    (r'from\s+["\']\.\./utils/SearchCache["\']', 'from "../utils/cache/SearchCache"'),
    (r'from\s+["\']\.\./utils/SecurityUtils["\']', 'from "../utils/security/SecurityUtils"'),
    (r'from\s+["\']\.\./utils/SafeRegex["\']', 'from "../utils/security/SafeRegex"'),
    (r'from\s+["\']\.\./utils/SourceValidator["\']', 'from "../utils/validation/SourceValidator"'),
    (r'from\s+["\']\.\./utils/SourceValidatorService["\']', 'from "../utils/validation/SourceValidatorService"'),
    (r'from\s+["\']\.\./utils/BookSourceValidationService["\']', 'from "../utils/validation/BookSourceValidationService"'),
    (r'from\s+["\']\.\./utils/DataValidator["\']', 'from "../utils/validation/DataValidator"'),
    (r'from\s+["\']\.\./utils/BookSourceManager["\']', 'from "../utils/validation/BookSourceManager"'),
    (r'from\s+["\']\.\./utils/SourceImportManager["\']', 'from "../utils/validation/SourceImportManager"'),
    (r'from\s+["\']\.\./utils/BookSourceDebugger["\']', 'from "../utils/validation/BookSourceDebugger"'),
    (r'from\s+["\']\.\./utils/FileManager["\']', 'from "../utils/file/FileManager"'),
    (r'from\s+["\']\.\./utils/BackupManager["\']', 'from "../utils/file/BackupManager"'),
    (r'from\s+["\']\.\./utils/DatabaseManager["\']', 'from "../utils/file/DatabaseManager"'),
    (r'from\s+["\']\.\./utils/PerformanceMonitor["\']', 'from "../utils/performance/PerformanceMonitor"'),
    (r'from\s+["\']\.\./utils/PerformanceUtils["\']', 'from "../utils/performance/PerformanceUtils"'),
    (r'from\s+["\']\.\./utils/BackgroundTaskManager["\']', 'from "../utils/performance/BackgroundTaskManager"'),
    (r'from\s+["\']\.\./utils/LogCollector["\']', 'from "../utils/performance/LogCollector"'),
    (r'from\s+["\']\.\./utils/ParseDebugLogger["\']', 'from "../utils/performance/ParseDebugLogger"'),
    (r'from\s+["\']\.\./utils/CrawlerManager["\']', 'from "../utils/crawler/CrawlerManager"'),
    (r'from\s+["\']\.\./utils/CrawlerMonitor["\']', 'from "../utils/crawler/CrawlerMonitor"'),
    (r'from\s+["\']\.\./utils/ImageScraperService["\']', 'from "../utils/crawler/ImageScraperService"'),
    (r'from\s+["\']\.\./utils/ImageScrapeManager["\']', 'from "../utils/crawler/ImageScrapeManager"'),
    (r'from\s+["\']\.\./utils/RequestThrottler["\']', 'from "../utils/crawler/RequestThrottler"'),
    (r'from\s+["\']\.\./utils/RequestEnhancer["\']', 'from "../utils/crawler/RequestEnhancer"'),
    (r'from\s+["\']\.\./utils/JSEngine["\']', 'from "../utils/scripting/JSEngine"'),
    (r'from\s+["\']\.\./utils/EnhancedJSEngine["\']', 'from "../utils/scripting/EnhancedJSEngine"'),
    (r'from\s+["\']\.\./utils/ScriptEngine["\']', 'from "../utils/scripting/ScriptEngine"'),
    (r'from\s+["\']\.\./utils/AstroReadJSRuntime["\']', 'from "../utils/scripting/AstroReadJSRuntime"'),
    (r'from\s+["\']\.\./utils/RegexCache["\']', 'from "../utils/cache/RegexCache"'),
    (r'from\s+["\']\.\./utils/ParseCache["\']', 'from "../utils/cache/ParseCache"'),
    (r'from\s+["\']\.\./utils/WeakRefCache["\']', 'from "../utils/cache/WeakRefCache"'),
    (r'from\s+["\']\.\./utils/ObjectPool["\']', 'from "../utils/cache/ObjectPool"'),
    (r'from\s+["\']\.\./utils/ContentPurifier["\']', 'from "../utils/content/ContentPurifier"'),
    (r'from\s+["\']\.\./utils/ContentFilter["\']', 'from "../utils/content/ContentFilter"'),
    (r'from\s+["\']\.\./utils/ContentProcessor["\']', 'from "../utils/content/ContentProcessor"'),
    (r'from\s+["\']\.\./utils/HtmlUtils["\']', 'from "../utils/content/HtmlUtils"'),
    (r'from\s+["\']\.\./utils/StringUtils["\']', 'from "../utils/content/StringUtils"'),
    (r'from\s+["\']\.\./utils/ToastUtils["\']', 'from "../utils/content/ToastUtils"'),
    (r'from\s+["\']\.\./utils/IdGenerator["\']', 'from "../utils/content/IdGenerator"'),
    (r'from\s+["\']\.\./utils/ErrorHandler["\']', 'from "../utils/error/ErrorHandler"'),
    (r'from\s+["\']\.\./utils/ErrorHandlingService["\']', 'from "../utils/error/ErrorHandlingService"'),
    (r'from\s+["\']\.\./utils/SourceSandbox["\']', 'from "../utils/security/SourceSandbox"'),
    (r'from\s+["\']\.\./utils/JSSecurityConfig["\']', 'from "../utils/security/JSSecurityConfig"'),
    (r'from\s+["\']\.\./utils/SqlSecurityUtils["\']', 'from "../utils/security/SqlSecurityUtils"'),
    (r'from\s+["\']\.\./utils/RuleEngine["\']', 'from "../utils/parser/RuleEngine"'),
    (r'from\s+["\']\.\./utils/RuleAnalyzer["\']', 'from "../utils/parser/RuleAnalyzer"'),
    (r'from\s+["\']\.\./utils/AnalyzeRule["\']', 'from "../utils/parser/AnalyzeRule"'),
    (r'from\s+["\']\.\./utils/XPathEngine["\']', 'from "../utils/parser/XPathEngine"'),
    (r'from\s+["\']\.\./utils/CssSelectorParser["\']', 'from "../utils/parser/CssSelectorParser"'),
    (r'from\s+["\']\.\./utils/SelectorCore["\']', 'from "../utils/parser/SelectorCore"'),
    (r'from\s+["\']\.\./utils/OptimizedSelectorEngine["\']', 'from "../utils/parser/OptimizedSelectorEngine"'),
    (r'from\s+["\']\.\./utils/ParserCore["\']', 'from "../utils/parser/ParserCore"'),
    (r'from\s+["\']\.\./utils/IParser["\']', 'from "../utils/parser/IParser"'),
    (r'from\s+["\']\.\./utils/AsyncCssSelectorParser["\']', 'from "../utils/parser/AsyncCssSelectorParser"'),
    (r'from\s+["\']\.\./utils/AsyncChapterParser["\']', 'from "../utils/parser/AsyncChapterParser"'),
    (r'from\s+["\']\.\./utils/AsyncContentParser["\']', 'from "../utils/parser/AsyncContentParser"'),
    (r'from\s+["\']\.\./utils/CssParser["\']', 'from "../utils/parser/CssParser"'),
    (r'from\s+["\']\.\./utils/JSParser["\']', 'from "../utils/parser/JSParser"'),
    (r'from\s+["\']\.\./utils/JsonPathParser["\']', 'from "../utils/parser/JsonPathParser"'),
    (r'from\s+["\']\.\./utils/RegexParser["\']', 'from "../utils/parser/RegexParser"'),
    (r'from\s+["\']\.\./utils/XPathParser["\']', 'from "../utils/parser/XPathParser"'),
    # 处理 from './utils/' 开头的路径 (在pages等目录中)
    (r'from\s+["\']\./utils/Logger["\']', 'from "./utils/performance/Logger"'),
    (r'from\s+["\']\./utils/NetworkManager["\']', 'from "./utils/network/NetworkManager"'),
    (r'from\s+["\']\./utils/ContentParser["\']', 'from "./utils/parser/ContentParser"'),
    (r'from\s+["\']\./utils/HTMLParser["\']', 'from "./utils/parser/HTMLParser"'),
    (r'from\s+["\']\./utils/BookSourceParser["\']', 'from "./utils/parser/BookSourceParser"'),
    (r'from\s+["\']\./utils/SearchEngine["\']', 'from "./utils/search/SearchEngine"'),
    (r'from\s+["\']\./utils/BookSourceSearchEngine["\']', 'from "./utils/search/BookSourceSearchEngine"'),
    (r'from\s+["\']\./utils/SecurityUtils["\']', 'from "./utils/security/SecurityUtils"'),
    (r'from\s+["\']\./utils/SourceValidator["\']', 'from "./utils/validation/SourceValidator"'),
    (r'from\s+["\']\./utils/FileManager["\']', 'from "./utils/file/FileManager"'),
    (r'from\s+["\']\./utils/PerformanceMonitor["\']', 'from "./utils/performance/PerformanceMonitor"'),
    (r'from\s+["\']\./utils/CrawlerManager["\']', 'from "./utils/crawler/CrawlerManager"'),
    (r'from\s+["\']\./utils/JSEngine["\']', 'from "./utils/scripting/JSEngine"'),
]

base_path = "entry/src/main/ets"
fixed_count = 0
fixed_files = []

# 遍历所有目录，除了utils目录
for root, dirs, files in os.walk(base_path):
    # 跳过utils目录
    if 'utils' in root:
        continue
    for file in files:
        if file.endswith('.ets'):
            file_path = os.path.join(root, file)
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                original = content
                
                # 应用所有修复规则
                for pattern, replacement in fix_rules:
                    content = re.sub(pattern, replacement, content)
                
                if content != original:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    rel_path = os.path.relpath(file_path, base_path)
                    fixed_files.append(rel_path)
                    fixed_count += 1
            except Exception as e:
                print(f"Error processing {file_path}: {e}")

print(f"\\n总共修复了 {fixed_count} 个文件")
print("\\n修复的文件列表 (前30个):")
for f in fixed_files[:30]:
    print(f"  - {f}")
if len(fixed_files) > 30:
    print(f"  ... 还有 {len(fixed_files) - 30} 个文件")
