/**
 * Repositories Module Index
 * 数据仓库模块统一导出
 */

// 本地数据仓库
export { BookRepository } from './local/BookRepository';
export { BookSourceRepository } from './local/BookSourceRepository';
export { BookmarkRepository } from './local/BookmarkRepository';
export { ChapterRepository } from './local/ChapterRepository';
export { CategoryRepository } from './local/CategoryRepository';
export { ReadConfigRepository } from './local/ReadConfigRepository';

// 远程数据仓库
export { RemoteBookSourceRepository } from './remote/RemoteBookSourceRepository';

// 仓库接口
export { IBookRepository } from './interfaces/IBookRepository';
export { IBookSourceRepository } from './interfaces/IBookSourceRepository';
export { IBookmarkRepository } from './interfaces/IBookmarkRepository';
