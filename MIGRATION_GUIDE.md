# AstroRead 核心功能迁移指南

本文档帮助你将 AstroRead 的核心功能从 Text 组件迁移到 WebReader 组件，以获得更好的阅读体验。

## 已完成的改进

### 1. HTMLParser - 替代 jsoup 的纯 TypeScript 实现

**文件位置**: `entry/src/main/ets/utils/HTMLParser.ets`

**功能**:
- ✅ CSS Selector 解析 (`.class`, `#id`, `tag`)
- ✅ XPath 解析 (`//div[@class="xxx"]//a/@href`)
- ✅ JSONPath 解析 (`$.books.*`)
- ✅ 正则表达式解析 (`##pattern`)
- ✅ HTML 标签清理
- ✅ URL 拼接处理

**使用方法**:
```typescript
import HTMLParser from '../utils/HTMLParser';

// 解析 HTML
const results = HTMLParser.parse(html, '.book-item');

// XPath
const titles = HTMLParser.parse(html, '//h1[@class="title"]');

// JSONPath
const names = HTMLParser.parse(jsonStr, '$.data.books[*].name');
```

### 2. JSEngine 增强

**文件位置**: `entry/src/main/ets/utils/JSEngine.ets`

**改进**:
- ✅ 集成了 HTMLParser
- ✅ 完善了 `java` 对象的方法
- ✅ 支持 `base64Encode/Decode`, `md5Encode`
- ✅ 支持 `getElements`, `parseHtml`

**可用的书源规则方法**:
```javascript
// 编码/解码
java.encodeURI(str)
java.decodeURI(str)
java.encodeURIComponent(str)
java.decodeURIComponent(str)
java.base64Encode(str)
java.base64Decode(str)
java.md5Encode(str)

// HTML 解析
java.getElements(html, selector)  // 返回数组
java.parseHtml(html)              // 返回对象

// 缓存
java.put(key, value)
java.getCache(key)

// 日志
java.log(msg)
java.longToast(msg)
```

### 3. WebReader - 基于 Web 组件的阅读器

**文件位置**: `entry/src/main/ets/components/WebReader.ets`

**优势**:
- ✅ 支持 CSS 样式和复杂排版
- ✅ 支持图片显示
- ✅ 点击区域划分（左/中/右）
- ✅ 阅读进度追踪
- ✅ 主题切换（亮色/暗色/护眼）
- ✅ 字号、行距、字间距调整

## 迁移步骤

### 步骤 1: 在 ReadPage 中导入 WebReader

```typescript
// 在 ReadPage.ets 顶部添加
import { WebReader, WebReaderConfig } from '../components/WebReader';
```

### 步骤 2: 添加配置状态

```typescript
@Entry
@ComponentV2
struct ReadPage {
  // ... 原有代码 ...

  // 新增 WebReader 配置
  @State webConfig: WebReaderConfig = {
    fontSize: 18,
    lineHeight: 1.8,
    letterSpacing: 0,
    backgroundColor: '#FFFFFF',
    textColor: '#333333',
    theme: 'light'
  };

  // WebReader 引用
  private webReaderRef: WebReader | null = null;

  // ... 其余代码 ...
}
```

### 步骤 3: 将纯文本转换为 HTML

在 `loadChapterContent` 方法中添加转换函数：

```typescript
/**
 * 将纯文本转换为 HTML
 */
private convertTextToHtml(text: string): string {
  if (!text) return '';

  // 按段落分割
  const paragraphs = text.split(/\n\s*\n/);

  // 包装为 HTML
  const htmlParagraphs = paragraphs.map(p => {
    const cleanP = p.trim()
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\n/g, '<br>');

    if (cleanP) {
      return `<p>${cleanP}</p>`;
    }
    return '';
  });

  return htmlParagraphs.join('\n');
}
```

### 步骤 4: 替换阅读器 UI

找到 ReadPage 的 build 方法，替换内容显示部分：

**原代码**:
```typescript
Scroll() {
  Text(this.chapterContent.content)
    .fontSize(this.readConfig.fontSize)
    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
    .lineHeight(this.readConfig.lineSpacing)
    // ...
}
```

**新代码**:
```typescript
// 使用 WebReader 替代 Text
WebReader({
  content: this.chapterContent
    ? this.convertTextToHtml(this.chapterContent.content)
    : '',
  config: this.webConfig,
  onClick: () => {
    this.showMenu = !this.showMenu;
  },
  onChapterEnd: () => {
    // 自动加载下一章
    this.nextChapter();
  }
})
  .width('100%')
  .height('100%')
```

### 步骤 5: 添加主题同步

在 `aboutToAppear` 或主题切换时同步配置：

```typescript
// 根据当前主题更新 WebReader 配置
private syncThemeToWebReader() {
  const isLight = themeManager.isLightTheme();

  if (isLight) {
    this.webConfig = {
      ...this.webConfig,
      backgroundColor: '#FFFFFF',
      textColor: '#333333',
      theme: 'light'
    };
  } else {
    this.webConfig = {
      ...this.webConfig,
      backgroundColor: '#1A1A1A',
      textColor: '#D4D4D4',
      theme: 'dark'
    };
  }
}
```

### 步骤 6: 更新字号调整逻辑

**原代码**:
```typescript
// 增大字号
this.readConfig.fontSize = Math.min(this.readConfig.fontSize + 2, 32);
```

**新代码**:
```typescript
// 增大字号（同时更新 readConfig 和 webConfig）
const newSize = Math.min(this.readConfig.fontSize + 2, 32);
this.readConfig.fontSize = newSize;
this.webConfig = { ...this.webConfig, fontSize: newSize };
```

## 注意事项

### 1. Web 组件权限

确保在 `module.json5` 中声明网络权限（如果需要加载网络图片）：

```json
{
  "module": {
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET"
      }
    ]
  }
}
```

### 2. 大章节性能

对于超大章节（> 500KB），建议：
- 分页加载
- 虚拟滚动
- 延迟渲染

### 3. 图片处理

WebReader 支持图片显示，但需要：
- 设置图片最大宽度为 100%
- 处理图片加载失败情况
- 可选：添加图片点击放大功能

### 4. 点击区域

WebReader 的点击区域划分：
- **左侧 1/3**: 上一页/上一章
- **中间 1/3**: 显示/隐藏菜单
- **右侧 1/3**: 下一页/下一章

可以在 WebReader.ets 中修改点击区域的逻辑。

## 测试建议

迁移完成后，测试以下场景：

1. **基础功能**
   - [ ] 章节内容正常显示
   - [ ] 翻页流畅
   - [ ] 点击显示/隐藏菜单

2. **主题切换**
   - [ ] 亮色主题
   - [ ] 暗色主题
   - [ ] 切换时内容不闪烁

3. **配置调整**
   - [ ] 字号增大/减小
   - [ ] 行距调整
   - [ ] 配置持久化

4. **特殊内容**
   - [ ] 包含图片的章节
   - [ ] 包含特殊格式的章节
   - [ ] 超长短章节

## 回退方案

如果 WebReader 出现问题，可以快速回退到 Text 组件：

```typescript
// 添加一个标志控制使用哪个阅读器
@State useWebReader: boolean = true;

// 在 build 中判断
if (this.useWebReader) {
  WebReader({...})
} else {
  // 原来的 Text 实现
  Text(this.chapterContent.content)
    ...
}
```

## 后续优化方向

1. **翻页动画**: 添加模拟纸质书翻页效果
2. **字体选择**: 支持自定义字体（通过 Web Font）
3. **批注高亮**: 在 Web 组件中实现文本选择和批注
4. **TTS 朗读**: 集成系统 TTS 接口
5. **音量键翻页**: 监听音量键事件

---

**最后更新**: 2026-02-16
