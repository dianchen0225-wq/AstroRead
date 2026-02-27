import { Logger } from '../performance/Logger';
import { NetworkAdapter } from '../network/NetworkAdapter';
import { HTMLParser } from '../parser/HTMLParser';
import { CssSelectorParser } from '../parser/CssSelectorParser';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

export interface StrResponse {
  body: string;
  headers: Record<string, string>;
  code: number;
  url: string;
}

export interface JavaBridgeContext {
  baseUrl?: string;
  result?: string;
  key?: string;
  page?: number;
}

export type ScriptValue = string | number | boolean | object | null | undefined;

export class JavaBridge {
  private static instance: JavaBridge | null = null;
  private readonly TAG = 'JavaBridge';
  private htmlParser: HTMLParser;
  private networkAdapter: NetworkAdapter;
  private currentContent: string = '';
  private currentBaseUrl: string = '';
  private cookieStore: Map<string, Map<string, string>> = new Map();

  private constructor() {
    this.htmlParser = HTMLParser.getInstance();
    this.networkAdapter = NetworkAdapter.getInstance();
  }

  static getInstance(): JavaBridge {
    if (!JavaBridge.instance) {
      JavaBridge.instance = new JavaBridge();
    }
    return JavaBridge.instance;
  }

  setContext(context: JavaBridgeContext): void {
    if (context.baseUrl) {
      this.currentBaseUrl = context.baseUrl;
    }
    if (context.result) {
      this.currentContent = context.result;
    }
  }

  resetContext(): void {
    this.currentContent = '';
    this.currentBaseUrl = '';
  }

  async ajax(urlStr: string): Promise<string> {
    try {
      Logger.debug(this.TAG, `ajax: ${urlStr}`);
      return await this.networkAdapter.get(urlStr);
    } catch (error) {
      Logger.error(this.TAG, `ajax failed: ${error}`);
      return '';
    }
  }
  async ajaxAll(urlList: string[]): Promise<StrResponse[]> {
    const results: StrResponse[] = [];
    const promises: Promise<void>[] = [];

    for (let i = 0; i < urlList.length; i++) {
      const url = urlList[i];
      promises.push(
        this.networkAdapter.get(url).then((body: string) => {
          results.push({
            body: body,
            headers: {},
            code: 200,
            url: url
          });
        }).catch(() => {
          results.push({
            body: '',
            headers: {},
            code: 0,
            url: url
          });
        })
      );
    }

    await Promise.all(promises);
    return results;
  }

  async connect(urlStr: string): Promise<StrResponse> {
    try {
      const body = await this.networkAdapter.get(urlStr);
      return {
        body: body,
        headers: {},
        code: 200,
        url: urlStr
      };
    } catch (error) {
      return {
        body: '',
        headers: {},
        code: 0,
        url: urlStr
      };
    }
  }

  async downloadFile(content: string, url: string): Promise<string> {
    Logger.debug(this.TAG, `downloadFile: ${url}`);
    return url;
  }

  async get(url: string, headers?: Record<string, string>): Promise<string> {
    try {
      Logger.debug(this.TAG, `java.get: ${url}`);
      return await this.networkAdapter.get(url, headers || {});
    } catch (error) {
      Logger.error(this.TAG, `get failed: ${error}`);
      return '';
    }
  }

  async post(urlStr: string, body: string, headers?: Record<string, string>): Promise<string> {
    try {
      Logger.debug(this.TAG, `java.post: ${urlStr}`);
      return await this.networkAdapter.post(urlStr, body, headers || {});
    } catch (error) {
      Logger.error(this.TAG, `post failed: ${error}`);
      return '';
    }
  }

  getCookie(tag: string, key?: string): string {
    const cookies = this.cookieStore.get(tag);
    if (!cookies) return '';
    if (key) {
      return cookies.get(key) || '';
    }
    const parts: string[] = [];
    cookies.forEach((value: string, k: string) => {
      parts.push(`${k}=${value}`);
    });
    return parts.join('; ');
  }

  setCookie(tag: string, key: string, value: string): void {
    let cookies = this.cookieStore.get(tag);
    if (!cookies) {
      cookies = new Map();
      this.cookieStore.set(tag, cookies);
    }
    cookies.set(key, value);
  }

  base64Decode(str: string, flags: number = 0): string {
    try {
      const base64 = new util.Base64Helper();
      const uint8Array = base64.decodeSync(str);
      const decoder = new util.TextDecoder('utf-8');
      return decoder.decodeToString(uint8Array);
    } catch (error) {
      Logger.error(this.TAG, `base64Decode failed: ${error}`);
      return str;
    }
  }

  base64DecodeToByteArray(str: string | null, flags: number = 0): number[] {
    if (!str) return [];
    try {
      const base64 = new util.Base64Helper();
      const uint8Array = base64.decodeSync(str);
      return Array.from(uint8Array);
    } catch (error) {
      return [];
    }
  }

  base64Encode(str: string, flags: number = 0): string {
    try {
      const encoder = new util.TextEncoder();
      const uint8Array = encoder.encodeInto(str);
      const base64 = new util.Base64Helper();
      return base64.encodeToStringSync(uint8Array);
    } catch (error) {
      Logger.error(this.TAG, `base64Encode failed: ${error}`);
      return str;
    }
  }

  async md5Encode(str: string): Promise<string> {
    try {
      const md = cryptoFramework.createMd('MD5');
      const encoder = new util.TextEncoder();
      const data = encoder.encodeInto(str);
      const dataBlob: cryptoFramework.DataBlob = { data: data };
      await md.update(dataBlob);
      const result = await md.digest();
      return this.arrayBufferToHex(result.data);
    } catch (error) {
      Logger.error(this.TAG, `md5Encode failed: ${error}`);
      return '';
    }
  }

  async md5Encode16(str: string): Promise<string> {
    const full = await this.md5Encode(str);
    return full.substring(8, 24);
  }

  private arrayBufferToHex(buffer: ArrayBuffer): string {
    const uint8Array = new Uint8Array(buffer);
    let hex = '';
    for (let i = 0; i < uint8Array.length; i++) {
      const byte = uint8Array[i];
      hex += (byte < 16 ? '0' : '') + byte.toString(16);
    }
    return hex;
  }

  timeFormat(timestamp: number | string): string {
    let date: Date;
    if (typeof timestamp === 'string') {
      if (/^\d+$/.test(timestamp)) {
        date = new Date(parseInt(timestamp));
      } else {
        date = new Date(timestamp);
      }
    } else {
      date = new Date(timestamp);
    }

    if (isNaN(date.getTime())) {
      return '';
    }

    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hour = String(date.getHours()).padStart(2, '0');
    const minute = String(date.getMinutes()).padStart(2, '0');
    const second = String(date.getSeconds()).padStart(2, '0');

    return `${year}-${month}-${day} ${hour}:${minute}:${second}`;
  }

  utf8ToGbk(str: string): string {
    Logger.warn(this.TAG, 'utf8ToGbk: HarmonyOS does not support GBK encoding natively, returning original string');
    return str;
  }

  encodeURI(str: string, enc: string = 'UTF-8'): string {
    try {
      return encodeURIComponent(str);
    } catch {
      return str;
    }
  }

  htmlFormat(str: string): string {
    if (!str) return '';
    return str
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n')
      .replace(/<\/div>/gi, '\n')
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/\n\s*\n/g, '\n\n')
      .trim();
  }

  getFile(path: string): string {
    Logger.warn(this.TAG, `getFile not supported in HarmonyOS sandbox: ${path}`);
    return '';
  }

  readFile(path: string): string {
    Logger.warn(this.TAG, `readFile not supported in HarmonyOS sandbox: ${path}`);
    return '';
  }

  readTxtFile(path: string, charsetName: string = 'UTF-8'): string {
    Logger.warn(this.TAG, `readTxtFile not supported in HarmonyOS sandbox: ${path}`);
    return '';
  }

  deleteFile(path: string): boolean {
    Logger.warn(this.TAG, `deleteFile not supported in HarmonyOS sandbox: ${path}`);
    return false;
  }

  unzipFile(zipPath: string): string {
    Logger.warn(this.TAG, `unzipFile not supported: ${zipPath}`);
    return '';
  }

  getTxtInFolder(unzipPath: string): string {
    Logger.warn(this.TAG, `getTxtInFolder not supported: ${unzipPath}`);
    return '';
  }

  getZipStringContent(url: string, path: string): string {
    Logger.warn(this.TAG, `getZipStringContent not supported: ${url}`);
    return '';
  }

  getZipByteArrayContent(url: string, path: string): number[] {
    Logger.warn(this.TAG, `getZipByteArrayContent not supported: ${url}`);
    return [];
  }

  queryBase64TTF(base64: string | null): object | null {
    Logger.warn(this.TAG, 'queryBase64TTF not supported');
    return null;
  }

  queryTTF(str: string | null): object | null {
    Logger.warn(this.TAG, 'queryTTF not supported');
    return null;
  }

  replaceFont(text: string, font1: object | null, font2: object | null): string {
    return text;
  }

  log(msg: string): void {
    Logger.info(this.TAG, `[JS] ${msg}`);
  }

  async aesDecodeToByteArray(str: string, key: string, transformation: string, iv: string): Promise<number[]> {
    try {
      const decoded = await this.aesDecodeToString(str, key, transformation, iv);
      const encoder = new util.TextEncoder();
      return Array.from(encoder.encodeInto(decoded));
    } catch (error) {
      Logger.error(this.TAG, `aesDecodeToByteArray failed: ${error}`);
      return [];
    }
  }

  async aesDecodeToString(str: string, key: string, transformation: string, iv: string): Promise<string> {
    try {
      const cipher = cryptoFramework.createCipher(transformation);
      const keyData = new Uint8Array(this.hexToBytes(key));
      const keyBlob: cryptoFramework.DataBlob = { data: keyData };
      const symKey = await cryptoFramework.createSymKeyGenerator('AES128').convertKey(keyBlob);
      
      const ivData = new Uint8Array(this.hexToBytes(iv));
      const ivBlob: cryptoFramework.DataBlob = { data: ivData };
      const ivParamsSpec: cryptoFramework.IvParamsSpec = {
        algName: 'IvParamsSpec',
        iv: ivBlob
      };
      
      await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, ivParamsSpec);
      
      const inputData = new Uint8Array(this.base64DecodeToByteArray(str));
      const inputBlob: cryptoFramework.DataBlob = { data: inputData };
      
      const result = await cipher.doFinal(inputBlob);
      const decoder = new util.TextDecoder('utf-8');
      return decoder.decodeToString(result.data);
    } catch (error) {
      Logger.error(this.TAG, `aesDecodeToString failed: ${error}`);
      return '';
    }
  }

  async aesBase64DecodeToByteArray(str: string, key: string, transformation: string, iv: string): Promise<number[]> {
    return this.aesDecodeToByteArray(str, key, transformation, iv);
  }

  async aesBase64DecodeToString(str: string, key: string, transformation: string, iv: string): Promise<string> {
    return this.aesDecodeToString(str, key, transformation, iv);
  }

  async aesEncodeToByteArray(data: string, key: string, transformation: string, iv: string): Promise<number[]> {
    try {
      const encoded = await this.aesEncodeToString(data, key, transformation, iv);
      const encoder = new util.TextEncoder();
      return Array.from(encoder.encodeInto(encoded));
    } catch (error) {
      Logger.error(this.TAG, `aesEncodeToByteArray failed: ${error}`);
      return [];
    }
  }

  async aesEncodeToString(data: string, key: string, transformation: string, iv: string): Promise<string> {
    try {
      const cipher = cryptoFramework.createCipher(transformation);
      const keyData = new Uint8Array(this.hexToBytes(key));
      const keyBlob: cryptoFramework.DataBlob = { data: keyData };
      const symKey = await cryptoFramework.createSymKeyGenerator('AES128').convertKey(keyBlob);
      
      const ivData = new Uint8Array(this.hexToBytes(iv));
      const ivBlob: cryptoFramework.DataBlob = { data: ivData };
      const ivParamsSpec: cryptoFramework.IvParamsSpec = {
        algName: 'IvParamsSpec',
        iv: ivBlob
      };
      
      await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, ivParamsSpec);
      const encoder = new util.TextEncoder();
      const inputData = encoder.encodeInto(data);
      const inputBlob: cryptoFramework.DataBlob = { data: inputData };
      
      const result = await cipher.doFinal(inputBlob);
      const base64 = new util.Base64Helper();
      return base64.encodeToStringSync(result.data);
    } catch (error) {
      Logger.error(this.TAG, `aesEncodeToString failed: ${error}`);
      return '';
    }
  }

  async aesEncodeToBase64ByteArray(data: string, key: string, transformation: string, iv: string): Promise<number[]> {
    return this.aesEncodeToByteArray(data, key, transformation, iv);
  }

  async aesEncodeToBase64String(data: string, key: string, transformation: string, iv: string): Promise<string> {
    return this.aesEncodeToString(data, key, transformation, iv);
  }

  private hexToBytes(hex: string): number[] {
    const bytes: number[] = [];
    for (let i = 0; i < hex.length; i += 2) {
      bytes.push(parseInt(hex.substr(i, 2), 16));
    }
    return bytes;
  }

  setContent(content: string | number | boolean | object | null | undefined, baseUrl?: string): void {
    if (typeof content === 'string') {
      this.currentContent = content;
    } else if (content !== null && content !== undefined) {
      this.currentContent = JSON.stringify(content);
    } else {
      this.currentContent = '';
    }
    if (baseUrl) {
      this.currentBaseUrl = baseUrl;
    }
  }

  getStringList(rule: string, isUrl: boolean = false): string[] {
    if (!this.currentContent || !rule) {
      return [];
    }

    try {
      const results = this.htmlParser.parse(this.currentContent, rule);
      
      if (isUrl) {
        return results.map((r: string) => this.resolveUrl(r));
      }
      
      return results;
    } catch (error) {
      Logger.error(this.TAG, `getStringList failed: ${error}`);
      return [];
    }
  }

  getString(ruleStr: string | null, isUrl: boolean = false): string {
    if (!this.currentContent) {
      return '';
    }

    if (!ruleStr) {
      return this.currentContent;
    }

    try {
      const results = this.htmlParser.parse(this.currentContent, ruleStr);
      const result = results.length > 0 ? results[0] : '';
      
      if (isUrl && result) {
        return this.resolveUrl(result);
      }
      
      return result;
    } catch (error) {
      Logger.error(this.TAG, `getString failed: ${error}`);
      return '';
    }
  }

  getElements(ruleStr: string): string[] {
    if (!this.currentContent || !ruleStr) {
      return [];
    }

    try {
      return CssSelectorParser.selectElements(this.currentContent, ruleStr);
    } catch (error) {
      Logger.error(this.TAG, `getElements failed: ${error}`);
      return [];
    }
  }

  private resolveUrl(relativeUrl: string): string {
    if (!relativeUrl) return '';
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }

    if (!this.currentBaseUrl) return relativeUrl;

    try {
      const protocolEnd = this.currentBaseUrl.indexOf('://');
      if (protocolEnd === -1) return relativeUrl;

      const protocol = this.currentBaseUrl.substring(0, protocolEnd + 3);
      const hostStart = protocolEnd + 3;
      const pathStart = this.currentBaseUrl.indexOf('/', hostStart);
      const host = pathStart === -1 
        ? this.currentBaseUrl.substring(hostStart) 
        : this.currentBaseUrl.substring(hostStart, pathStart);

      if (relativeUrl.startsWith('/')) {
        return `${protocol}${host}${relativeUrl}`;
      }

      const path = pathStart === -1 ? '/' : this.currentBaseUrl.substring(pathStart);
      const lastSlash = path.lastIndexOf('/');
      const basePath = lastSlash === -1 ? '/' : path.substring(0, lastSlash + 1);

      return `${protocol}${host}${basePath}${relativeUrl}`;
    } catch {
      return relativeUrl;
    }
  }
  getMethodMap(): Map<string, (args: ScriptValue[]) => ScriptValue | Promise<ScriptValue>> {
    const bridge = this;
    const methodMap = new Map<string, (args: ScriptValue[]) => ScriptValue | Promise<ScriptValue>>();

    methodMap.set('ajax', (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.ajax(String(args[0] ?? ''));
    });

    methodMap.set('ajaxAll', async (args: ScriptValue[]): Promise<ScriptValue> => {
      const urlList = args[0];
      if (!Array.isArray(urlList)) return [];
      return bridge.ajaxAll(urlList as string[]);
    });

    methodMap.set('connect', (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.connect(String(args[0] ?? ''));
    });

    methodMap.set('downloadFile', async (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.downloadFile(String(args[0] ?? ''), String(args[1] ?? ''));
    });

    methodMap.set('get', (args: ScriptValue[]): Promise<ScriptValue> => {
      const url = String(args[0] ?? '');
      const headers = args[1] !== undefined && args[1] !== null && typeof args[1] === 'object' ? args[1] as Record<string, string> : undefined;
      return bridge.get(url, headers);
    });

    methodMap.set('post', (args: ScriptValue[]): Promise<ScriptValue> => {
      const url = String(args[0] ?? '');
      const body = String(args[1] ?? '');
      const headers = args[2] !== undefined && args[2] !== null && typeof args[2] === 'object' ? args[2] as Record<string, string> : undefined;
      return bridge.post(url, body, headers);
    });

    methodMap.set('getCookie', (args: ScriptValue[]): ScriptValue => {
      const tag = String(args[0] ?? '');
      const key = args[1] !== undefined && args[1] !== null ? String(args[1]) : undefined;
      return bridge.getCookie(tag, key);
    });

    methodMap.set('base64Decode', (args: ScriptValue[]): ScriptValue => {
      const str = String(args[0] ?? '');
      const flags = args[1] !== undefined && args[1] !== null ? Number(args[1]) : 0;
      return bridge.base64Decode(str, flags);
    });

    methodMap.set('base64DecodeToByteArray', (args: ScriptValue[]): ScriptValue => {
      const str = args[0] !== undefined && args[0] !== null ? String(args[0]) : null;
      const flags = args[1] !== undefined && args[1] !== null ? Number(args[1]) : 0;
      return bridge.base64DecodeToByteArray(str, flags);
    });

    methodMap.set('base64Encode', (args: ScriptValue[]): ScriptValue => {
      const str = String(args[0] ?? '');
      const flags = args[1] !== undefined && args[1] !== null ? Number(args[1]) : 0;
      return bridge.base64Encode(str, flags);
    });

    methodMap.set('md5Encode', (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.md5Encode(String(args[0] ?? ''));
    });

    methodMap.set('md5Encode16', (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.md5Encode16(String(args[0] ?? ''));
    });

    methodMap.set('timeFormat', (args: ScriptValue[]): ScriptValue => {
      const input = args[0];
      if (typeof input === 'number') {
        return bridge.timeFormat(input);
      }
      return bridge.timeFormat(String(input ?? ''));
    });

    methodMap.set('utf8ToGbk', (args: ScriptValue[]): ScriptValue => {
      return bridge.utf8ToGbk(String(args[0] ?? ''));
    });

    methodMap.set('encodeURI', (args: ScriptValue[]): ScriptValue => {
      const str = String(args[0] ?? '');
      const enc = args[1] !== undefined && args[1] !== null ? String(args[1]) : 'UTF-8';
      return bridge.encodeURI(str, enc);
    });

    methodMap.set('htmlFormat', (args: ScriptValue[]): ScriptValue => {
      return bridge.htmlFormat(String(args[0] ?? ''));
    });

    methodMap.set('getFile', (args: ScriptValue[]): ScriptValue => {
      return bridge.getFile(String(args[0] ?? ''));
    });

    methodMap.set('readFile', (args: ScriptValue[]): ScriptValue => {
      return bridge.readFile(String(args[0] ?? ''));
    });

    methodMap.set('readTxtFile', (args: ScriptValue[]): ScriptValue => {
      const path = String(args[0] ?? '');
      const charset = args[1] !== undefined && args[1] !== null ? String(args[1]) : 'UTF-8';
      return bridge.readTxtFile(path, charset);
    });

    methodMap.set('deleteFile', (args: ScriptValue[]): ScriptValue => {
      return bridge.deleteFile(String(args[0] ?? ''));
    });

    methodMap.set('unzipFile', (args: ScriptValue[]): ScriptValue => {
      return bridge.unzipFile(String(args[0] ?? ''));
    });

    methodMap.set('getTxtInFolder', (args: ScriptValue[]): ScriptValue => {
      return bridge.getTxtInFolder(String(args[0] ?? ''));
    });

    methodMap.set('getZipStringContent', (args: ScriptValue[]): ScriptValue => {
      return bridge.getZipStringContent(String(args[0] ?? ''), String(args[1] ?? ''));
    });

    methodMap.set('getZipByteArrayContent', (args: ScriptValue[]): ScriptValue => {
      return bridge.getZipByteArrayContent(String(args[0] ?? ''), String(args[1] ?? ''));
    });

    methodMap.set('queryBase64TTF', (args: ScriptValue[]): ScriptValue => {
      return bridge.queryBase64TTF(args[0] !== undefined && args[0] !== null ? String(args[0]) : null);
    });

    methodMap.set('queryTTF', (args: ScriptValue[]): ScriptValue => {
      return bridge.queryTTF(args[0] !== undefined && args[0] !== null ? String(args[0]) : null);
    });

    methodMap.set('replaceFont', (args: ScriptValue[]): ScriptValue => {
      return bridge.replaceFont(
        String(args[0] ?? ''),
        args[1] !== undefined && args[1] !== null ? args[1] as object : null,
        args[2] !== undefined && args[2] !== null ? args[2] as object : null
      );
    });

    methodMap.set('log', (args: ScriptValue[]): ScriptValue => {
      bridge.log(String(args[0] ?? ''));
      return undefined;
    });

    methodMap.set('aesDecodeToByteArray', (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.aesDecodeToByteArray(
        String(args[0] ?? ''),
        String(args[1] ?? ''),
        String(args[2] ?? 'AES/CBC/PKCS5Padding'),
        String(args[3] ?? '')
      );
    });

    methodMap.set('aesDecodeToString', (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.aesDecodeToString(
        String(args[0] ?? ''),
        String(args[1] ?? ''),
        String(args[2] ?? 'AES/CBC/PKCS5Padding'),
        String(args[3] ?? '')
      );
    });

    methodMap.set('aesBase64DecodeToByteArray', (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.aesBase64DecodeToByteArray(
        String(args[0] ?? ''),
        String(args[1] ?? ''),
        String(args[2] ?? 'AES/CBC/PKCS5Padding'),
        String(args[3] ?? '')
      );
    });

    methodMap.set('aesBase64DecodeToString', (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.aesBase64DecodeToString(
        String(args[0] ?? ''),
        String(args[1] ?? ''),
        String(args[2] ?? 'AES/CBC/PKCS5Padding'),
        String(args[3] ?? '')
      );
    });

    methodMap.set('aesEncodeToByteArray', (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.aesEncodeToByteArray(
        String(args[0] ?? ''),
        String(args[1] ?? ''),
        String(args[2] ?? 'AES/CBC/PKCS5Padding'),
        String(args[3] ?? '')
      );
    });

    methodMap.set('aesEncodeToString', (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.aesEncodeToString(
        String(args[0] ?? ''),
        String(args[1] ?? ''),
        String(args[2] ?? 'AES/CBC/PKCS5Padding'),
        String(args[3] ?? '')
      );
    });

    methodMap.set('aesEncodeToBase64ByteArray', (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.aesEncodeToBase64ByteArray(
        String(args[0] ?? ''),
        String(args[1] ?? ''),
        String(args[2] ?? 'AES/CBC/PKCS5Padding'),
        String(args[3] ?? '')
      );
    });

    methodMap.set('aesEncodeToBase64String', (args: ScriptValue[]): Promise<ScriptValue> => {
      return bridge.aesEncodeToBase64String(
        String(args[0] ?? ''),
        String(args[1] ?? ''),
        String(args[2] ?? 'AES/CBC/PKCS5Padding'),
        String(args[3] ?? '')
      );
    });

    methodMap.set('setContent', (args: ScriptValue[]): ScriptValue => {
      bridge.setContent(args[0], args[1] !== undefined && args[1] !== null ? String(args[1]) : undefined);
      return undefined;
    });

    methodMap.set('getStringList', (args: ScriptValue[]): ScriptValue => {
      const rule = String(args[0] ?? '');
      const isUrl = args[1] !== undefined && args[1] !== null && Boolean(args[1]);
      return bridge.getStringList(rule, isUrl);
    });

    methodMap.set('getString', (args: ScriptValue[]): ScriptValue => {
      const rule = args[0] !== undefined && args[0] !== null ? String(args[0]) : null;
      const isUrl = args[1] !== undefined && args[1] !== null && Boolean(args[1]);
      return bridge.getString(rule, isUrl);
    });

    methodMap.set('getElements', (args: ScriptValue[]): ScriptValue => {
      return bridge.getElements(String(args[0] ?? ''));
    });

    return methodMap;
  }
}

export default JavaBridge.getInstance();
