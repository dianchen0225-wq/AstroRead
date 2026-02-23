import os
import re

# 定义修复规则
fix_rules = [
    # 模型导入路径
    (r'from\s+["\']\.\./models/', 'from "../../models/'),
    # 核心模块导入路径
    (r'from\s+["\']\.\./core/', 'from "../../core/'),
    # common目录导入路径
    (r'from\s+["\']\.\./common/', 'from "../../common/'),
    # components目录导入路径
    (r'from\s+["\']\.\./components/', 'from "../../components/'),
    # pages目录导入路径
    (r'from\s+["\']\.\./pages/', 'from "../../pages/'),
    # utils内部导入 - 各模块
    (r'from\s+["\']\./Logger["\']', 'from "../performance/Logger"'),
    (r'from\s+["\']\./SafeRegex["\']', 'from "../security/SafeRegex"'),
    (r'from\s+["\']\./AstroReadJSRuntime["\']', 'from "../scripting/AstroReadJSRuntime"'),
    (r'from\s+["\']\./RequestEnhancer["\']', 'from "../crawler/RequestEnhancer"'),
    (r'from\s+["\']\./ContentParser["\']', 'from "../parser/ContentParser"'),
    (r'from\s+["\']\./AsyncChapterParser["\']', 'from "../parser/AsyncChapterParser"'),
    (r'from\s+["\']\./AsyncContentParser["\']', 'from "../parser/AsyncContentParser"'),
    (r'from\s+["\']\./NetworkConfig["\']', 'from "../network/NetworkConfig"'),
    (r'from\s+["\']\./NetworkManager["\']', 'from "../network/NetworkManager"'),
    (r'from\s+["\']\./NetworkAdapter["\']', 'from "../network/NetworkAdapter"'),
    (r'from\s+["\']\./HtmlUtils["\']', 'from "../content/HtmlUtils"'),
    (r'from\s+["\']\./StringUtils["\']', 'from "../content/StringUtils"'),
    (r'from\s+["\']\./ContentPurifier["\']', 'from "../content/ContentPurifier"'),
    (r'from\s+["\']\./ContentFilter["\']', 'from "../content/ContentFilter"'),
    (r'from\s+["\']\./ContentProcessor["\']', 'from "../content/ContentProcessor"'),
    (r'from\s+["\']\./FileManager["\']', 'from "../file/FileManager"'),
    (r'from\s+["\']\./BackupManager["\']', 'from "../file/BackupManager"'),
    (r'from\s+["\']\./DatabaseManager["\']', 'from "../file/DatabaseManager"'),
    (r'from\s+["\']\./ErrorHandler["\']', 'from "../error/ErrorHandler"'),
    (r'from\s+["\']\./ErrorHandlingService["\']', 'from "../error/ErrorHandlingService"'),
    (r'from\s+["\']\./SecurityUtils["\']', 'from "../security/SecurityUtils"'),
    (r'from\s+["\']\./SqlSecurityUtils["\']', 'from "../security/SqlSecurityUtils"'),
    (r'from\s+["\']\./SourceSandbox["\']', 'from "../security/SourceSandbox"'),
    (r'from\s+["\']\./JSSecurityConfig["\']', 'from "../security/JSSecurityConfig"'),
    (r'from\s+["\']\./SafeExpressionEngine["\']', 'from "../security/SafeExpressionEngine"'),
    (r'from\s+["\']\./SourceValidator["\']', 'from "../validation/SourceValidator"'),
    (r'from\s+["\']\./SourceValidatorService["\']', 'from "../validation/SourceValidatorService"'),
    (r'from\s+["\']\./BookSourceValidationService["\']', 'from "../validation/BookSourceValidationService"'),
    (r'from\s+["\']\./DataValidator["\']', 'from "../validation/DataValidator"'),
    (r'from\s+["\']\./SourceHealthManager["\']', 'from "../validation/SourceHealthManager"'),
    (r'from\s+["\']\./BookSourceManager["\']', 'from "../validation/BookSourceManager"'),
    (r'from\s+["\']\./SourceImportManager["\']', 'from "../validation/SourceImportManager"'),
    (r'from\s+["\']\./SourceImportTaskPool["\']', 'from "../validation/SourceImportTaskPool"'),
    (r'from\s+["\']\./BookSourceDebugger["\']', 'from "../validation/BookSourceDebugger"'),
    (r'from\s+["\']\./PerformanceMonitor["\']', 'from "../performance/PerformanceMonitor"'),
    (r'from\s+["\']\./PerformanceUtils["\']', 'from "../performance/PerformanceUtils"'),
    (r'from\s+["\']\./BackgroundTaskManager["\']', 'from "../performance/BackgroundTaskManager"'),
    (r'from\s+["\']\./LogCollector["\']', 'from "../performance/LogCollector"'),
    (r'from\s+["\']\./ParseDebugLogger["\']', 'from "../performance/ParseDebugLogger"'),
    (r'from\s+["\']\./Semaphore["\']', 'from "../performance/Semaphore"'),
    (r'from\s+["\']\./RegexCache["\']', 'from "../cache/RegexCache"'),
    (r'from\s+["\']\./WeakRefCache["\']', 'from "../cache/WeakRefCache"'),
    (r'from\s+["\']\./ParseCache["\']', 'from "../cache/ParseCache"'),
    (r'from\s+["\']\./ObjectPool["\']', 'from "../cache/ObjectPool"'),
    (r'from\s+["\']\./PoolManager["\']', 'from "../cache/PoolManager"'),
    (r'from\s+["\']\./SearchCache["\']', 'from "../cache/SearchCache"'),
    (r'from\s+["\']\./JSEngine["\']', 'from "../scripting/JSEngine"'),
    (r'from\s+["\']\./EnhancedJSEngine["\']', 'from "../scripting/EnhancedJSEngine"'),
    (r'from\s+["\']\./ScriptEngine["\']', 'from "../scripting/ScriptEngine"'),
    (r'from\s+["\']\./CrawlerManager["\']', 'from "../crawler/CrawlerManager"'),
    (r'from\s+["\']\./CrawlerIndex["\']', 'from "../crawler/CrawlerIndex"'),
    (r'from\s+["\']\./CrawlerMonitor["\']', 'from "../crawler/CrawlerMonitor"'),
    (r'from\s+["\']\./CrawlerRequestHandler["\']', 'from "../crawler/CrawlerRequestHandler"'),
    (r'from\s+["\']\./ImageScraperService["\']', 'from "../crawler/ImageScraperService"'),
    (r'from\s+["\']\./ImageScrapeManager["\']', 'from "../crawler/ImageScrapeManager"'),
    (r'from\s+["\']\./ImageDetector["\']', 'from "../crawler/ImageDetector"'),
    (r'from\s+["\']\./RequestThrottler["\']', 'from "../crawler/RequestThrottler"'),
    (r'from\s+["\']\./SearchEngine["\']', 'from "../search/SearchEngine"'),
    (r'from\s+["\']\./BookSourceSearchEngine["\']', 'from "../search/BookSourceSearchEngine"'),
    (r'from\s+["\']\./EnhancedBookSourceSearchEngine["\']', 'from "../search/EnhancedBookSourceSearchEngine"'),
    (r'from\s+["\']\./SearchQueryParser["\']', 'from "../search/SearchQueryParser"'),
    (r'from\s+["\']\./SearchResultValidator["\']', 'from "../search/SearchResultValidator"'),
    (r'from\s+["\']\./SearchImageEnhancer["\']', 'from "../search/SearchImageEnhancer"'),
    (r'from\s+["\']\./SearchEnhancer["\']', 'from "../search/SearchEnhancer"'),
    (r'from\s+["\']\./SmartSourceSelector["\']', 'from "../search/SmartSourceSelector"'),
    (r'from\s+["\']\./SelectorCore["\']', 'from "../parser/SelectorCore"'),
    (r'from\s+["\']\./OptimizedSelectorEngine["\']', 'from "../parser/OptimizedSelectorEngine"'),
    (r'from\s+["\']\./ParserCore["\']', 'from "../parser/ParserCore"'),
    (r'from\s+["\']\./IParser["\']', 'from "../parser/IParser"'),
    (r'from\s+["\']\./HTMLParser["\']', 'from "../parser/HTMLParser"'),
    (r'from\s+["\']\./CssSelectorParser["\']', 'from "../parser/CssSelectorParser"'),
    (r'from\s+["\']\./AsyncCssSelectorParser["\']', 'from "../parser/AsyncCssSelectorParser"'),
    (r'from\s+["\']\./XPathEngine["\']', 'from "../parser/XPathEngine"'),
    (r'from\s+["\']\./RuleEngine["\']', 'from "../parser/RuleEngine"'),
    (r'from\s+["\']\./RuleAnalyzer["\']', 'from "../parser/RuleAnalyzer"'),
    (r'from\s+["\']\./AnalyzeRule["\']', 'from "../parser/AnalyzeRule"'),
    (r'from\s+["\']\./BookSourceParser["\']', 'from "../parser/BookSourceParser"'),
    (r'from\s+["\']\./FileParser["\']', 'from "../parser/FileParser"'),
    (r'from\s+["\']\./TXTParser["\']', 'from "../parser/TXTParser"'),
    (r'from\s+["\']\./EPUBParser["\']', 'from "../parser/EPUBParser"'),
    (r'from\s+["\']\./LocalFileParser["\']', 'from "../parser/LocalFileParser"'),
    (r'from\s+["\']\./CssParser["\']', 'from "../parser/CssParser"'),
    (r'from\s+["\']\./JSParser["\']', 'from "../parser/JSParser"'),
    (r'from\s+["\']\./JsonPathParser["\']', 'from "../parser/JsonPathParser"'),
    (r'from\s+["\']\./RegexParser["\']', 'from "../parser/RegexParser"'),
    (r'from\s+["\']\./XPathParser["\']', 'from "../parser/XPathParser"'),
    (r'from\s+["\']\./IdGenerator["\']', 'from "../content/IdGenerator"'),
    (r'from\s+["\']\./ToastUtils["\']', 'from "../content/ToastUtils"'),
]

base_path = "entry/src/main/ets/utils"
fixed_count = 0
fixed_files = []

# 遍历所有子目录
for root, dirs, files in os.walk(base_path):
    # 跳过 __tests__ 目录
    if '__tests__' in root:
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
print("\\n修复的文件列表:")
for f in fixed_files[:20]:  # 只显示前20个
    print(f"  - {f}")
if len(fixed_files) > 20:
    print(f"  ... 还有 {len(fixed_files) - 20} 个文件")
