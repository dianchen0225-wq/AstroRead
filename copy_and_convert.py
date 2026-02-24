import os
import shutil

# 源目录和目标目录
source_dir = r"F:\MyApplication\AstroRead\entry\src\main"
target_dir = r"F:\1"
merged_dir = r"F:\1\merged"

# 按功能分类的文件字典
# key: 功能文件夹名, value: 该功能相关的文件列表
functional_groups = {
    "书源管理": [
        r"ets\utils\BookSourceManager.ets",
        r"ets\utils\BookSourceParser.ets",
        r"ets\utils\SourceHealthManager.ets",
        r"ets\core\SourceManagerInterface.ets",
    ],
    "书源搜索": [
        r"ets\utils\BookSourceSearchEngine.ets",
        r"ets\utils\SearchEngine.ets",
        r"ets\utils\AdvancedSearchEngine.ets",
        r"ets\models\SearchResult.ets",
    ],
    "书源调试": [
        r"ets\utils\BookSourceDebugger.ets",
    ],
    "HTML解析": [
        r"ets\utils\ParserCore.ets",
        r"ets\utils\HTMLParser.ets",
        r"ets\utils\CssSelectorParser.ets",
        r"ets\utils\AsyncCssSelectorParser.ets",
        r"ets\utils\AnalyzeRule.ets",
        r"ets\utils\ContentProcessor.ets",
        r"ets\utils\ParseCache.ets",
        r"ets\models\ContentFilter.ets",
    ],
    "JS引擎": [
        r"ets\utils\EnhancedJSEngine.ets",
    ],
    "网络请求": [
        r"ets\utils\NetworkAdapter.ets",
    ],
    "数据模型": [
        r"ets\models\BookSource.ets",
        r"ets\models\Book.ets",
        r"ets\models\Chapter.ets",
    ],
    "核心接口": [
        r"ets\core\AstroReadFacade.ets",
    ],
    "测试文件": [
        r"ets\core\__tests__\ParserCore.test.ets",
        r"ets\core\__tests__\BookSourceManager.test.ets",
        r"ets\core\__tests__\SearchEngine.test.ets",
    ],
}

# 确保目标目录存在
os.makedirs(target_dir, exist_ok=True)

# 创建功能分类文件夹
functional_dirs = {}
for group_name in functional_groups.keys():
    group_dir = os.path.join(target_dir, group_name)
    os.makedirs(group_dir, exist_ok=True)
    functional_dirs[group_name] = group_dir

# 遍历源目录下的所有文件和文件夹
for root, dirs, files in os.walk(source_dir):
    for file in files:
        source_file_path = os.path.join(root, file)
        # 计算相对路径
        relative_path = os.path.relpath(source_file_path, source_dir)
        # 构建目标文件路径
        target_file_path = os.path.join(target_dir, relative_path)
        # 确保目标文件的目录存在
        os.makedirs(os.path.dirname(target_file_path), exist_ok=True)
        # 复制文件
        shutil.copy2(source_file_path, target_file_path)
        print(f"已复制: {source_file_path} -> {target_file_path}")

print("所有文件复制完成！")

# 遍历目标目录下的所有文件，将非txt文件转换为txt格式
for root, dirs, files in os.walk(target_dir):
    for file in files:
        file_path = os.path.join(root, file)
        # 如果文件不是txt格式，则转换为txt
        if not file.lower().endswith('.txt'):
            # 读取文件内容
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                # 构建新的txt文件路径
                txt_file_path = os.path.splitext(file_path)[0] + '.txt'
                # 写入txt文件
                with open(txt_file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"已转换: {file_path} -> {txt_file_path}")
                # 删除原文件
                os.remove(file_path)
            except Exception as e:
                print(f"转换失败: {file_path}, 错误: {e}")

print("所有文件转换完成！")

# 按功能分类提取文件
print("\n开始按功能分类提取文件...")

for group_name, file_list in functional_groups.items():
    group_dir = functional_dirs[group_name]
    print(f"\n处理功能分类: {group_name}")
    
    for relative_file in file_list:
        # 构建源txt文件路径（已转换后的路径）
        txt_relative_path = os.path.splitext(relative_file)[0] + '.txt'
        source_txt_path = os.path.join(target_dir, txt_relative_path)
        
        if os.path.exists(source_txt_path):
            # 获取原文件名（不带路径）
            original_filename = os.path.basename(txt_relative_path)
            target_file_path = os.path.join(group_dir, original_filename)
            
            # 复制文件（保持原文件名）
            shutil.copy2(source_txt_path, target_file_path)
            print(f"  已提取: {original_filename}")
        else:
            print(f"  文件不存在，跳过: {txt_relative_path}")

print("\n功能分类提取完成！")

# 创建合并文件夹
os.makedirs(merged_dir, exist_ok=True)

# 为每个功能分类创建合并文件
print("\n开始创建功能分类合并文件...")

for group_name in functional_groups.keys():
    group_dir = functional_dirs[group_name]
    merged_file_path = os.path.join(merged_dir, f"{group_name}_merged.txt")
    
    contents = []
    contents.append("=" * 80)
    contents.append(f"{group_name} - 合并文件")
    contents.append("=" * 80)
    contents.append("")
    
    # 遍历功能文件夹，合并所有txt文件
    for file in sorted(os.listdir(group_dir)):
        if file.lower().endswith('.txt'):
            file_path = os.path.join(group_dir, file)
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                contents.append("=" * 80)
                contents.append(f"文件: {file}")
                contents.append("=" * 80)
                contents.append("")
                contents.append(content)
                contents.append("")
                contents.append("")
            except Exception as e:
                print(f"读取失败: {file_path}, 错误: {e}")
    
    # 写入合并文件
    with open(merged_file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(contents))
    print(f"已创建合并文件: {merged_file_path}")

# 遍历目标目录（排除功能分类文件夹和merged文件夹），合并每个子文件夹内的txt文件
print("\n开始合并其他文件...")

exclude_dirs = set(functional_dirs.values())
exclude_dirs.add(merged_dir)

for root, dirs, files in os.walk(target_dir):
    # 跳过功能分类文件夹和merged目录
    if any(root.startswith(exclude) for exclude in exclude_dirs):
        continue
    
    # 获取当前目录下的所有txt文件
    txt_files = [f for f in files if f.lower().endswith('.txt')]
    
    if txt_files:
        # 计算相对路径，用于命名合并后的文件
        relative_path = os.path.relpath(root, target_dir)
        # 替换路径分隔符为下划线，用于文件名
        merged_file_name = relative_path.replace(os.sep, '_') + '_merged.txt'
        merged_file_path = os.path.join(merged_dir, merged_file_name)
        
        # 合并所有txt文件
        try:
            with open(merged_file_path, 'w', encoding='utf-8') as merged_file:
                for txt_file in sorted(txt_files):
                    txt_file_path = os.path.join(root, txt_file)
                    with open(txt_file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    # 写入文件分隔标识
                    merged_file.write(f"{'='*50}\n")
                    merged_file.write(f"文件: {txt_file}\n")
                    merged_file.write(f"{'='*50}\n\n")
                    merged_file.write(content)
                    merged_file.write("\n\n")
            print(f"已合并: {root} -> {merged_file_path}")
        except Exception as e:
            print(f"合并失败: {root}, 错误: {e}")

print("\n所有文件处理完成！")
print(f"\n输出目录结构:")
print(f"  - {target_dir} (所有文件)")
for group_name in functional_groups.keys():
    print(f"  - {os.path.join(target_dir, group_name)} ({group_name}相关文件)")
print(f"  - {merged_dir} (合并后的文件)")
