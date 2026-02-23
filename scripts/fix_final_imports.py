import os
import re

# 定义最后的修复规则
fix_rules = [
    # 修复viewmodel导入
    (r'from\s+["\']\.\./viewmodel/', 'from "../../viewmodel/'),
    # 修复network目录内的相互导入
    (r'from\s+["\']\.\./network/', 'from "./'),
    # 修复其他目录对network的导入
    (r'from\s+["\']\.\./network/NetworkManager["\']', 'from "../network/NetworkManager"'),
    (r'from\s+["\']\.\./network/NetworkAdapter["\']', 'from "../network/NetworkAdapter"'),
    (r'from\s+["\']\.\./network/NetworkConfig["\']', 'from "../network/NetworkConfig"'),
]

base_path = "entry/src/main/ets/utils"
fixed_count = 0
fixed_files = []

# 遍历utils目录
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
