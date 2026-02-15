#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Android图标转HarmonyOS图标转换脚本
"""

import os
import sys
from PIL import Image

# 设置控制台输出编码为UTF-8
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

def convert_android_to_harmonyos(android_icon_path, output_path, target_size=512):
    """
    将Android图标转换为HarmonyOS格式

    Args:
        android_icon_path: Android图标路径
        output_path: 输出路径
        target_size: 目标尺寸（默认512x512）
    """
    try:
        # 打开图片
        img = Image.open(android_icon_path)

        # 转换为RGBA模式（支持透明度）
        if img.mode != 'RGBA':
            img = img.convert('RGBA')

        # 调整大小到目标尺寸
        img_resized = img.resize((target_size, target_size), Image.Resampling.LANCZOS)

        # 保存为PNG格式
        img_resized.save(output_path, 'PNG', optimize=True)
        print(f"✓ 成功转换: {android_icon_path} -> {output_path} ({target_size}x{target_size})")

    except Exception as e:
        print(f"✗ 转换失败: {android_icon_path} - {str(e)}")


def main():
    # Android图标源路径
    android_icons_dir = r"C:\Users\chend\Desktop\图标"

    # HarmonyOS项目路径
    harmonyos_media_dir = r"f:\MyApplication\AstroRead\AppScope\resources\base\media"
    harmonyos_entry_media_dir = r"f:\MyApplication\AstroRead\entry\src\main\resources\base\media"

    # 确保输出目录存在
    os.makedirs(harmonyos_media_dir, exist_ok=True)
    os.makedirs(harmonyos_entry_media_dir, exist_ok=True)

    print("=" * 60)
    print("Android图标转HarmonyOS图标转换工具")
    print("=" * 60)

    # 1. 处理应用图标（使用最高分辨率的ic_launcher.png）
    print("\n[1/3] 转换应用图标...")
    app_icon_source = os.path.join(android_icons_dir, "mipmap-xxxhdpi", "ic_launcher.png")
    app_icon_output = os.path.join(harmonyos_media_dir, "app_icon.png")
    convert_android_to_harmonyos(app_icon_source, app_icon_output, target_size=512)

    # 同时复制到entry模块
    app_icon_entry_output = os.path.join(harmonyos_entry_media_dir, "app_icon.png")
    convert_android_to_harmonyos(app_icon_source, app_icon_entry_output, target_size=512)

    # 2. 处理启动窗口图标（使用ic_launcher_round.png）
    print("\n[2/3] 转换启动窗口图标...")
    start_icon_source = os.path.join(android_icons_dir, "mipmap-xxxhdpi", "ic_launcher_round.png")
    start_icon_output = os.path.join(harmonyos_entry_media_dir, "startIcon.png")
    convert_android_to_harmonyos(start_icon_source, start_icon_output, target_size=512)

    # 3. 处理应用商店图标（playstore-icon.png）
    print("\n[3/3] 转换应用商店图标...")
    store_icon_source = os.path.join(android_icons_dir, "playstore-icon.png")
    store_icon_output = os.path.join(harmonyos_media_dir, "app_icon.png")
    convert_android_to_harmonyos(store_icon_source, store_icon_output, target_size=512)

    print("\n" + "=" * 60)
    print("转换完成！")
    print("=" * 60)
    print(f"\n图标已放置到以下位置:")
    print(f"  • 应用图标: {app_icon_output}")
    print(f"  • 启动图标: {start_icon_output}")
    print(f"  • 应用商店图标: {store_icon_output}")
    print("\n配置文件引用:")
    print(f"  • AppScope/app.json5: \"icon\": \"$media:app_icon\"")
    print(f"  • entry/src/main/module.json5: \"icon\": \"$media:app_icon\"")
    print(f"  • entry/src/main/module.json5: \"startWindowIcon\": \"$media:startIcon\"")


if __name__ == "__main__":
    main()
