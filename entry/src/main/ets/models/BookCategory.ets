/**
 * 书籍分类数据模型
 */
export interface BookCategory {
  id: string;                    // 分类ID
  name: string;                  // 分类名称
  sort: number;                  // 排序
  createTime: number;            // 创建时间
}
