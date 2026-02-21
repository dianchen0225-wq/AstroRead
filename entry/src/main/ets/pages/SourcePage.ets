/**
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { themeManager } from '../common/ThemeManager';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { ImportResult, DeleteResult } from '../viewmodel/BookSourceViewModel';
import { BookSource } from '../models/BookSource';
import { SecurityScanResult, SecurityRisk, SecurityRiskLevel } from '../utils/SourceSandbox';
import { BusinessError } from '@kit.BasicServicesKit';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { DesignSystem } from '../common/DesignSystem';
import { Logger } from '../utils/Logger';
import { NetworkManager } from '../utils/NetworkManager';
import { SourceImportTaskPool } from '../utils/SourceImportTaskPool';
import { showToast } from '../utils/ToastUtils';

export interface SourceItemData {
  name: string;
  status: string;
  enabled: boolean;
  id: string;
  isValidating: boolean;
}

export interface DeleteConfirmState {
  show: boolean;
  count: number;
  isDeleting: boolean;
}

@ComponentV2
export struct SourcePage {
  @Local isLightMode: boolean = true;
  @Local sourceList: SourceItemData[] = [];
  @Local allSourceList: SourceItemData[] = [];
  @Local searchKeyword: string = '';
  @Local isSearching: boolean = false;
  @Local searchResultCount: number = 0;
  @Local showImportDialog: boolean = false;
  @Local importUrl: string = '';
  @Local isImporting: boolean = false;
  @Local importProgress: number = 0;
  @Local importProgressMessage: string = '';
  @Local isUpdating: boolean = false;
  @Local updateProgress: string = '';
  @Local showSecurityWarning: boolean = false;
  @Local securityScanResult: SecurityScanResult | null = null;
  @Local pendingImportContent: string = '';
  @Local pendingImportFormat: string = '';
  @Local riskConfirmCount: number = 0;
  @Local totalCount: number = 0;
  @Local currentPage: number = 1;
  @Local isLoadingMore: boolean = false;
  @Local hasMore: boolean = true;
  @Local showDeleteConfirm: boolean = false;
  @Local disabledSourceCount: number = 0;
  @Local isDeletingDisabled: boolean = false;
  @Local selectedIds: string[] = [];
  @Local showBatchActions: boolean = false;
  
  private readonly PAGE_SIZE: number = 50;
  private isComponentActive: boolean = false;
  private decoder = util.TextDecoder.create('utf-8');
  private searchDebounceTimer: number = 0;
  private readonly SEARCH_DEBOUNCE_DELAY: number = 300;
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isComponentActive = true;
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
    this.loadSources();
  }

  aboutToDisappear(): void {
    this.isComponentActive = false;
    themeManager.removeListener(this.themeListener);
    this.sourceList = [];
    this.allSourceList = [];
    this.securityScanResult = null;
    this.pendingImportContent = '';
    if (this.searchDebounceTimer !== 0) {
      clearTimeout(this.searchDebounceTimer);
      this.searchDebounceTimer = 0;
    }
  }

  async loadSources() {
    if (!this.isComponentActive) return;

    try {
      this.currentPage = 1;
      this.hasMore = true;
      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      const result = await bookSourceViewModel.loadBookSourcesPaged(this.currentPage, this.PAGE_SIZE);
      
      this.totalCount = result.total;
      this.sourceList = result.sources
        .filter((source: BookSource) => source.id && source.id.trim() !== '')
        .map((source: BookSource) => {
          const item: SourceItemData = {
            name: source.name,
            status: source.enabled ? '正常' : '已禁用',
            enabled: source.enabled,
            id: source.id,
            isValidating: false
          };
          return item;
        });
      
      this.allSourceList = this.sourceList.slice();
      this.disabledSourceCount = this.allSourceList.filter((s: SourceItemData) => !s.enabled).length;
      this.searchResultCount = this.sourceList.length;
      
      this.hasMore = this.sourceList.length < this.totalCount;
      Logger.info('SourcePage', `加载了 ${this.sourceList.length} 个书源，共 ${this.totalCount} 个，禁用 ${this.disabledSourceCount} 个`);
    } catch (error) {
      Logger.error('SourcePage', `加载书源失败: ${error}`);
    }
  }

  async loadMoreSources() {
    if (!this.isComponentActive || this.isLoadingMore || !this.hasMore) return;

    try {
      this.isLoadingMore = true;
      this.currentPage++;

      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      const result = await bookSourceViewModel.loadBookSourcesPaged(this.currentPage, this.PAGE_SIZE);

      const newItems: SourceItemData[] = result.sources
        .filter((source: BookSource) => source.id && source.id.trim() !== '')
        .map((source: BookSource) => {
          const item: SourceItemData = {
            name: source.name,
            status: source.enabled ? '正常' : '已禁用',
            enabled: source.enabled,
            id: source.id,
            isValidating: false
          };
          return item;
        });

      for (let i: number = 0; i < newItems.length; i++) {
        this.sourceList.push(newItems[i]);
      }
      this.hasMore = this.sourceList.length < this.totalCount;
      Logger.info('SourcePage', `加载更多 ${newItems.length} 个书源`);
    } catch (error) {
      Logger.error('SourcePage', `加载更多书源失败: ${error}`);
      this.currentPage--;
    } finally {
      this.isLoadingMore = false;
    }
  }

  async toggleSource(id: string) {
    const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
    const source: BookSource | null = await bookSourceViewModel.getBookSourceById(id);
    if (source) {
      const enabled: boolean = !source.enabled;
      await bookSourceViewModel.toggleBookSource(id, enabled);
      await this.loadSources();
    }
  }
  
  onSearchKeywordChange(keyword: string): void {
    this.searchKeyword = keyword;
    
    if (this.searchDebounceTimer !== 0) {
      clearTimeout(this.searchDebounceTimer);
      this.searchDebounceTimer = 0;
    }
    
    this.searchDebounceTimer = setTimeout(() => {
      this.performSearch(keyword);
    }, this.SEARCH_DEBOUNCE_DELAY);
  }
  
  performSearch(keyword: string): void {
    if (!this.isComponentActive) return;
    
    this.isSearching = true;
    
    if (!keyword || keyword.trim().length === 0) {
      this.sourceList = this.allSourceList.slice();
      this.searchResultCount = this.sourceList.length;
      this.isSearching = false;
      return;
    }
    
    const lowerKeyword = keyword.toLowerCase().trim();
    const filtered = this.allSourceList.filter((item: SourceItemData) => {
      return item.name.toLowerCase().includes(lowerKeyword) ||
             item.status.toLowerCase().includes(lowerKeyword);
    });
    
    this.sourceList = filtered;
    this.searchResultCount = filtered.length;
    this.isSearching = false;
    
    Logger.info('SourcePage', `搜索 "${keyword}" 找到 ${filtered.length} 个结果`);
  }
  
  clearSearch(): void {
    this.searchKeyword = '';
    this.sourceList = this.allSourceList.slice();
    this.searchResultCount = this.sourceList.length;
  }
  
  async countDisabledSources(): Promise<number> {
    let count = 0;
    for (const item of this.allSourceList) {
      if (!item.enabled) {
        count++;
      }
    }
    return count;
  }
  
  showDeleteDisabledConfirm(): void {
    this.disabledSourceCount = this.allSourceList.filter((s: SourceItemData) => !s.enabled).length;
    if (this.disabledSourceCount === 0) {
      showToast({
        message: '没有禁用的书源',
        duration: 2000
      });
      return;
    }
    this.showDeleteConfirm = true;
  }

  async deleteDisabledSources(): Promise<void> {
    if (this.isDeletingDisabled) return;

    this.isDeletingDisabled = true;
    this.showDeleteConfirm = false;

    try {
      const disabledIds: string[] = [];
      for (const item of this.allSourceList) {
        if (!item.enabled && item.id) {
          disabledIds.push(item.id);
        }
      }

      if (disabledIds.length === 0) {
        showToast({
          message: '没有禁用的书源',
          duration: 2000
        });
        return;
      }

      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      const result: DeleteResult = await bookSourceViewModel.batchDeleteBookSources(disabledIds);

      if (result.success) {
        showToast({
          message: `成功删除 ${result.count || disabledIds.length} 个禁用书源`,
          duration: 2000
        });
        await this.loadSources();
      } else {
        showToast({
          message: result.message || '删除失败',
          duration: 2000
        });
      }
    } catch (error) {
      Logger.error('SourcePage', `删除禁用书源失败: ${error}`);
      showToast({
        message: '删除失败',
        duration: 2000
      });
    } finally {
      this.isDeletingDisabled = false;
    }
  }

  showImportDialogUI() {
    this.showImportDialog = true;
    this.importUrl = '';
  }

  async importFromUrl(url: string): Promise<void> {
    if (!url || url.trim().length === 0) {
      Logger.info('SourcePage', '请输入书源URL');
      return;
    }

    const trimmedUrl = url.trim();
    
    if (!this.isValidUrl(trimmedUrl)) {
      Logger.info('SourcePage', '请输入有效的URL地址');
      return;
    }

    this.isImporting = true;
    try {
      Logger.info('SourcePage', `开始从URL导入书源: ${trimmedUrl}`);
      
      const networkManager = NetworkManager.getInstance();
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      networkManager.setContext(context);
      const content = await networkManager.get(trimmedUrl, undefined, 5 * 1024 * 1024);
      
      if (!content || content.trim().length === 0) {
        throw new Error('从URL获取的书源内容为空');
      }
      
      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      const results = await Promise.all([
        SourceImportTaskPool.scanSecurity(content),
        SourceImportTaskPool.detectFormat(content)
      ]);
      const scanResult = results[0];
      const format = results[1];
      
      if (scanResult.riskLevel === 'critical' || scanResult.riskLevel === 'high') {
        this.securityScanResult = scanResult;
        this.pendingImportContent = content;
        this.pendingImportFormat = format;
        this.riskConfirmCount = 0;
        this.showSecurityWarning = true;
        this.isImporting = false;
        return;
      }
      const result: ImportResult = await bookSourceViewModel.importBookSource(content, format, true);
      
      if (result.success) {
        Logger.info('SourcePage', result.message || `成功导入${result.count || 0}个书源`);
        await this.loadSources();
        this.showImportDialog = false;
      } else {
        if (result.message && result.message.includes('安全风险')) {
          const scanResult = await SourceImportTaskPool.scanSecurity(content);
          this.securityScanResult = scanResult;
          this.pendingImportContent = content;
          this.pendingImportFormat = await SourceImportTaskPool.detectFormat(content);
          this.riskConfirmCount = 0;
          this.showSecurityWarning = true;
        } else {
          Logger.error('SourcePage', result.message || '导入失败');
        }
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : '未知错误';
      Logger.error('SourcePage', `导入失败: ${errorMessage}`);
    } finally {
      this.isImporting = false;
    }
  }

  async confirmImportWithRisk(): Promise<void> {
    if (this.riskConfirmCount < 1) {
      this.riskConfirmCount++;
      Logger.info('SourcePage', '请再次点击确认导入（安全风险）');
      return;
    }
    
    this.showSecurityWarning = false;
    this.isImporting = true;
    this.riskConfirmCount = 0;
    
    try {
      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      const result = await bookSourceViewModel.importBookSource(
        this.pendingImportContent,
        this.pendingImportFormat,
        true
      );
      
      if (result.success) {
        Logger.info('SourcePage', result.message || `成功导入${result.count || 0}个书源`);
        await this.loadSources();
        this.showImportDialog = false;
      } else {
        Logger.error('SourcePage', result.message || '导入失败');
      }
    } catch (error) {
      Logger.error('SourcePage', '导入失败: ' + (error instanceof Error ? error.message : '未知错误'));
    } finally {
      this.isImporting = false;
      this.pendingImportContent = '';
      this.pendingImportFormat = '';
      this.securityScanResult = null;
    }
  }

  cancelImportWithRisk() {
    this.showSecurityWarning = false;
    this.riskConfirmCount = 0;
    this.pendingImportContent = '';
    this.pendingImportFormat = '';
    this.securityScanResult = null;
    Logger.info('SourcePage', '已取消导入');
  }

  private isValidUrl(url: string): boolean {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  async addSource(): Promise<void> {
    try {
      const documentPicker = new picker.DocumentViewPicker(this.getUIContext().getHostContext() as common.UIAbilityContext);
      const documentSelectOptions = new picker.DocumentSelectOptions();
      const documentSelectResult = await documentPicker.select(documentSelectOptions);
      if (documentSelectResult) {
        const uri = documentSelectResult[0];
        const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        const arrayBuffer = new ArrayBuffer(1024 * 1024);
        const readLen = fs.readSync(file.fd, arrayBuffer);
        let text = this.decoder.decodeToString(new Uint8Array(arrayBuffer.slice(0, readLen)));
        
        const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
        const results = await Promise.all([
          SourceImportTaskPool.scanSecurity(text),
          SourceImportTaskPool.detectFormat(text)
        ]);
        const scanResult = results[0];
        const format = results[1];
        
        if (scanResult.riskLevel === 'critical' || scanResult.riskLevel === 'high') {
          this.securityScanResult = scanResult;
          this.pendingImportContent = text;
          this.pendingImportFormat = format;
          this.riskConfirmCount = 0;
          this.showSecurityWarning = true;
          return;
        }
        
        this.isImporting = true;
        try {
          const result: ImportResult = await bookSourceViewModel.importBookSource(text, format, true);
          if (result.success) {
            Logger.info('SourcePage', result.message || `成功导入${result.count || 0}个书源`);
            await this.loadSources();
          } else {
            if (result.message && result.message.includes('安全风险')) {
              const scanResult = await SourceImportTaskPool.scanSecurity(text);
              this.securityScanResult = scanResult;
              this.pendingImportContent = text;
              this.pendingImportFormat = await SourceImportTaskPool.detectFormat(text);
              this.riskConfirmCount = 0;
              this.showSecurityWarning = true;
            } else {
              Logger.error('SourcePage', result.message || '导入失败');
            }
          }
        } catch (error) {
          Logger.error('SourcePage', '导入失败: ' + (error instanceof Error ? error.message : '未知错误'));
        } finally {
          this.isImporting = false;
        }
      }
    } catch (e) {
      let error: BusinessError = e as BusinessError;
      Logger.error('SourcePage', `本地导入失败: ${JSON.stringify(error)}`);
    }
  }

  async updateSource(): Promise<void> {
    if (this.sourceList.length === 0) {
      Logger.info('SourcePage', '暂无书源可更新');
      return;
    }

    this.isUpdating = true;
    this.updateProgress = '正在验证书源...';
    
    try {
      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      const sources: BookSource[] = await bookSourceViewModel.loadAllBookSources();
      const totalSources = sources.length;
      
      let validCount = 0;
      let invalidCount = 0;

      for (let i = 0; i < sources.length; i++) {
        if (!this.isComponentActive) break;
        
        const source = sources[i];
        this.updateProgress = `正在验证 (${i + 1}/${totalSources})...`;
        
        try {
          const isValid = await bookSourceViewModel.testBookSource(source);
          
          if (isValid) {
            validCount++;
            source.enabled = true;
          } else {
            invalidCount++;
            source.enabled = false;
          }
          
          await bookSourceViewModel.upsertBookSource(source);
          
          if (i < sources.length - 1) {
            await new Promise<void>((resolve: Function) => setTimeout(resolve, 500));
          }
        } catch (error) {
          Logger.error('SourcePage', `验证书源${source.name}失败: ${error}`);
          invalidCount++;
        }
      }

      await this.loadSources();
      Logger.info('SourcePage', `验证完成: 有效${validCount}个, 失效${invalidCount}个`);
    } catch (error) {
      Logger.error('SourcePage', `更新书源失败: ${error}`);
    } finally {
      this.isUpdating = false;
      this.updateProgress = '';
    }
  }

  async validateSingleSource(id: string) {
    const item = this.sourceList.find((s: SourceItemData) => s.id === id);
    if (!item) {
      Logger.warn('SourcePage', `未找到书源: ${id}`);
      return;
    }

    item.isValidating = true;
    item.status = '验证中...';

    try {
      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      
      await bookSourceViewModel.loadAllBookSources();
      
      const source = await bookSourceViewModel.getBookSourceById(id);
      if (!source) {
        Logger.warn('SourcePage', `ViewModel中未找到书源: ${id}`);
        item.status = '未找到';
        return;
      }

      Logger.info('SourcePage', `开始验证书源: ${source.name}`);
      const isValid = await bookSourceViewModel.testBookSource(source);

      source.enabled = isValid;
      await bookSourceViewModel.upsertBookSource(source);

      item.status = isValid ? '正常' : '失效';
      item.enabled = isValid;

      Logger.info('SourcePage', `书源验证完成: ${source.name}, 状态: ${item.status}`);
    } catch (error) {
      Logger.error('SourcePage', `验证书源失败: ${error}`);
      item.status = '验证失败';
    } finally {
      item.isValidating = false;
    }
  }

  async deleteSource(id: string) {
    try {
      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      const result = await bookSourceViewModel.deleteBookSource(id);
      if (result.success) {
        Logger.info('SourcePage', '删除成功');
        await this.loadSources();
      } else {
        Logger.error('SourcePage', result.message || '删除失败');
      }
    } catch (error) {
      Logger.error('SourcePage', '删除失败');
    }
  }

  /**
   * 选择/取消选择单个书源
   */
  toggleSelectSource(id: string): void {
    const index = this.selectedIds.indexOf(id);
    if (index > -1) {
      this.selectedIds.splice(index, 1);
    } else {
      this.selectedIds.push(id);
    }
    
    // 如果没有选中任何项，则隐藏批量操作栏
    this.showBatchActions = this.selectedIds.length > 0;
  }

  /**
   * 选择所有当前页面的书源
   */
  selectAllCurrentPage(): void {
    for (const item of this.sourceList) {
      if (!this.selectedIds.includes(item.id)) {
        this.selectedIds.push(item.id);
      }
    }
    this.showBatchActions = true;
  }

  /**
   * 取消选择所有书源
   */
  unselectAll(): void {
    this.selectedIds = [];
    this.showBatchActions = false;
  }

  /**
   * 批量删除选中的书源
   */
  async batchDeleteSelected(): Promise<void> {
    if (this.selectedIds.length === 0) {
      showToast({
        message: '请先选择要删除的书源',
        duration: 2000
      });
      return;
    }

    try {
      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      const result = await bookSourceViewModel.batchDeleteBookSources(this.selectedIds);

      if (result.success) {
        showToast({
          message: `成功删除 ${result.count || this.selectedIds.length} 个书源`,
          duration: 2000
        });
        this.unselectAll(); // 清空选择
        await this.loadSources(); // 重新加载
      } else {
        showToast({
          message: result.message || '批量删除失败',
          duration: 2000
        });
      }
    } catch (error) {
      Logger.error('SourcePage', `批量删除失败: ${error}`);
      showToast({
        message: '批量删除失败',
        duration: 2000
      });
    }
  }

  /**
   * 批量启用选中的书源
   */
  async batchEnableSelected(): Promise<void> {
    if (this.selectedIds.length === 0) {
      showToast({
        message: '请先选择要启用的书源',
        duration: 2000
      });
      return;
    }

    try {
      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      const result = await bookSourceViewModel.batchUpdateBookSourcesStatus(this.selectedIds, true);

      if (result.success) {
        showToast({
          message: `成功启用 ${result.count || this.selectedIds.length} 个书源`,
          duration: 2000
        });
        await this.loadSources(); // 重新加载
      } else {
        showToast({
          message: result.message || '批量启用失败',
          duration: 2000
        });
      }
    } catch (error) {
      Logger.error('SourcePage', `批量启用失败: ${error}`);
      showToast({
        message: '批量启用失败',
        duration: 2000
      });
    }
  }

  /**
   * 批量禁用选中的书源
   */
  async batchDisableSelected(): Promise<void> {
    if (this.selectedIds.length === 0) {
      showToast({
        message: '请先选择要禁用的书源',
        duration: 2000
      });
      return;
    }

    try {
      const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
      const result = await bookSourceViewModel.batchUpdateBookSourcesStatus(this.selectedIds, false);

      if (result.success) {
        showToast({
          message: `成功禁用 ${result.count || this.selectedIds.length} 个书源`,
          duration: 2000
        });
        await this.loadSources(); // 重新加载
      } else {
        showToast({
          message: result.message || '批量禁用失败',
          duration: 2000
        });
      }
    } catch (error) {
      Logger.error('SourcePage', `批量禁用失败: ${error}`);
      showToast({
        message: '批量禁用失败',
        duration: 2000
      });
    }
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Row() {
            Text('‹')
              .fontSize(20)
              .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .justifyContent(FlexAlign.Center)
          .margin({ right: 15 })

          Text($r('app.string.source_management'))
            .fontSize(18)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .fontWeight(600)
            .layoutWeight(1)
          
          if (this.totalCount > 0) {
            Text(`(${this.sourceList.length}/${this.totalCount})`)
              .fontSize(14)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .margin({ right: 8 })
          }
        }
        .width('100%')
        .padding({ left: 15, right: 20, top: 15, bottom: 15 })
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .border({
          width: { bottom: 1 },
          color: DesignSystem.getBorderColor(this.isLightMode)
        })

        Column() {
          Row() {
            TextInput({ placeholder: '搜索书源名称...', text: this.searchKeyword })
              .layoutWeight(1)
              .height(40)
              .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
              .borderRadius(12)
              .padding({ left: 12, right: 12 })
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .placeholderColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .onChange((value: string) => {
                this.onSearchKeywordChange(value);
              })
            
            if (this.searchKeyword.length > 0) {
              Button() {
                Text('✕')
                  .fontSize(16)
                  .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              }
              .width(40)
              .height(40)
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .borderRadius(12)
              .margin({ left: 8 })
              .onClick(() => {
                this.clearSearch();
              })
            }
          }
          .width('100%')
          .margin({ bottom: 10 })

          // 批量操作栏
          if (this.showBatchActions) {
            Row() {
              Button('取消')
                .fontSize(14)
                .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
                .margin({ right: 10 })
                .onClick(() => {
                  this.unselectAll();
                })

              Text(`${this.selectedIds.length} 项已选`)
                .fontSize(14)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                .layoutWeight(1)

              Button('全部')
                .fontSize(14)
                .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
                .margin({ right: 10 })
                .onClick(() => {
                  this.selectAllCurrentPage();
                })

              Button('删除')
                .fontSize(14)
                .fontColor('#ffffff')
                .backgroundColor(DesignSystem.getErrorColor(this.isLightMode))
                .borderRadius(8)
                .padding({ left: 12, right: 12 })
                .onClick(() => {
                  this.batchDeleteSelected();
                })
            }
            .width('100%')
            .padding(10)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .borderRadius(12)
            .margin({ bottom: 10 })
          }
          
          if (this.searchKeyword.length > 0) {
            Row() {
              if (this.isSearching) {
                LoadingProgress()
                  .width(14)
                  .height(14)
                  .color(DesignSystem.getPrimaryColor(this.isLightMode))
                  .margin({ right: 6 })
              }
              Text(`找到 ${this.searchResultCount} 个匹配书源`)
                .fontSize(12)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            }
            .width('100%')
            .margin({ bottom: 8 })
          }

          Row() {
            Button() {
              Row() {
                Text('🌐')
                  .fontSize(16)
                  .margin({ right: 8 })
                Text('网络导入')
                  .fontSize(14)
                  .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              }
            }
            .layoutWeight(1)
            .height(40)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .border({
              width: 1,
              color: DesignSystem.getBorderColor(this.isLightMode)
            })
            .borderRadius(12)
            .margin({ right: 10 })
            .enabled(!this.isImporting && !this.isUpdating)
            .onClick(() => {
              this.showImportDialogUI();
            })

            Button() {
              Row() {
                Text('📁')
                  .fontSize(16)
                  .margin({ right: 8 })
                Text('本地导入')
                  .fontSize(14)
                  .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              }
            }
            .layoutWeight(1)
            .height(40)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .border({
              width: 1,
              color: DesignSystem.getBorderColor(this.isLightMode)
            })
            .borderRadius(12)
            .margin({ right: 10 })
            .enabled(!this.isImporting && !this.isUpdating)
            .onClick(() => {
              this.addSource();
            })

            Button() {
              Row() {
                if (this.isUpdating) {
                  LoadingProgress()
                    .width(16)
                    .height(16)
                    .color(DesignSystem.getPrimaryTextColor(this.isLightMode))
                    .margin({ right: 8 })
                } else {
                  Text('↻')
                    .fontSize(16)
                    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                    .margin({ right: 8 })
                }
                Text(this.isUpdating ? '验证中' : '验证书源')
                  .fontSize(14)
                  .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              }
            }
            .layoutWeight(1)
            .height(40)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .border({
              width: 1,
              color: DesignSystem.getBorderColor(this.isLightMode)
            })
            .borderRadius(12)
            .enabled(!this.isImporting && !this.isUpdating)
            .onClick(() => {
              this.updateSource();
            })
          }
          .width('100%')
          .margin({ bottom: 10 })
          
          if (this.disabledSourceCount > 0) {
            Row() {
              Text(`禁用书源: ${this.disabledSourceCount} 个`)
                .fontSize(12)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                .layoutWeight(1)
              
              Button() {
                Row() {
                  if (this.isDeletingDisabled) {
                    LoadingProgress()
                      .width(14)
                      .height(14)
                      .color('#fff')
                      .margin({ right: 4 })
                  }
                  Text(this.isDeletingDisabled ? '删除中...' : '删除禁用书源')
                    .fontSize(12)
                    .fontColor('#fff')
                }
              }
              .height(32)
              .backgroundColor('#f44336')
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
              .enabled(!this.isDeletingDisabled && !this.isImporting && !this.isUpdating)
              .onClick(() => {
                this.showDeleteDisabledConfirm();
              })
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
            .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .margin({ bottom: 10 })
          }

          if (this.isUpdating && this.updateProgress) {
            Row() {
              LoadingProgress()
                .width(16)
                .height(16)
                .color(DesignSystem.getPrimaryColor(this.isLightMode))
                .margin({ right: 8 })
              Text(this.updateProgress)
                .fontSize(12)
                .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
          }

          Scroll() {
            Column() {
              if (this.sourceList.length === 0) {
                Column() {
                  Text('📚')
                    .fontSize(48)
                    .margin({ bottom: 16 })
                  Text('暂无书源')
                    .fontSize(16)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                    .margin({ bottom: 8 })
                  Text('点击"网络导入"按钮添加书源')
                    .fontSize(14)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                    .margin({ bottom: 16 })
                  Button('网络导入书源')
                    .fontSize(14)
                    .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                    .fontColor('#fff')
                    .borderRadius(8)
                    .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                    .onClick(() => {
                      this.showImportDialogUI();
                    })
                }
                .width('100%')
                .height(200)
                .justifyContent(FlexAlign.Center)
              } else {
                ForEach(this.sourceList, (item: SourceItemData) => {
                  Row() {
                    Checkbox({ name: item.id, group: 'sourceSelection' })
                      .select(this.selectedIds.includes(item.id))
                      .onChange((value: boolean) => {
                        this.toggleSelectSource(item.id);
                      })
                      .margin({ right: 10 })

                    Column() {
                      Text(item.name)
                        .fontSize(14)
                        .fontWeight(500)
                        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                        .margin({ bottom: 4 })
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })

                      Row() {
                        Text(item.status)
                          .fontSize(12)
                          .fontColor(this.getStatusColor(item.status))
                          .fontWeight(500)

                        if (item.isValidating) {
                          LoadingProgress()
                            .width(12)
                            .height(12)
                            .color(DesignSystem.getPrimaryColor(this.isLightMode))
                            .margin({ left: 8 })
                        }
                      }
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Row() {
                      Button('验证')
                        .fontSize(12)
                        .height(28)
                        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                        .borderRadius(6)
                        .margin({ right: 8 })
                        .enabled(!item.isValidating)
                        .onClick(() => {
                          this.validateSingleSource(item.id);
                        })

                      Toggle({ type: ToggleType.Switch, isOn: item.enabled })
                        .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
                        .onChange((isOn: boolean) => {
                          item.enabled = isOn;
                          this.toggleSource(item.id);
                        })
                    }
                  }
                  .width('100%')
                  .padding(15)
                  .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                  .borderRadius(12)
                  .border({
                    width: 1,
                    color: DesignSystem.getBorderColor(this.isLightMode)
                  })
                  .margin({ bottom: 8 })
                })
                
                if (this.hasMore && this.sourceList.length > 0) {
                  Row() {
                    if (this.isLoadingMore) {
                      LoadingProgress()
                        .width(20)
                        .height(20)
                        .color(DesignSystem.getPrimaryColor(this.isLightMode))
                        .margin({ right: 8 })
                      Text('加载中...')
                        .fontSize(14)
                        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                    } else {
                      Button('加载更多')
                        .fontSize(14)
                        .height(36)
                        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                        .borderRadius(8)
                        .border({
                          width: 1,
                          color: DesignSystem.getBorderColor(this.isLightMode)
                        })
                        .onClick(() => {
                          this.loadMoreSources();
                        })
                    }
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  .padding({ top: 16, bottom: 16 })
                }
                
                if (!this.showBatchActions && this.sourceList.length > 0) {
                  Row() {
                    Button('网络导入书源')
                      .layoutWeight(1)
                      .height(44)
                      .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                      .fontColor('#fff')
                      .borderRadius(12)
                      .margin({ right: 8 })
                      .onClick(() => {
                        this.showImportDialogUI();
                      })
                      
                    if (this.disabledSourceCount > 0) {
                      Button('删除禁用')
                        .layoutWeight(1)
                        .height(44)
                        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                        .borderRadius(12)
                        .onClick(() => {
                          this.deleteDisabledSources();
                        })
                    }
                  }
                  .width('100%')
                  .margin({ top: 16 })
                }
              }
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .scrollable(ScrollDirection.Vertical)
          .edgeEffect(EdgeEffect.Spring)
          .onScrollFrameBegin((offset: number, _state: ScrollState) => {
            return { offsetRemain: offset };
          })
        }
        .width('100%')
        .padding(20)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))

      if (this.showImportDialog) {
        Column() {
          Column() {
            Text('导入书源')
              .fontSize(18)
              .fontWeight(600)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 12 })

            Text('支持阅读APP格式的JSON书源')
              .fontSize(12)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 16 })

            TextInput({ placeholder: '请输入书源URL', text: this.importUrl })
              .width('100%')
              .height(44)
              .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .placeholderColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .enabled(!this.isImporting)
              .onChange((value: string) => {
                this.importUrl = value;
              })

            Text('示例: https://example.com/sources.json')
              .fontSize(11)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .width('100%')
              .margin({ top: 8, bottom: 16 })

            Row() {
              Button('取消')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .borderRadius(8)
                .margin({ right: 10 })
                .enabled(!this.isImporting)
                .onClick(() => {
                  this.showImportDialog = false;
                })

              Button(this.isImporting ? '导入中...' : '导入')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                .fontColor('#fff')
                .borderRadius(8)
                .enabled(!this.isImporting && this.importUrl.trim().length > 0)
                .onClick(() => {
                  this.importFromUrl(this.importUrl);
                })
            }
            .width('100%')
          }
          .width('90%')
          .constraintSize({ maxWidth: 400 })
          .padding(24)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (!this.isImporting) {
            this.showImportDialog = false;
          }
        })
      }

      if (this.showSecurityWarning && this.securityScanResult) {
        Column() {
          Column() {
            Row() {
              Text('⚠️')
                .fontSize(24)
              Text('安全警告')
                .fontSize(18)
                .fontWeight(600)
                .fontColor('#FF6B00')
                .margin({ left: 8 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ bottom: 16 })

            Text(this.securityScanResult.summary)
              .fontSize(14)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 16 })

            Scroll() {
              Column() {
                ForEach(this.securityScanResult.risks.slice(0, 5), (risk: SecurityRisk) => {
                  Row() {
                    Text(this.getRiskLevelEmoji(risk.level))
                      .fontSize(14)
                      .margin({ right: 8 })

                    Column() {
                      Text(risk.type)
                        .fontSize(12)
                        .fontWeight(500)
                        .fontColor(this.getRiskLevelColor(risk.level))

                      Text(risk.description)
                        .fontSize(11)
                        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                        .margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                  .border({
                    width: { bottom: 1 },
                    color: DesignSystem.getBorderColor(this.isLightMode)
                  })
                })
              }
              .width('100%')
            }
            .width('100%')
            .constraintSize({ maxHeight: 200 })
            .margin({ bottom: 16 })

            Text('是否仍要导入此书源？')
              .fontSize(13)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 8 })
            
            if (this.riskConfirmCount === 0) {
              Text('⚠️ 需要点击两次确认按钮才能导入')
                .fontSize(11)
                .fontColor('#FF6B00')
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ bottom: 16 })
            } else {
              Text('⚠️ 请再次点击确认按钮完成导入')
                .fontSize(11)
                .fontColor('#FF0000')
                .fontWeight(500)
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ bottom: 16 })
            }

            Row() {
              Button('取消导入')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .borderRadius(8)
                .margin({ right: 10 })
                .onClick(() => {
                  this.cancelImportWithRisk();
                })

              Button(this.riskConfirmCount === 0 ? '无视风险，继续导入' : '再次点击确认导入')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(this.riskConfirmCount === 0 ? '#FF6B00' : '#FF0000')
                .fontColor('#fff')
                .borderRadius(8)
                .onClick(() => {
                  this.confirmImportWithRisk();
                })
            }
            .width('100%')
          }
          .width('90%')
          .constraintSize({ maxWidth: 400 })
          .padding(24)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .borderRadius(16)
          .border({
            width: 2,
            color: '#FF6B00'
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.6)')
        .justifyContent(FlexAlign.Center)
      }
      
      if (this.showDeleteConfirm) {
        Column() {
          Column() {
            Row() {
              Text('🗑️')
                .fontSize(24)
              Text('确认删除')
                .fontSize(18)
                .fontWeight(600)
                .fontColor('#f44336')
                .margin({ left: 8 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ bottom: 16 })

            Text(`确定要删除 ${this.disabledSourceCount} 个禁用的书源吗？`)
              .fontSize(14)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 8 })

            Text('此操作不可撤销，删除后需要重新导入书源。')
              .fontSize(12)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 20 })

            Row() {
              Button('取消')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .borderRadius(8)
                .margin({ right: 10 })
                .onClick(() => {
                  this.showDeleteConfirm = false;
                })

              Button('确认删除')
                .layoutWeight(1)
                .height(44)
                .backgroundColor('#f44336')
                .fontColor('#fff')
                .borderRadius(8)
                .onClick(() => {
                  this.deleteDisabledSources();
                })
            }
            .width('100%')
          }
          .width('90%')
          .constraintSize({ maxWidth: 400 })
          .padding(24)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .borderRadius(16)
          .border({
            width: 2,
            color: '#f44336'
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showDeleteConfirm = false;
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  private getRiskLevelEmoji(level: SecurityRiskLevel): string {
    switch (level) {
      case 'critical': return '🔴';
      case 'high': return '🟠';
      case 'medium': return '🟡';
      case 'low': return '🟢';
      default: return '⚪';
    }
  }

  private getRiskLevelColor(level: SecurityRiskLevel): string {
    const bookSourceViewModel = viewModelManager.getBookSourceViewModel();
    return bookSourceViewModel.getSecurityRiskLevelColor(level);
  }

  private getStatusColor(status: string): string {
    switch (status) {
      case '正常':
        return '#4caf50';
      case '失效':
      case '验证失败':
        return '#f44336';
      case '已禁用':
        return '#999999';
      case '验证中...':
        return '#ff9800';
      default:
        return '#999999';
    }
  }
}
