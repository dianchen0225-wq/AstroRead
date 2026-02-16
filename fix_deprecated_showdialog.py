#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复弃用的 showDialog API 调用
将 promptAction.showDialog 替换为 AlertDialog.show
并修复参数格式
"""

import re
import os

def fix_showdialog_to_alertdialog(content):
    """将 promptAction.showDialog 替换为 AlertDialog.show"""
    # 替换导入语句
    content = content.replace("import { promptAction } from '@kit.ArkUI';", 
                             "import { AlertDialog } from '@kit.ArkUI';")
    
    # 替换 showDialog 调用为 AlertDialog.show
    content = content.replace("promptAction.showDialog", "AlertDialog.show")
    
    return content

def fix_buttons_to_confirm(content):
    """将 buttons 参数改为 confirm 参数"""
    # 匹配 buttons 数组格式
    pattern = r'buttons:\s*\[\s*{\s*text:\s*[\'"]([^\'"]+)[\'"],\s*color:\s*[\'"]#007DFF[\'"]\s*}\s*\]'
    replacement = r'confirm: {\n              value: "\1",\n              action: () => {}\n            }'
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    # 匹配简单的 buttons 格式
    pattern2 = r'buttons:\s*\[\s*{\s*text:\s*[\'"]([^\'"]+)[\'"]\s*}\s*\]'
    replacement2 = r'confirm: {\n              value: "\1",\n              action: () => {}\n            }'
    content = re.sub(pattern2, replacement2, content, flags=re.DOTALL)
    
    return content

def fix_error_messages(content):
    """修复错误消息中的 showDialog"""
    content = content.replace("showDialog failed", "AlertDialog.show failed")
    return content

def fix_router_push(content):
    """将 router.push 替换为 router.pushUrl"""
    content = content.replace("router.push", "router.pushUrl")
    return content

def fix_getparams(content):
    """将 getParams 替换为 getParamsSync"""
    content = content.replace(".getParams()", ".getParamsSync()")
    return content

def fix_back(content):
    """将 back 替换为 backUrl"""
    content = content.replace("router.back()", "router.backUrl()")
    return content

def process_file(filepath):
    """处理单个文件"""
    print(f"Processing file: {filepath}")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # 应用修复
    content = fix_showdialog_to_alertdialog(content)
    content = fix_buttons_to_confirm(content)
    content = fix_error_messages(content)
    content = fix_router_push(content)
    content = fix_getparams(content)
    content = fix_back(content)
    
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
        'SearchPage.ets',
        'SourcePage.ets',
        'ReadPage.ets',
        'BookDetailPage.ets',
        'BookshelfPage.ets'
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