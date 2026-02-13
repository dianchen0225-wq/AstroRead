import { BookSource, SearchRule, FindRule, ChapterRule, ContentRule } from '../models/BookSource';
import { BookSourceViewModel } from '../viewmodel/BookSourceViewModel';
import { IdGenerator } from '../utils/IdGenerator';
import { NetworkManager } from '../utils/NetworkManager';

/**
 * 书源原始数据类型
 */
interface RawBookSource {
  id?: string;
  name?: string;
  url?: string;
  baseUrl?: string;
  enabled?: boolean;
  header?: string;
  headers?: string;
  searchUrl?: string;
  search?: string;
  searchRule?: {
    bookList?: string;
    list?: string;
    name?: string;
    author?: string;
    cover?: string;
    intro?: string;
    bookUrl?: string;
    url?: string;
    nextUrl?: string;
  };
  findRule?: {
    url?: string;
    bookList?: string;
    list?: string;
    name?: string;
    author?: string;
    cover?: string;
    intro?: string;
    bookUrl?: string;
    url?: string;
  };
  chapterRule?: {
    chapterList?: string;
    list?: string;
    chapterName?: string;
    name?: string;
    chapterUrl?: string;
    url?: string;
    nextUrl?: string;
  };
  contentRule?: {
    content?: string;
    nextUrl?: string;
    prevUrl?: string;
    replaceRule?: string;
  };
  ruleType?: string;
  sort?: number;
  lastUpdateTime?: number;
  addTime?: number;
}

/**
 * 书源管理页面
 * 使用 ViewModel 进行书源管理
 */
@Component
export struct BookSourcePage {
  private bookSourceViewModel: BookSourceViewModel = new BookSourceViewModel();
  
  @State bookSources: BookSource[] = [];
  @State isLoading: boolean = true;
  @State showImportDialog: boolean = false;
  @State importUrl: string = '';
  @State importError: string = '';

  aboutToAppear(): void {
    this.loadBookSources();
  }

  /**
   * 加载书源列表 - 使用 ViewModel
   */
  async loadBookSources(): Promise<void> {
    this.isLoading = true;
    try {
      this.bookSources = await this.bookSourceViewModel.loadEnabledBookSources();
    } catch (error) {
      console.error('Failed to load book sources:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 切换书源启用状态 - 使用 ViewModel
   */
  async toggleBookSource(bookSource: BookSource): Promise<void> {
    try {
      await this.bookSourceViewModel.toggleBookSource(bookSource.id, !bookSource.enabled);
      await this.loadBookSources();
    } catch (error) {
      console.error('Failed to toggle book source:', error);
    }
  }

  build() {
    Stack() {
      Column() {
        // 标题栏
        Row() {
          Text('书源管理')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          
          Button('导入')
            .type(ButtonType.Normal)
            .onClick(() => {
              this.showImportDialog = true;
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .justifyContent(FlexAlign.SpaceBetween)
        .backgroundColor('#FFFFFF')

        // 书源列表
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.bookSources.length === 0) {
          Column() {
            Text('暂无书源')
              .fontSize(16)
              .fontColor('#999999')
            Text('点击导入按钮添加书源')
              .margin({ top: 8 })
              .fontSize(14)
              .fontColor('#CCCCCC')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.bookSources, (source: BookSource) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(source.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#333333')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')

                    Text(source.url)
                      .margin({ top: 4 })
                      .fontSize(12)
                      .fontColor('#999999')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Toggle({ type: ToggleType.Switch, isOn: source.enabled })
                    .selectedColor('#007AFF')
                    .onChange(() => {
                      this.toggleBookSource(source);
                    })
                }
                .width('100%')
                .padding(16)
              }
            }, (source: BookSource) => source.id)
          }
          .width('100%')
          .height('100%')
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')

      // 导入对话框
      if (this.showImportDialog) {
        Stack() {
          // 背景遮罩
          Text('')
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => {
              this.showImportDialog = false;
            })

          // 对话框内容
          Column() {
            Text('导入书源')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 16 })

            TextInput({
              placeholder: '请输入书源URL或粘贴书源JSON',
              text: this.importUrl
            })
              .width('100%')
              .height(120)
              .borderRadius(8)
              .backgroundColor('#FFFFFF')
              .padding(12)
              .margin({ bottom: 16 })

            if (this.importError) {
              Text(this.importError)
                .fontSize(14)
                .fontColor('#FF3B30')
                .margin({ bottom: 16 })
            }

            Row() {
              Button('取消')
                .width('48%')
                .height(40)
                .margin({ right: '4%' })
                .onClick(() => {
                  this.showImportDialog = false;
                  this.importUrl = '';
                  this.importError = '';
                })

              Button('导入')
                .width('48%')
                .height(40)
                .onClick(() => {
                  this.performImport();
                })
            }
          }
          .width('80%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
      }
    }
  }

  /**
   * 执行书源导入
   */
  async performImport(): Promise<void> {
    if (!this.importUrl.trim()) {
      this.importError = '请输入书源URL或JSON';
      return;
    }

    try {
      let bookSources: BookSource[] = [];
      const input = this.importUrl.trim();

      // 检测输入类型
      if (input.startsWith('http://') || input.startsWith('https://')) {
        // 从URL获取书源
        const networkManager = NetworkManager.getInstance();
        const jsonString = await networkManager.get(input);
        const data = JSON.parse(jsonString);

        // 处理书源数据格式
        if (Array.isArray(data)) {
          // 多个书源
          bookSources = data.map((source: RawBookSource) => this.normalizeBookSource(source));
        } else if (data.bookSource !== undefined || data.sources !== undefined) {
          // 包含书源数组的对象
          const sources: RawBookSource[] = data.bookSource !== undefined ? data.bookSource : data.sources;
          bookSources = sources.map((source: RawBookSource) => this.normalizeBookSource(source));
        } else {
          // 单个书源
          bookSources = [this.normalizeBookSource(data)];
        }
      } else {
        // 直接解析JSON字符串
        const data = JSON.parse(input);

        // 处理书源数据格式
        if (Array.isArray(data)) {
          // 多个书源
          bookSources = data.map((source: RawBookSource) => this.normalizeBookSource(source));
        } else if (data.bookSource !== undefined || data.sources !== undefined) {
          // 包含书源数组的对象
          const sources: RawBookSource[] = data.bookSource !== undefined ? data.bookSource : data.sources;
          bookSources = sources.map((source: RawBookSource) => this.normalizeBookSource(source));
        } else {
          // 单个书源
          bookSources = [this.normalizeBookSource(data)];
        }
      }

      // 导入所有书源
      for (const source of bookSources) {
        await this.bookSourceViewModel.upsertBookSource(source);
      }

      await this.loadBookSources();

      this.showImportDialog = false;
      this.importUrl = '';
      this.importError = '';
    } catch (error) {
      console.error('Failed to import book source:', error);
      this.importError = '导入失败，请检查书源格式或网络连接';
    }
  }

  /**
   * 规范化书源数据格式
   */
  private normalizeBookSource(source: RawBookSource): BookSource {
    return {
      id: source.id !== undefined ? source.id : IdGenerator.generateUUID(),
      name: source.name !== undefined ? source.name : '未知书源',
      url: source.url !== undefined ? source.url : (source.baseUrl !== undefined ? source.baseUrl : ''),
      enabled: source.enabled !== false,
      header: source.header !== undefined ? source.header : (source.headers !== undefined ? source.headers : undefined),
      searchUrl: source.searchUrl !== undefined ? source.searchUrl : (source.search !== undefined ? source.search : ''),
      searchRule: {
        bookList: this.getSearchRuleBookList(source),
        name: this.getSearchRuleName(source),
        author: this.getSearchRuleAuthor(source),
        cover: this.getSearchRuleCover(source),
        intro: this.getSearchRuleIntro(source),
        bookUrl: this.getSearchRuleBookUrl(source),
        nextUrl: this.getSearchRuleNextUrl(source)
      },
      findRule: this.buildFindRule(source),
      chapterRule: {
        chapterList: this.getChapterRuleChapterList(source),
        chapterName: this.getChapterRuleChapterName(source),
        chapterUrl: this.getChapterRuleChapterUrl(source),
        nextUrl: this.getChapterRuleNextUrl(source)
      },
      contentRule: {
        content: this.getContentRuleContent(source),
        nextUrl: this.getContentRuleNextUrl(source),
        prevUrl: this.getContentRulePrevUrl(source),
        replaceRule: this.getContentRuleReplaceRule(source)
      },
      ruleType: source.ruleType !== undefined ? source.ruleType : 'xpath',
      sort: source.sort !== undefined ? source.sort : 0,
      lastUpdateTime: source.lastUpdateTime !== undefined ? source.lastUpdateTime : Date.now(),
      addTime: source.addTime !== undefined ? source.addTime : Date.now()
    };
  }

  private getSearchRuleBookList(source: RawBookSource): string {
    if (source.searchRule !== undefined) {
      if (source.searchRule.bookList !== undefined) {
        return source.searchRule.bookList;
      }
      if (source.searchRule.list !== undefined) {
        return source.searchRule.list;
      }
    }
    return '';
  }

  private getSearchRuleName(source: RawBookSource): string {
    if (source.searchRule !== undefined && source.searchRule.name !== undefined) {
      return source.searchRule.name;
    }
    return '';
  }

  private getSearchRuleAuthor(source: RawBookSource): string {
    if (source.searchRule !== undefined && source.searchRule.author !== undefined) {
      return source.searchRule.author;
    }
    return '';
  }

  private getSearchRuleCover(source: RawBookSource): string | undefined {
    if (source.searchRule !== undefined) {
      return source.searchRule.cover;
    }
    return undefined;
  }

  private getSearchRuleIntro(source: RawBookSource): string | undefined {
    if (source.searchRule !== undefined) {
      return source.searchRule.intro;
    }
    return undefined;
  }

  private getSearchRuleBookUrl(source: RawBookSource): string {
    if (source.searchRule !== undefined) {
      if (source.searchRule.bookUrl !== undefined) {
        return source.searchRule.bookUrl;
      }
      if (source.searchRule.url !== undefined) {
        return source.searchRule.url;
      }
    }
    return '';
  }

  private getSearchRuleNextUrl(source: RawBookSource): string | undefined {
    if (source.searchRule !== undefined) {
      return source.searchRule.nextUrl;
    }
    return undefined;
  }

  private buildFindRule(source: RawBookSource): FindRule | undefined {
    if (source.findRule === undefined) {
      return undefined;
    }
    return {
      url: source.findRule.url !== undefined ? source.findRule.url : '',
      bookList: this.getFindRuleBookList(source),
      name: this.getFindRuleName(source),
      author: this.getFindRuleAuthor(source),
      cover: this.getFindRuleCover(source),
      intro: this.getFindRuleIntro(source),
      bookUrl: this.getFindRuleBookUrl(source)
    };
  }

  private getFindRuleBookList(source: RawBookSource): string {
    if (source.findRule !== undefined) {
      if (source.findRule.bookList !== undefined) {
        return source.findRule.bookList;
      }
      if (source.findRule.list !== undefined) {
        return source.findRule.list;
      }
    }
    return '';
  }

  private getFindRuleName(source: RawBookSource): string {
    if (source.findRule !== undefined && source.findRule.name !== undefined) {
      return source.findRule.name;
    }
    return '';
  }

  private getFindRuleAuthor(source: RawBookSource): string {
    if (source.findRule !== undefined && source.findRule.author !== undefined) {
      return source.findRule.author;
    }
    return '';
  }

  private getFindRuleCover(source: RawBookSource): string | undefined {
    if (source.findRule !== undefined) {
      return source.findRule.cover;
    }
    return undefined;
  }

  private getFindRuleIntro(source: RawBookSource): string | undefined {
    if (source.findRule !== undefined) {
      return source.findRule.intro;
    }
    return undefined;
  }

  private getFindRuleBookUrl(source: RawBookSource): string {
    if (source.findRule !== undefined) {
      if (source.findRule.bookUrl !== undefined) {
        return source.findRule.bookUrl;
      }
      if (source.findRule.url !== undefined) {
        return source.findRule.url;
      }
    }
    return '';
  }

  private getChapterRuleChapterList(source: RawBookSource): string {
    if (source.chapterRule !== undefined) {
      if (source.chapterRule.chapterList !== undefined) {
        return source.chapterRule.chapterList;
      }
      if (source.chapterRule.list !== undefined) {
        return source.chapterRule.list;
      }
    }
    return '';
  }

  private getChapterRuleChapterName(source: RawBookSource): string {
    if (source.chapterRule !== undefined) {
      if (source.chapterRule.chapterName !== undefined) {
        return source.chapterRule.chapterName;
      }
      if (source.chapterRule.name !== undefined) {
        return source.chapterRule.name;
      }
    }
    return '';
  }

  private getChapterRuleChapterUrl(source: RawBookSource): string {
    if (source.chapterRule !== undefined) {
      if (source.chapterRule.chapterUrl !== undefined) {
        return source.chapterRule.chapterUrl;
      }
      if (source.chapterRule.url !== undefined) {
        return source.chapterRule.url;
      }
    }
    return '';
  }

  private getChapterRuleNextUrl(source: RawBookSource): string | undefined {
    if (source.chapterRule !== undefined) {
      return source.chapterRule.nextUrl;
    }
    return undefined;
  }

  private getContentRuleContent(source: RawBookSource): string {
    if (source.contentRule !== undefined && source.contentRule.content !== undefined) {
      return source.contentRule.content;
    }
    return '';
  }

  private getContentRuleNextUrl(source: RawBookSource): string | undefined {
    if (source.contentRule !== undefined) {
      return source.contentRule.nextUrl;
    }
    return undefined;
  }

  private getContentRulePrevUrl(source: RawBookSource): string | undefined {
    if (source.contentRule !== undefined) {
      return source.contentRule.prevUrl;
    }
    return undefined;
  }

  private getContentRuleReplaceRule(source: RawBookSource): string | undefined {
    if (source.contentRule !== undefined) {
      return source.contentRule.replaceRule;
    }
    return undefined;
  }
}
