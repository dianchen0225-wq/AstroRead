#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
完整修复所有格式错误的 showDialog 调用
"""

import re
import os

def fix_all_malformed_showdialog(content):
    """修复所有格式错误的 showDialog 调用"""
    # 匹配所有格式错误的 showDialog 调用
    # 模式1: message: 后面跟着 message:
    pattern1 = r'promptAction\.showDialog\(\{[^}]*title: \'提示\',\s*message:\s*message: \'([^\']+)\',\s*duration: \d+\s*\} as promptAction\.ShowToastOptions,'
    replacement1 = r'promptAction.showDialog({\n            title: \'提示\',\n            message: \'\1\',\n            buttons:'
    content = re.sub(pattern1, replacement1, content, flags=re.DOTALL)
    
    # 模式2: 只有 message: 后面跟着 message: (没有 title)
    pattern2 = r'promptAction\.showDialog\(\{[^}]*message:\s*message: \'([^\']+)\',\s*duration: \d+\s*\} as promptAction\.ShowToastOptions,'
    replacement2 = r'promptAction.showDialog({\n            title: \'提示\',\n            message: \'\1\',\n            buttons:'
    content = re.sub(pattern2, replacement2, content, flags=re.DOTALL)
    
    return content

def fix_remaining_toast_options(content):
    """修复剩余的 ShowToastOptions"""
    # 匹配任何剩余的 ShowToastOptions
    pattern = r'\} as promptAction\.ShowToastOptions,'
    replacement = r'},'
    content = re.sub(pattern, replacement, content)
    return content

def fix_duplicate_message(content):
    """修复重复的 message 字段"""
    # 匹配重复的 message 字段
    pattern = r'message:\s*message:'
    replacement = r'message:'
    content = re.sub(pattern, replacement, content)
    return content

def fix_duration_field(content):
    """移除 duration 字段"""
    # 匹配 duration 字段
    pattern = r',\s*duration: \d+'
    replacement = r''
    content = re.sub(pattern, replacement, content)
    return content

def process_file(filepath):
    """处理单个文件"""
    print(f"Processing file: {filepath}")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # 应用修复
    content = fix_all_malformed_showdialog(content)
    content = fix_remaining_toast_options(content)
    content = fix_duplicate_message(content)
    content = fix_duration_field(content)
    
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
