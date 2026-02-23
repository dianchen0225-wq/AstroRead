/**
 * Copyright (c) 2025 AstroRead Project
 * 页面状态管理器
 * 管理页面生命周期状态，避免重复加载
 */
// import { Logger } from '../performance/Logger';

export interface PageState {
  isInitialized: boolean;
  lastActiveTime: number;
  dataVersion: number;
  isActive: boolean;
}
export interface PageLifecycleCallbacks {
  onFirstLoad: () => Promise<void>;
  onRefresh?: () => Promise<void>;
  onActivate?: () => void;
  onDeactivate?: () => void;
  onDataChanged?: (version: number) => void;
}

export interface PageStats {
  totalPages: number;
  activePages: number;
  initializedPages: number;
}

export class PageStateManager {
  private static instance: PageStateManager | null = null;
  
  private pageStates: Map<string, PageState> = new Map();
  private callbacks: Map<string, PageLifecycleCallbacks> = new Map();
  private dataVersions: Map<string, number> = new Map();
  
  private constructor() {}
  
  static getInstance(): PageStateManager {
    if (PageStateManager.instance === null) {
      PageStateManager.instance = new PageStateManager();
    }
    return PageStateManager.instance;
  }
  
  static destroyInstance(): void {
    if (PageStateManager.instance !== null) {
      PageStateManager.instance.clearAll();
      PageStateManager.instance = null;
    }
  }
  
  /**
   * 注册页面
   */
  registerPage(pageId: string, callbacks: PageLifecycleCallbacks): void {
    if (!this.pageStates.has(pageId)) {
      const initialState: PageState = {
        isInitialized: false,
        lastActiveTime: 0,
        dataVersion: 0,
        isActive: false
      };
      this.pageStates.set(pageId, initialState);
      // Logger.debug('PageStateManager', `页面已注册: ${pageId}`);
    }
    
    this.callbacks.set(pageId, callbacks);
  }
  
  /**
   * 注销页面
   */
  unregisterPage(pageId: string): void {
    this.pageStates.delete(pageId);
    this.callbacks.delete(pageId);
    // Logger.debug('PageStateManager', `页面已注销: ${pageId}`);
  }
  
  /**
   * 页面显示时调用
   * 智能判断是否需要重新加载数据
   */
  async onPageAppear(pageId: string): Promise<void> {
    const state = this.pageStates.get(pageId);
    const callbacks = this.callbacks.get(pageId);
    
    if (!state || !callbacks) {
      // Logger.warn('PageStateManager', `页面未注册: ${pageId}`);
      return;
    }
    
    state.isActive = true;
    state.lastActiveTime = Date.now();
    
    if (!state.isInitialized) {
      // Logger.info('PageStateManager', `页面首次加载: ${pageId}`);
      await callbacks.onFirstLoad();
      state.isInitialized = true;
      state.dataVersion = this.dataVersions.get(pageId) || 0;
    } else {
      const currentDataVersion = this.dataVersions.get(pageId) || 0;
      const needsRefresh = currentDataVersion > state.dataVersion;
      
      if (needsRefresh && callbacks.onRefresh) {
        // Logger.info('PageStateManager', `页面数据已更新，刷新: ${pageId}`);
        await callbacks.onRefresh();
        state.dataVersion = currentDataVersion;
      } else if (callbacks.onActivate) {
        // Logger.debug('PageStateManager', `页面激活: ${pageId}`);
        callbacks.onActivate();
      }
    }
  }
  
  /**
   * 页面隐藏时调用
   */
  onPageDisappear(pageId: string): void {
    const state = this.pageStates.get(pageId);
    const callbacks = this.callbacks.get(pageId);
    
    if (state) {
      state.isActive = false;
    }
    
    if (callbacks && callbacks.onDeactivate) {
      callbacks.onDeactivate();
    }
    // Logger.debug('PageStateManager', `页面隐藏: ${pageId}`);
  }
  
  /**
   * 通知数据变更
   */
  notifyDataChanged(pageId: string, version?: number): void {
    const newVersion = version ?? ((this.dataVersions.get(pageId) || 0) + 1);
    this.dataVersions.set(pageId, newVersion);
    
    const state = this.pageStates.get(pageId);
    const callbacks = this.callbacks.get(pageId);
    
    if (state && callbacks && callbacks.onDataChanged && state.isActive) {
      callbacks.onDataChanged(newVersion);
    }
    // Logger.info('PageStateManager', `数据变更通知: ${pageId}, 版本: ${newVersion}`);
  }
  
  /**
   * 强制刷新页面
   */
  async forceRefresh(pageId: string): Promise<void> {
    const callbacks = this.callbacks.get(pageId);
    
    if (callbacks) {
      if (callbacks.onRefresh) {
        await callbacks.onRefresh();
      } else {
        await callbacks.onFirstLoad();
      }
      
      const state = this.pageStates.get(pageId);
      if (state) {
        state.dataVersion = this.dataVersions.get(pageId) || 0;
      }
    }
  }
  
  /**
   * 检查页面是否已初始化
   */
  isPageInitialized(pageId: string): boolean {
    const state = this.pageStates.get(pageId);
    return state?.isInitialized ?? false;
  }
  
  /**
   * 检查页面是否活跃
   */
  isPageActive(pageId: string): boolean {
    const state = this.pageStates.get(pageId);
    return state?.isActive ?? false;
  }
  
  /**
   * 获取页面状态
   */
  getPageState(pageId: string): PageState | null {
    return this.pageStates.get(pageId) || null;
  }
  
  /**
   * 重置页面状态（用于强制重新加载）
   */
  resetPageState(pageId: string): void {
    const state = this.pageStates.get(pageId);
    if (state) {
      state.isInitialized = false;
      state.dataVersion = 0;
      // Logger.info('PageStateManager', `页面状态已重置: ${pageId}`);
    }
  }
  
  /**
   * 清除所有状态
   */
  clearAll(): void {
    this.pageStates.clear();
    this.callbacks.clear();
    this.dataVersions.clear();
    // Logger.info('PageStateManager', '所有页面状态已清除');
  }
  /**
   * 获取统计信息
   */
  getStats(): PageStats {
    let activePages = 0;
    let initializedPages = 0;
    
    this.pageStates.forEach(state => {
      if (state.isActive) activePages++;
      if (state.isInitialized) initializedPages++;
    });
    
    return {
      totalPages: this.pageStates.size,
      activePages: activePages,
      initializedPages: initializedPages
    };
  }
}
export interface PageIdsType {
  BOOKSHELF: string;
  HOME: string;
  SEARCH: string;
  SOURCE: string;
  BOOK_DETAIL: string;
  READ: string;
  SETTINGS: string;
  LOCAL_BOOK: string;
  IMPORT: string;
}

export const pageStateManager = PageStateManager.getInstance();
export const PageIds: PageIdsType = {
  BOOKSHELF: 'page:bookshelf',
  HOME: 'page:home',
  SEARCH: 'page:search',
  SOURCE: 'page:source',
  BOOK_DETAIL: 'page:book_detail',
  READ: 'page:read',
  SETTINGS: 'page:settings',
  LOCAL_BOOK: 'page:local_book',
  IMPORT: 'page:import'
};
