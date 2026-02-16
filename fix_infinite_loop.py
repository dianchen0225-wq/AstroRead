#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复 router.pushUrl 的无限循环问题
"""

import re
import os

def fix_router_pushurl_loop(content):
    """修复 router.pushUrl 的无限循环"""
    # 匹配 router.pushUrl 后面跟着多个 Url 的情况
    pattern = r'router\.pushUrl(Url)+'
    replacement = r'router.pushUrl'
    content = re.sub(pattern, replacement, content)
    return content

def process_file(filepath):
    """处理单个文件"""
    print(f"Processing file: {filepath}")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # 应用修复
    content = fix_router_pushurl_loop(content)
    
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
        'BookshelfPage.ets',
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