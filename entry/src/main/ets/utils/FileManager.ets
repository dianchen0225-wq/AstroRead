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
  encoding?: string;
  confidence?: number;
}

export interface EncodingDetectionResult {
  encoding: string;
  confidence: number;
  hasBOM: boolean;
  bomType?: string;
}

export interface BOMDetectionResult {
  hasBOM: boolean;
  encoding: string;
  bomType?: string;
}

export class FileManager {
  private static instance: FileManager | null = null;
  private readonly TAG = 'FileManager';
  private readonly SUPPORTED_EXTENSIONS: string[] = ['.txt', '.epub', '.pdf'];
  private context: common.UIAbilityContext | null = null;

  private readonly BOM_PATTERNS: Map<string, Uint8Array> = new Map([
    ['UTF-8', new Uint8Array([0xEF, 0xBB, 0xBF])],
    ['UTF-16LE', new Uint8Array([0xFF, 0xFE])],
    ['UTF-16BE', new Uint8Array([0xFE, 0xFF])],
    ['UTF-32LE', new Uint8Array([0xFF, 0xFE, 0x00, 0x00])],
    ['UTF-32BE', new Uint8Array([0x00, 0x00, 0xFE, 0xFF])]
  ]);

  private readonly ENCODING_PRIORITY: string[] = [
    'utf-8',
    'gb18030',
    'gbk',
    'gb2312',
    'big5',
    'utf-16le',
    'utf-16be'
  ];

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

  async readFileContent(uri: string): Promise<string> {
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);

      fs.readSync(file.fd, buffer);
      fs.closeSync(file);

      const uint8Array = new Uint8Array(buffer);
      const detectionResult = this.detectEncoding(uint8Array);
      
      Logger.info(this.TAG, `检测到编码: ${detectionResult.encoding}, 置信度: ${detectionResult.confidence}, BOM: ${detectionResult.hasBOM}`);

      let contentStart = 0;
      if (detectionResult.hasBOM && detectionResult.bomType) {
        const bomBytes = this.BOM_PATTERNS.get(detectionResult.bomType);
        if (bomBytes) {
          contentStart = bomBytes.length;
        }
      }

      const contentBuffer = uint8Array.slice(contentStart);
      
      const content = this.decodeContent(contentBuffer, detectionResult.encoding);
      
      if (this.isValidContent(content)) {
        return content;
      }

      Logger.warn(this.TAG, '解码结果验证失败，尝试其他编码');
      return this.tryAlternativeEncodings(contentBuffer, detectionResult.encoding);
    } catch (error) {
      Logger.error(this.TAG, `读取文件失败: ${error}`);
      throw new Error(`读取文件失败: ${error}`);
    }
  }

  detectEncoding(data: Uint8Array): EncodingDetectionResult {
    const bomResult = this.detectBOM(data);
    if (bomResult.hasBOM) {
      return {
        encoding: bomResult.encoding,
        confidence: 1.0,
        hasBOM: true,
        bomType: bomResult.bomType
      };
    }

    if (this.isValidUTF8(data)) {
      return {
        encoding: 'utf-8',
        confidence: 0.9,
        hasBOM: false
      };
    }

    const gbResult = this.detectGBEncoding(data);
    if (gbResult.confidence > 0.7) {
      return gbResult;
    }

    const defaultResult: EncodingDetectionResult = {
      encoding: 'gb18030',
      confidence: 0.5,
      hasBOM: false
    };
    return defaultResult;
  }

  private detectBOM(data: Uint8Array): BOMDetectionResult {
    const entries = Array.from(this.BOM_PATTERNS.entries());
    for (let idx = 0; idx < entries.length; idx++) {
      const entry = entries[idx];
      const encoding = entry[0];
      const bom = entry[1];
      if (data.length >= bom.length) {
        let match = true;
        for (let i = 0; i < bom.length; i++) {
          if (data[i] !== bom[i]) {
            match = false;
            break;
          }
        }
        if (match) {
          const result: BOMDetectionResult = {
            hasBOM: true,
            encoding: encoding.toLowerCase(),
            bomType: encoding
          };
          return result;
        }
      }
    }
    const result: BOMDetectionResult = { hasBOM: false, encoding: '' };
    return result;
  }

  private isValidUTF8(data: Uint8Array): boolean {
    let i = 0;
    while (i < data.length) {
      const byte = data[i];
      if (byte <= 0x7F) {
        i++;
        continue;
      }
      
      let seqLength = 0;
      if ((byte & 0xE0) === 0xC0) {
        seqLength = 2;
      } else if ((byte & 0xF0) === 0xE0) {
        seqLength = 3;
      } else if ((byte & 0xF8) === 0xF0) {
        seqLength = 4;
      } else {
        return false;
      }

      if (i + seqLength > data.length) {
        return false;
      }

      for (let j = 1; j < seqLength; j++) {
        if ((data[i + j] & 0xC0) !== 0x80) {
          return false;
        }
      }
      i += seqLength;
    }
    return true;
  }

  private detectGBEncoding(data: Uint8Array): EncodingDetectionResult {
    let gbLikeBytes = 0;
    let totalMultiByte = 0;
    const sampleSize = Math.min(data.length, 4096);

    for (let i = 0; i < sampleSize - 1; i++) {
      const byte1 = data[i];
      const byte2 = data[i + 1];

      if (byte1 >= 0x81 && byte1 <= 0xFE) {
        totalMultiByte++;
        if (byte2 >= 0x40 && byte2 <= 0xFE && byte2 !== 0x7F) {
          gbLikeBytes++;
        }
      }
    }

    const confidence = totalMultiByte > 0 ? gbLikeBytes / totalMultiByte : 0;

    return {
      encoding: 'gb18030',
      confidence: Math.min(confidence, 0.95),
      hasBOM: false
    };
  }

  private decodeContent(data: Uint8Array, encoding: string): string {
    try {
      const decoder = new util.TextDecoder(encoding);
      return decoder.decodeToString(data);
    } catch (e) {
      Logger.error(this.TAG, `解码失败 (${encoding}): ${e}`);
      const fallbackDecoder = new util.TextDecoder('utf-8');
      return fallbackDecoder.decodeToString(data);
    }
  }

  private tryAlternativeEncodings(data: Uint8Array, excludeEncoding: string): string {
    for (const encoding of this.ENCODING_PRIORITY) {
      if (encoding === excludeEncoding) {
        continue;
      }
      try {
        const content = this.decodeContent(data, encoding);
        if (this.isValidContent(content)) {
          Logger.info(this.TAG, `使用备用编码成功: ${encoding}`);
          return content;
        }
      } catch (e) {
        continue;
      }
    }

    Logger.warn(this.TAG, '所有编码尝试失败，使用UTF-8');
    return this.decodeContent(data, 'utf-8');
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

    const safeFileName = this.sanitizeFileName(fileName);
    if (!safeFileName) {
      throw new Error('文件名无效或包含不安全字符');
    }

    const sandboxPath = `${this.context.filesDir}/books/${safeFileName}`;

    if (!this.isPathWithinSandbox(sandboxPath)) {
      throw new Error('文件路径不在安全沙盒范围内');
    }

    try {
      const dir = sandboxPath.substring(0, sandboxPath.lastIndexOf('/'));
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }

      fs.copyFileSync(sourceUri, sandboxPath);

      return sandboxPath;
    } catch (error) {
      Logger.error('FileManager', `复制文件到沙盒失败: ${error}`);
      throw new Error(`复制文件失败: ${error}`);
    }
  }

  /**
   * 清理文件名，防止路径遍历攻击
   */
  private sanitizeFileName(fileName: string): string {
    if (!fileName || fileName.trim().length === 0) {
      return '';
    }

    let sanitized = fileName.trim();

    const dangerousPatterns = [
      /\.\./g,           // 父目录遍历
      /\.\.\//g,         // Unix路径遍历
      /\.\.\\/g,         // Windows路径遍历
      /\//g,             // Unix路径分隔符
      /\\/g,             // Windows路径分隔符
      /:/g,              // Windows驱动器分隔符
      /\*/g,             // 通配符
      /\?/g,             // 通配符
      /"/g,              // 引号
      /</g,              // 重定向
      />/g,              // 重定向
      /\|/g,             // 管道
      /\0/g,             // 空字节
      /\x00-\x1f/g,      // 控制字符
    ];

    for (const pattern of dangerousPatterns) {
      sanitized = sanitized.replace(pattern, '_');
    }

    const maxFileNameLength = 255;
    if (sanitized.length > maxFileNameLength) {
      const ext = this.getFileExtension(sanitized);
      const nameWithoutExt = sanitized.substring(0, sanitized.lastIndexOf('.' + ext));
      const truncatedName = nameWithoutExt.substring(0, maxFileNameLength - ext.length - 1);
      sanitized = `${truncatedName}.${ext}`;
    }

    if (sanitized.startsWith('.')) {
      sanitized = '_' + sanitized.substring(1);
    }

    if (!/^[\w\u4e00-\u9fa5\-_.]+$/.test(sanitized)) {
      const ext = this.getFileExtension(sanitized);
      const timestamp = Date.now();
      sanitized = `file_${timestamp}.${ext}`;
    }

    return sanitized;
  }

  /**
   * 检查路径是否在沙盒范围内
   */
  private isPathWithinSandbox(path: string): boolean {
    if (!this.context) {
      return false;
    }

    let normalizedPath = path.replace(/\\/g, '/');
    while (normalizedPath.includes('//')) {
      normalizedPath = normalizedPath.replace(/\/\//g, '/');
    }
    while (normalizedPath.includes('/./')) {
      normalizedPath = normalizedPath.replace(/\/\.\//g, '/');
    }
    while (normalizedPath.includes('/../')) {
      const before = normalizedPath;
      normalizedPath = normalizedPath.replace(/\/[^\/]+\/\.\.\//g, '/');
      if (normalizedPath === before) {
        break;
      }
    }

    const sandboxBase = this.context.filesDir.replace(/\\/g, '/');
    
    if (!normalizedPath.startsWith(sandboxBase)) {
      return false;
    }

    if (normalizedPath.includes('..')) {
      return false;
    }

    return true;
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
