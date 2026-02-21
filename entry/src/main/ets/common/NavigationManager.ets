import { Logger } from '../utils/Logger';

export interface NavigationItem {
  pageName: string;
  params?: ESObject;
  timestamp: number;
}

export interface NavigationOptions {
  animated?: boolean;
  replace?: boolean;
  clearStack?: boolean;
}
export type NavigationChangeListener = (pageName: string, action: 'push' | 'pop' | 'replace', params?: ESObject) => void;

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
  private notifyListeners(pageName: string, action: 'push' | 'pop' | 'replace', params?: ESObject): void {
    const listenersCopy: NavigationChangeListener[] = this.navigationChangeListeners.slice();
    listenersCopy.forEach(listener => {
      try {
        listener(pageName, action, params);
      } catch (error) {
        Logger.error(NavigationManager.TAG, `通知导航监听器失败: ${error}`);
      }
    });
  }

  navigateTo(pageName: string, params?: ESObject, options?: NavigationOptions): void {
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

  navigateBack(params?: ESObject): boolean {
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

  initializeStack(pageName: string, params?: ESObject): void {
    this.navigationStack = [{
      pageName,
      params,
      timestamp: Date.now()
    }];
    Logger.info(NavigationManager.TAG, `初始化导航栈: ${pageName}`);
  }
  updateCurrentParams(params: ESObject): void {
    const current = this.getCurrentPage();
    if (current) {
      current.params = this.mergeParams(current.params, params);
    }
  }

  private mergeParams(baseParams?: ESObject, newParams?: ESObject): ESObject {
    const result: ESObject = {};

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
