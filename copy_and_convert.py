import os
import shutil

# 源目录和目标目录
source_dir = r"F:\MyApplication\AstroRead\entry\src\main"
target_dir = r"F:\1"
merged_dir = r"F:\1\merged"

# 确保目标目录存在
os.makedirs(target_dir, exist_ok=True)

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

# 创建合并文件夹
os.makedirs(merged_dir, exist_ok=True)

# 遍历目标目录，合并每个子文件夹内的txt文件
for root, dirs, files in os.walk(target_dir):
    # 跳过merged目录
    if merged_dir in root:
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

print("所有文件合并完成！")
