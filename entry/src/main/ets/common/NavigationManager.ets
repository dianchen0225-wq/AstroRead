import { Logger } from '../utils/Logger';

export interface BookDetailParams {
  bookId: string;
}

export interface ReadPageParams {
  bookId: string;
  initialChapterIndex: number;
  initialChapterUrl: string;
}

export interface ImportSourceParams {
  sourceId: string;
  sourceName: string;
}

export interface NavigationItem {
  pageName: string;
  params?: NavigationParams;
  timestamp: number;
}

export interface NavigationOptions {
  animated?: boolean;
  replace?: boolean;
  clearStack?: boolean;
}
export type NavigationParams = Record<string, string | number | boolean | Object | null | undefined>;

  export type NavigationChangeListener = (pageName: string, action: 'push' | 'pop' | 'replace', params?: NavigationParams) => void;

export class NavigationManager {
  private static readonly TAG = 'NavigationManager';
  private static instance: NavigationManager | null = null;
  private navigationStack: NavigationItem[] = [];
  private navigationChangeListeners: NavigationChangeListener[] = [];
  private maxStackSize: number = 20;
  private isNavigating: boolean = false;

  private constructor() {
    this.navigationStack = [];
  }

  static getInstance(): NavigationManager {
    if (NavigationManager.instance === null) {
      NavigationManager.instance = new NavigationManager();
    }
    return NavigationManager.instance;
  }

  addNavigationChangeListener(listener: NavigationChangeListener): void {
    if (!this.navigationChangeListeners.includes(listener)) {
      this.navigationChangeListeners.push(listener);
    }
  }

  removeNavigationChangeListener(listener: NavigationChangeListener): void {
    const index = this.navigationChangeListeners.indexOf(listener);
    if (index > -1) {
      this.navigationChangeListeners.splice(index, 1);
    }
  }
  private notifyListeners(pageName: string, action: 'push' | 'pop' | 'replace', params?: NavigationParams): void {
    const listenersCopy: NavigationChangeListener[] = this.navigationChangeListeners.slice();
    listenersCopy.forEach(listener => {
      try {
        listener(pageName, action, params);
      } catch (error) {
        Logger.error(NavigationManager.TAG, `通知导航监听器失败: ${error}`);
      }
    });
  }

  navigateTo(pageName: string, params?: NavigationParams, options?: NavigationOptions): void {
    if (this.isNavigating) {
      Logger.warn(NavigationManager.TAG, '导航进行中，请稍后再试');
      return;
    }

    this.isNavigating = true;

    try {
      if (options?.clearStack) {
        this.navigationStack = [];
      }

      if (options?.replace && this.navigationStack.length > 0) {
        this.navigationStack.pop();
      }

      const navItem: NavigationItem = {
        pageName,
        params,
        timestamp: Date.now()
      };

      this.navigationStack.push(navItem);

      if (this.navigationStack.length > this.maxStackSize) {
        this.navigationStack.shift();
      }

      Logger.info(NavigationManager.TAG, `导航到: ${pageName}, 栈深度: ${this.navigationStack.length}`);
      this.notifyListeners(pageName, options?.replace ? 'replace' : 'push', params);
    } finally {
      this.isNavigating = false;
    }
  }

  private createNavParams(): NavigationParams {
    const params: NavigationParams = {};
    return params;
  }

  private createBookDetailParams(bookId: string): NavigationParams {
    const params: NavigationParams = {};
    params['bookId'] = bookId;
    return params;
  }

  private createReadPageParams(bookId: string, chapterIndex: number, chapterUrl: string): NavigationParams {
    const params: NavigationParams = {};
    params['bookId'] = bookId;
    params['initialChapterIndex'] = chapterIndex;
    params['initialChapterUrl'] = chapterUrl;
    return params;
  }

  navigateToBookDetail(params: BookDetailParams, options?: NavigationOptions): void {
    const navParams = this.createBookDetailParams(params.bookId);
    this.navigateTo('BookDetailPage', navParams, options);
  }

  navigateToReadPage(params: ReadPageParams, options?: NavigationOptions): void {
    const navParams = this.createReadPageParams(params.bookId, params.initialChapterIndex, params.initialChapterUrl);
    this.navigateTo('ReadPage', navParams, options);
  }

  navigateToImportSource(params: ImportSourceParams, options?: NavigationOptions): void {
    const navParams: NavigationParams = {};
    navParams['sourceId'] = params.sourceId;
    navParams['sourceName'] = params.sourceName;
    this.navigateTo('ImportSourcePage', navParams, options);
  }

  navigateToBookSourceRepairPage(options?: NavigationOptions): void {
    const navParams = this.createNavParams();
    this.navigateTo('BookSourceRepairPage', navParams, options);
  }

  navigateBack(params?: NavigationParams): boolean {
    if (this.isNavigating) {
      Logger.warn(NavigationManager.TAG, '导航进行中，请稍后再试');
      return false;
    }

    if (this.navigationStack.length <= 1) {
      Logger.info(NavigationManager.TAG, '已到达导航栈底部');
      return false;
    }

    this.isNavigating = true;

    try {
      this.navigationStack.pop();
      const prevPage = this.navigationStack[this.navigationStack.length - 1];

      if (prevPage) {
        const mergedParams = params ? this.mergeParams(prevPage.params, params) : prevPage.params;
        Logger.info(NavigationManager.TAG, `返回到: ${prevPage.pageName}, 栈深度: ${this.navigationStack.length}`);
        this.notifyListeners(prevPage.pageName, 'pop', mergedParams);
        return true;
      }
      return false;
    } finally {
      this.isNavigating = false;
    }
  }

  navigateToRoot(): void {
    if (this.navigationStack.length <= 1) {
      return;
    }

    const rootPage = this.navigationStack[0];
    this.navigationStack = [rootPage] as NavigationItem[];
    Logger.info(NavigationManager.TAG, `返回根页面: ${rootPage.pageName}`);
    this.notifyListeners(rootPage.pageName, 'pop', rootPage.params);
  }

  getCurrentPage(): NavigationItem | null {
    if (this.navigationStack.length > 0) {
      return this.navigationStack[this.navigationStack.length - 1];
    }
    return null;
  }

  getPreviousPage(): NavigationItem | null {
    if (this.navigationStack.length > 1) {
      return this.navigationStack[this.navigationStack.length - 2];
    }
    return null;
  }

  getStackDepth(): number {
    return this.navigationStack.length;
  }

  canGoBack(): boolean {
    return this.navigationStack.length > 1;
  }

  getNavigationStack(): NavigationItem[] {
    return this.navigationStack.slice();
  }

  clearStack(): void {
    this.navigationStack = [];
    Logger.info(NavigationManager.TAG, '导航栈已清空');
  }

  initializeStack(pageName: string, params?: NavigationParams): void {
    this.navigationStack = [{
      pageName,
      params,
      timestamp: Date.now()
    }];
    Logger.info(NavigationManager.TAG, `初始化导航栈: ${pageName}`);
  }
  updateCurrentParams(params: NavigationParams): void {
    const current = this.getCurrentPage();
    if (current) {
      current.params = this.mergeParams(current.params, params);
    }
  }

  private mergeParams(baseParams?: NavigationParams, newParams?: NavigationParams): NavigationParams {
    const result: NavigationParams = {};

    if (baseParams) {
      Object.keys(baseParams).forEach(key => {
        result[key] = baseParams[key];
      });
    }

    if (newParams) {
      Object.keys(newParams).forEach(key => {
        result[key] = newParams[key];
      });
    }

    return result;
  }
}

export default NavigationManager.getInstance();
