/**
 * NavigationManager - 导航管理器
 * 用于管理页面导航和参数传递，替代 deprecated 的 router API
 */

export interface NavParams {
  bookId?: string;
  initialChapterIndex?: number;
  initialChapterUrl?: string;
  tabIndex?: number;
}

interface NavigationItem {
  pageName: string;
  params?: NavParams;
}

export class NavigationManager {
  private static instance: NavigationManager | null = null;
  private navigationStack: NavigationItem[] = [];
  private currentPageIndex: number = 0;
  private pageChangeListener: ((pageName: string, params?: NavParams) => void) | null = null;

  private constructor() {
  }

  static getInstance(): NavigationManager {
    if (NavigationManager.instance === null) {
      NavigationManager.instance = new NavigationManager();
    }
    return NavigationManager.instance;
  }

  setPageChangeListener(listener: (pageName: string, params?: NavParams) => void): void {
    this.pageChangeListener = listener;
  }

  navigateTo(pageName: string, params?: NavParams): void {
    this.navigationStack.push({ pageName, params });
    if (this.pageChangeListener) {
      this.pageChangeListener(pageName, params);
    }
  }

  navigateBack(): void {
    if (this.navigationStack.length > 1) {
      this.navigationStack.pop();
      const prevPage = this.navigationStack[this.navigationStack.length - 1];
      if (this.pageChangeListener) {
        this.pageChangeListener(prevPage.pageName, prevPage.params);
      }
    } else {
      if (this.pageChangeListener) {
        this.pageChangeListener('MainPage', undefined);
      }
    }
  }

  getCurrentPage(): NavigationItem | null {
    if (this.navigationStack.length > 0) {
      return this.navigationStack[this.navigationStack.length - 1];
    }
    return null;
  }

  clearStack(): void {
    this.navigationStack = [];
  }
}

export default NavigationManager.getInstance();
