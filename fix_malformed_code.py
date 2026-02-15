#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复格式错误的 showDialog 调用
"""

import re
import os

def fix_malformed_showdialog(content):
    """修复格式错误的 showDialog 调用"""
    # 匹配格式错误的 showDialog 调用
    pattern = r'promptAction\.showDialog\(\{\s*title: \'提示\',\s*message:\s*message: \'([^\']+)\',\s*duration: \d+\s*\} as promptAction\.ShowToastOptions,\s*buttons:'
    replacement = r'promptAction.showDialog({\n          title: \'提示\',\n          message: \'\1\',\n          buttons:'
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    return content

def fix_escaped_quotes(content):
    """修复转义的引号"""
    content = content.replace("\\'", "'")
    return content

def process_file(filepath):
    """处理单个文件"""
    print(f"Processing file: {filepath}")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # 应用修复
    content = fix_malformed_showdialog(content)
    content = fix_escaped_quotes(content)
    
    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  [OK] Fixed file: {filepath}")
        return True
    else:
        print(f"  [SKIP] No changes needed: {filepath}")
        return False

def main():
    """主函数"""
    base_dir = "F:/MyApplication/AstroRead/entry/src/main/ets/pages"
    
    files_to_fix = [
        'SourcePage.ets',
        'ReadPage.ets',
        'BookDetailPage.ets'
    ]
    
    fixed_count = 0
    for filename in files_to_fix:
        filepath = os.path.join(base_dir, filename)
        if os.path.exists(filepath):
            if process_file(filepath):
                fixed_count += 1
        else:
            print(f"  [ERROR] File not found: {filepath}")
    
    print(f"\nDone! Fixed {fixed_count} files.")

if __name__ == '__main__':
    main()
