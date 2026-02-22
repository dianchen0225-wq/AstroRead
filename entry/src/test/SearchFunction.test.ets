  /**
   * 搜索功能测试套件
   * 包含功能测试、边界测试和兼容性测试
   */

  import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
  import { SearchResultBuilder, PagedSearchResult, SearchPaginationConfig, DEFAULT_PAGINATION_CONFIG } from '../main/ets/models/SearchResult';
  import { Book } from '../main/ets/models/Book';

  // 模拟书籍数据生成器
  function createMockBook(overrides: Partial<Book> = {}): Book {
    const book: Book = {
      id: `book_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      name: '测试书籍',
      author: '测试作者',
      cover: 'http://example.com/cover.jpg',
      intro: '这是一本测试书籍的简介',
      kind: '玄幻',
      wordCount: 1000000,
      latestChapter: '第100章 测试章节',
      bookSourceId: 'source_1',
      bookSourceName: '测试书源',
      bookUrl: 'http://example.com/book/1',
      lastUpdateTime: Date.now(),
      addTime: Date.now(),
      readProgress: 0,
      lastReadChapter: undefined,
      lastReadChapterIndex: undefined,
      lastReadTime: 0,
      totalChapters: 100,
      currentChapterIndex: 0,
      currentChapterTitle: '',
      isInShelf: false
    };
    // 手动合并覆盖属性
    if (overrides.id !== undefined) book.id = overrides.id;
    if (overrides.name !== undefined) book.name = overrides.name;
    if (overrides.author !== undefined) book.author = overrides.author;
    if (overrides.cover !== undefined) book.cover = overrides.cover;
    if (overrides.intro !== undefined) book.intro = overrides.intro;
    if (overrides.kind !== undefined) book.kind = overrides.kind;
    if (overrides.wordCount !== undefined) book.wordCount = overrides.wordCount;
    if (overrides.latestChapter !== undefined) book.latestChapter = overrides.latestChapter;
    if (overrides.bookSourceId !== undefined) book.bookSourceId = overrides.bookSourceId;
    if (overrides.bookSourceName !== undefined) book.bookSourceName = overrides.bookSourceName;
    if (overrides.bookUrl !== undefined) book.bookUrl = overrides.bookUrl;
    if (overrides.lastUpdateTime !== undefined) book.lastUpdateTime = overrides.lastUpdateTime;
    if (overrides.addTime !== undefined) book.addTime = overrides.addTime;
    if (overrides.readProgress !== undefined) book.readProgress = overrides.readProgress;
    if (overrides.lastReadChapter !== undefined) book.lastReadChapter = overrides.lastReadChapter;
    if (overrides.lastReadChapterIndex !== undefined) book.lastReadChapterIndex = overrides.lastReadChapterIndex;
    if (overrides.lastReadTime !== undefined) book.lastReadTime = overrides.lastReadTime;
    if (overrides.totalChapters !== undefined) book.totalChapters = overrides.totalChapters;
    if (overrides.currentChapterIndex !== undefined) book.currentChapterIndex = overrides.currentChapterIndex;
    if (overrides.currentChapterTitle !== undefined) book.currentChapterTitle = overrides.currentChapterTitle;
    if (overrides.isInShelf !== undefined) book.isInShelf = overrides.isInShelf;
    return book;
  }

  export default function searchFunctionTest() {
    describe('SearchFunctionTest', () => {

      // ==================== 功能测试 ====================
      describe('功能测试', () => {
        it('should_add_source_result_correctly', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);
          const books: Book[] = [
            createMockBook({ name: '完美世界', author: '辰东' }),
            createMockBook({ name: '遮天', author: '辰东' }),
            createMockBook({ name: '神墓', author: '辰东' })
          ];

          const newBooks = builder.addSourceResult('source_1', '测试书源1', books, true, undefined, 500);

          expect(newBooks.length).assertEqual(3);
          expect(builder.getTotalCount()).assertEqual(3);
        });

        it('should_deduplicate_books_with_same_name_and_author', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);

          // 第一批次
          const books1: Book[] = [
            createMockBook({ name: '完美世界', author: '辰东' }),
            createMockBook({ name: '遮天', author: '辰东' })
          ];
          builder.addSourceResult('source_1', '书源1', books1, true, undefined, 500);

          // 第二批次 - 包含重复书籍
          const books2: Book[] = [
            createMockBook({ name: '完美世界', author: '辰东' }), // 重复
            createMockBook({ name: '圣墟', author: '辰东' })
          ];
          const newBooks = builder.addSourceResult('source_2', '书源2', books2, true, undefined, 600);

          // 只有一本新书
          expect(newBooks.length).assertEqual(1);
          expect(newBooks[0].name).assertEqual('圣墟');
          expect(builder.getTotalCount()).assertEqual(3);
        });

        it('should_handle_empty_book_name', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);
          const books: Book[] = [
            createMockBook({ name: '', author: '作者' }),
            createMockBook({ name: '有效书名', author: '作者' })
          ];

          const newBooks = builder.addSourceResult('source_1', '书源1', books, true, undefined, 500);

          // 空书名的书籍应该被跳过
          expect(newBooks.length).assertEqual(1);
          expect(newBooks[0].name).assertEqual('有效书名');
        });

        it('should_set_default_author_for_empty_author', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);
          const books: Book[] = [
            createMockBook({ name: '测试书', author: '' })
          ];

          builder.addSourceResult('source_1', '书源1', books, true, undefined, 500);
          const result = builder.build(1);

          expect(result.books[0].author).assertEqual('未知作者');
        });

        it('should_build_paged_result_correctly', 0, () => {
          const config: SearchPaginationConfig = {
            pageSize: 2,
            maxResultsPerSource: 10,
            maxTotalResults: 100,
            enableDeduplication: true,
            sortByRelevance: false
          };
          const builder = new SearchResultBuilder(config);

          const books: Book[] = [
            createMockBook({ name: '书1' }),
            createMockBook({ name: '书2' }),
            createMockBook({ name: '书3' }),
            createMockBook({ name: '书4' }),
            createMockBook({ name: '书5' })
          ];

          builder.addSourceResult('source_1', '书源1', books, true, undefined, 500);

          const page1 = builder.build(1);
          expect(page1.books.length).assertEqual(2);
          expect(page1.totalCount).assertEqual(5);
          expect(page1.totalPages).assertEqual(3);
          expect(page1.hasMore).assertTrue();

          const page2 = builder.build(2);
          expect(page2.books.length).assertEqual(2);
          expect(page2.currentPage).assertEqual(2);

          const page3 = builder.build(3);
          expect(page3.books.length).assertEqual(1);
          expect(page3.hasMore).assertFalse();
        });
      });

      // ==================== 边界测试 ====================
      describe('边界测试', () => {
        it('should_handle_empty_search_result', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);
          const result = builder.build(1);

          expect(result.books.length).assertEqual(0);
          expect(result.totalCount).assertEqual(0);
          expect(result.totalPages).assertEqual(1);
          expect(result.hasMore).assertFalse();
        });

        it('should_handle_very_long_book_name', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);
          const longName = 'a'.repeat(500);
          const books: Book[] = [
            createMockBook({ name: longName, author: '作者' })
          ];

          const newBooks = builder.addSourceResult('source_1', '书源1', books, true, undefined, 500);
          expect(newBooks.length).assertEqual(1);
          expect(newBooks[0].name.length).assertEqual(500);
        });

        it('should_handle_special_characters_in_book_name', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);
          const books: Book[] = [
            createMockBook({ name: '《完美世界》', author: '辰东' }),
            createMockBook({ name: '完美世界!', author: '辰东' }),
            createMockBook({ name: '完美世界?', author: '辰东' }),
            createMockBook({ name: '完美世界  ', author: '辰东' }) // 尾部空格
          ];

          // 这些应该被视为重复（标准化后）
          const newBooks1 = builder.addSourceResult('source_1', '书源1', [books[0]], true, undefined, 500);
          const newBooks2 = builder.addSourceResult('source_2', '书源2', [books[1]], true, undefined, 500);
          const newBooks3 = builder.addSourceResult('source_3', '书源3', [books[2]], true, undefined, 500);
          const newBooks4 = builder.addSourceResult('source_4', '书源4', [books[3]], true, undefined, 500);

          expect(newBooks1.length).assertEqual(1);
          expect(newBooks2.length).assertEqual(0); // 重复
          expect(newBooks3.length).assertEqual(0); // 重复
          expect(newBooks4.length).assertEqual(0); // 重复
        });

        it('should_handle_page_number_out_of_range', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);
          const books: Book[] = [createMockBook({ name: '书1' })];

          builder.addSourceResult('source_1', '书源1', books, true, undefined, 500);

          // 请求超出范围的页码
          const result = builder.build(100);
          expect(result.currentPage).assertEqual(1);
          expect(result.books.length).assertEqual(1);
        });

        it('should_handle_unicode_characters', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);
          const books: Book[] = [
            createMockBook({ name: '📖完美世界', author: '辰东' }),
            createMockBook({ name: '完美世界🔥', author: '辰东' }),
            createMockBook({ name: '𝐓𝐞𝐬𝐭', author: '作者' })
          ];

          const newBooks = builder.addSourceResult('source_1', '书源1', books, true, undefined, 500);
          expect(newBooks.length).assertEqual(3);
        });
      });

      // ==================== 相关性排序测试 ====================
      describe('相关性排序测试', () => {
        it('should_sort_by_relevance_correctly', 0, () => {
          const config: SearchPaginationConfig = {
            pageSize: 10,
            maxResultsPerSource: 10,
            maxTotalResults: 100,
            enableDeduplication: true,
            sortByRelevance: true
          };
          const builder = new SearchResultBuilder(config);

          // 创建不同质量的书籍
          const books: Book[] = [
            createMockBook({
              name: '低质量书',
              author: '',
              cover: '',
              intro: '',
              wordCount: 0
            }),
            createMockBook({
              name: '高质量书',
              author: '知名作者',
              cover: 'http://example.com/cover.jpg',
              intro: '这是一本非常精彩的小说，内容丰富，情节跌宕起伏，值得一读。',
              wordCount: 5000000,
              latestChapter: '最新章节',
              kind: '玄幻'
            }),
            createMockBook({
              name: '中等质量书',
              author: '普通作者',
              cover: 'http://example.com/cover2.jpg',
              intro: '简介',
              wordCount: 1000000
            })
          ];

          builder.addSourceResult('source_1', '书源1', books, true, undefined, 500);
          const result = builder.build(1);

          // 高质量书应该排在前面
          expect(result.books[0].name).assertEqual('高质量书');
        });
      });

      // ==================== 性能测试 ====================
      describe('性能测试', () => {
        it('should_handle_large_number_of_books', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);
          const startTime = Date.now();

          // 添加大量书籍
          for (let i = 0; i < 100; i++) {
            const books: Book[] = [
              createMockBook({ name: `书籍${i}`, author: `作者${i % 10}` })
            ];
            builder.addSourceResult(`source_${i}`, `书源${i}`, books, true, undefined, 500);
          }

          const result = builder.build(1);
          const endTime = Date.now();

          expect(result.totalCount).assertEqual(100);
          // 处理100本书应该在1秒内完成
          expect(endTime - startTime).assertLess(1000);
        });

        it('should_handle_many_duplicate_books_efficiently', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);
          const startTime = Date.now();

          // 添加大量重复书籍
          for (let i = 0; i < 100; i++) {
            const books: Book[] = [
              createMockBook({ name: '重复书籍', author: '同一作者' })
            ];
            builder.addSourceResult(`source_${i}`, `书源${i}`, books, true, undefined, 500);
          }

          const result = builder.build(1);
          const endTime = Date.now();

          // 去重后应该只有1本
          expect(result.totalCount).assertEqual(1);
          expect(endTime - startTime).assertLess(500);
        });
      });

      // ==================== 兼容性测试 ====================
      describe('兼容性测试', () => {
        it('should_handle_null_and_undefined_fields', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);
          const books: Book[] = [
            {
              id: 'book_1',
              name: '测试书',
              author: '',
              cover: '',
              intro: '',
              kind: '',
              wordCount: 0,
              latestChapter: '',
              bookSourceId: 'source_1',
              bookSourceName: '书源1',
              bookUrl: 'http://example.com',
              lastUpdateTime: 0,
              addTime: 0,
              readProgress: 0,
              lastReadChapter: undefined,
              lastReadChapterIndex: undefined,
              lastReadTime: 0,
              totalChapters: 0,
              currentChapterIndex: 0,
              currentChapterTitle: '',
              isInShelf: false
            } as Book
          ];

          const newBooks = builder.addSourceResult('source_1', '书源1', books, true, undefined, 500);
          expect(newBooks.length).assertEqual(1);
          expect(newBooks[0].author).assertEqual('未知作者');
        });

        it('should_handle_failed_source_gracefully', 0, () => {
          const builder = new SearchResultBuilder(DEFAULT_PAGINATION_CONFIG);

          // 成功的书源
          const successBooks: Book[] = [createMockBook({ name: '成功书籍' })];
          builder.addSourceResult('source_1', '书源1', successBooks, true, undefined, 500);

          // 失败的书源
          builder.addSourceResult('source_2', '书源2', [], false, '网络错误', 0);

          const result = builder.build(1);
          expect(result.books.length).assertEqual(1);
          expect(result.sourceStats.length).assertEqual(2);
          expect(result.sourceStats[1].success).assertFalse();
          expect(result.sourceStats[1].error).assertEqual('网络错误');
        });
      });
    });
  }
