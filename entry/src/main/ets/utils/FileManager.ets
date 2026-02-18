/**
 * FileManager - 文件管理器
 * 提供本地文件浏览、导入、解析功能
 * 替代 Android SAF/FileProvider
 */

import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import util from '@ohos.util';
import common from '@ohos.app.ability.common';
import { Logger } from './Logger';

export interface FileInfo {
  name: string;
  path: string;
  size: number;
  modifyTime: number;
  isDirectory: boolean;
  extension: string;
}

export interface ImportResult {
  success: boolean;
  path?: string;
  content?: string;
  error?: string;
}

export class FileManager {
  private static instance: FileManager | null = null;
  private readonly TAG = 'FileManager';
  private readonly SUPPORTED_EXTENSIONS: string[] = ['.txt', '.epub', '.pdf'];
  private context: common.UIAbilityContext | null = null;

  static getInstance(): FileManager {
    if (!FileManager.instance) {
      FileManager.instance = new FileManager();
    }
    return FileManager.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  getContext(): common.UIAbilityContext | null {
    return this.context;
  }

  /**
   * 打开文件选择器
   * 让用户选择要导入的书籍文件
   */
  async pickFile(): Promise<ImportResult> {
    try {
      // 创建文档选择器
      const documentPicker = new picker.DocumentViewPicker();

      // 配置选择选项
      const selectOptions: picker.DocumentSelectOptions = {
        maxSelectNumber: 1,
        defaultFilePathUri: '',
        fileSuffixFilters: ['txt', 'epub', 'pdf']
      };

      // 打开选择器
      const result = await documentPicker.select(selectOptions);

      if (result && result.length > 0) {
        const uri = result[0];
        return await this.importFile(uri);
      }

      return { success: false, error: '用户取消选择' };
    } catch (error) {
      Logger.error(this.TAG, `选择文件失败: ${error}`);
      return { success: false, error: String(error) };
    }
  }

  /**
   * 导入文件到应用沙盒
   */
  async importFile(uri: string): Promise<ImportResult> {
    try {
      // 获取文件信息
      const fileInfo = fs.statSync(uri);
      const fileName = this.getFileNameFromUri(uri);
      const extension = this.getFileExtension(fileName).toLowerCase();

      Logger.info(this.TAG, `导入文件: ${fileName}, 大小: ${fileInfo.size}`);

      // 检查文件类型
      if (!this.SUPPORTED_EXTENSIONS.includes(extension)) {
        return { success: false, error: `不支持的文件格式: ${extension}` };
      }

      // 读取文件内容
      const content = await this.readFileContent(uri);

      // 复制到应用沙盒
      const sandboxPath = await this.copyToSandbox(uri, fileName);

      return {
        success: true,
        path: sandboxPath,
        content: content
      };
    } catch (error) {
      Logger.error(this.TAG, `导入文件失败: ${error}`);
      return { success: false, error: String(error) };
    }
  }

  /**
   * 读取文件内容
   */
  async readFileContent(uri: string): Promise<string> {
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);

      fs.readSync(file.fd, buffer);
      fs.closeSync(file);

      // 尝试多种编码解码
      const encodings: string[] = ['utf-8', 'gbk', 'gb2312', 'gb18030', 'big5'];

      for (const encoding of encodings) {
        try {
          const decoder = new util.TextDecoder(encoding);
          const content = decoder.decodeToString(new Uint8Array(buffer));
          // 检查解码是否成功（没有乱码）
          if (this.isValidContent(content)) {
            Logger.info(this.TAG, `使用编码: ${encoding}`);
            return content;
          }
        } catch (e) {
          continue;
        }
      }

      // 默认使用 utf-8
      const defaultDecoder = new util.TextDecoder('utf-8');
      return defaultDecoder.decodeToString(new Uint8Array(buffer));
    } catch (error) {
      Logger.error(this.TAG, `读取文件失败: ${error}`);
      throw new Error(`读取文件失败: ${error}`);
    }
  }

  /**
   * 检查内容是否有效（无乱码）
   */
  private isValidContent(content: string): boolean {
    // 检查是否包含大量替换字符（乱码标志）
    const replacementChar = '\uFFFD';
    const replacementCount = (content.match(new RegExp(replacementChar, 'g')) || []).length;
    const ratio = replacementCount / content.length;

    // 替换字符比例超过 1% 认为解码失败
    return ratio < 0.01;
  }

  /**
   * 复制文件到应用沙盒
   */
  private async copyToSandbox(sourceUri: string, fileName: string): Promise<string> {
    if (!this.context) {
      throw new Error('上下文未设置，请先调用 setContext() 方法');
    }
    const sandboxPath = `${this.context.filesDir}/books/${fileName}`;

    try {
      // 确保目录存在
      const dir = sandboxPath.substring(0, sandboxPath.lastIndexOf('/'));
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }

      // 复制文件
      fs.copyFileSync(sourceUri, sandboxPath);

      return sandboxPath;
    } catch (error) {
      Logger.error('FileManager', `复制文件到沙盒失败: ${error}`);
      throw new Error(`复制文件失败: ${error}`);
    }
  }

  /**
   * 获取应用沙盒中的书籍文件
   */
  getBookFiles(): FileInfo[] {
    try {
      if (!this.context) {
        Logger.error(this.TAG, '上下文未设置，无法获取书籍文件');
        return [];
      }
      const booksDir = `${this.context.filesDir}/books`;

      if (!fs.accessSync(booksDir)) {
        return [];
      }

      const files = fs.listFileSync(booksDir);
      const fileInfos: FileInfo[] = [];

      for (const fileName of files) {
        const filePath = `${booksDir}/${fileName}`;
        const stat = fs.statSync(filePath);

        fileInfos.push({
          name: fileName,
          path: filePath,
          size: stat.size,
          modifyTime: stat.mtime,
          isDirectory: stat.isDirectory(),
          extension: this.getFileExtension(fileName)
        });
      }

      // 按修改时间排序
      return fileInfos.sort((a: FileInfo, b: FileInfo) => b.modifyTime - a.modifyTime);
    } catch (error) {
      Logger.error(this.TAG, `获取书籍文件失败: ${error}`);
      return [];
    }
  }

  /**
   * 删除文件
   */
  deleteFile(path: string): boolean {
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
        return true;
      }
      return false;
    } catch (error) {
      Logger.error(this.TAG, `删除文件失败: ${error}`);
      return false;
    }
  }

  /**
   * 获取文件大小（友好格式）
   */
  getFileSizeString(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
  }

  /**
   * 从 URI 获取文件名
   */
  private getFileNameFromUri(uri: string): string {
    const parts = uri.split('/');
    return parts[parts.length - 1] || 'unknown';
  }

  /**
   * 获取文件扩展名
   */
  private getFileExtension(fileName: string): string {
    const index = fileName.lastIndexOf('.');
    return index > -1 ? fileName.substring(index) : '';
  }

  /**
   * 检查文件是否存在
   */
  fileExists(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (error) {
      Logger.error(this.TAG, `检查文件存在失败: ${error}`);
      return false;
    }
  }

  /**
   * 创建目录
   */
  createDirectory(path: string): boolean {
    try {
      if (!fs.accessSync(path)) {
        fs.mkdirSync(path, true);
      }
      return true;
    } catch (error) {
      Logger.error(this.TAG, `创建目录失败: ${error}`);
      return false;
    }
  }
}

export default FileManager.getInstance();
