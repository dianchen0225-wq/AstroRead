#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量修复弃用的 API 调用
"""

import re
import os

def fix_showtoast(content):
    """修复 showToast 调用"""
    # 匹配 showToast 调用（带类型断言，逗号结尾）
    pattern = r'promptAction\.showToast\(\{(.*?)\} as promptAction\.ShowToastOptions,'
    replacement = r'promptAction.showDialog({\n            title: \'提示\',\n            message: \1,\n            buttons: [\n              {\n                text: \'确定\',\n                color: \'#007DFF\'\n              }\n            ]\n          },'
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    return content

def fix_showtoast_semicolon(content):
    """修复 showToast 调用（带类型断言，分号结尾）"""
    pattern = r'promptAction\.showToast\(\{(.*?)\} as promptAction\.ShowToastOptions\);'
    replacement = r'promptAction.showDialog({\n            title: \'提示\',\n            message: \1,\n            buttons: [\n              {\n                text: \'确定\',\n                color: \'#007DFF\'\n              }\n            ]\n          });'
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    return content

def fix_showtoast_simple(content):
    """修复简单的 showToast 调用（没有类型断言）"""
    pattern = r'promptAction\.showToast\(\{(.*?)\);'
    replacement = r'promptAction.showDialog({\n            title: \'提示\',\n            message: \1,\n            buttons: [\n              {\n                text: \'确定\',\n                color: \'#007DFF\'\n              }\n            ]\n          });'
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    return content

def fix_error_log(content):
    """修复错误日志中的 showToast"""
    content = content.replace('showToast failed', 'showDialog failed')
    return content

def process_file(filepath):
    """处理单个文件"""
    print(f"Processing file: {filepath}")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # 应用修复
    content = fix_showtoast(content)
    content = fix_showtoast_semicolon(content)
    content = fix_showtoast_simple(content)
    content = fix_error_log(content)
    
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
