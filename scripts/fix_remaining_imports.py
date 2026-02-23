import os
import re

# 定义额外的修复规则
fix_rules = [
    # 修复viewmodel中的utils导入
    (r'from\s+["\']\.\./utils/SearchEnhancer["\']', 'from "../utils/search/SearchEnhancer"'),
    (r'from\s+["\']\.\./utils/SourceImportTaskPool["\']', 'from "../utils/validation/SourceImportTaskPool"'),
    (r'from\s+["\']\.\./utils/SmartSourceSelector["\']', 'from "../utils/search/SmartSourceSelector"'),
    # 修复任何遗漏的utils导入
    (r'from\s+["\']\.\./utils/([A-Za-z]+)["\']', r'from "../utils/\1"'),
]

base_path = "entry/src/main/ets"
fixed_count = 0
fixed_files = []

# 遍历所有目录
for root, dirs, files in os.walk(base_path):
    for file in files:
        if file.endswith('.ets'):
            file_path = os.path.join(root, file)
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                original = content
                
                # 应用修复规则
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
if fixed_files:
    print("\\n修复的文件列表:")
    for f in fixed_files:
        print(f"  - {f}")
