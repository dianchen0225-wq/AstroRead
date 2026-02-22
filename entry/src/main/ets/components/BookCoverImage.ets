/**
 * BookCoverImage - 书籍封面图片组件
 * 使用鸿蒙原生 Image 组件实现
 * 优化：添加图片缓存和懒加载支持
 */

import { imageScraperService } from '../utils/ImageScraperService';

@Component
export struct BookCoverImage {
  @Prop @Watch('onSrcChange') src: string | Resource = '';
  @Prop bookWidth: number = 80;
  @Prop bookHeight: number = 120;
  @Prop radius: number = 4;
  @Prop imageBlur: number = 0;
  @Prop circleCrop: boolean = false;
  @Prop imageGrayscale: boolean = false;
  @Prop placeholder: Resource = $r('app.media.startIcon');
  @Prop errorHolder: Resource = $r('app.media.startIcon');
  @Prop objectFit: ImageFit = ImageFit.Cover;

  @State private hasError: boolean = false;
  @State private cachedImagePath: string = '';

  async onSrcChange() {
    this.hasError = false;
    this.cachedImagePath = '';

    // 如果是网络图片，尝试从缓存加载
    if (typeof this.src === 'string' && this.src.startsWith('http')) {
      try {
        const cachedPath = await this.getCachedImage(this.src);
        if (cachedPath) {
          this.cachedImagePath = cachedPath;
        }
      } catch (error) {
        // 缓存加载失败，使用原URL
      }
    }
  }

  private async getCachedImage(url: string): Promise<string | null> {
    // 调用 ImageScraperService 的缓存查询方法
    const imageService = imageScraperService;
    const cachedPath = imageService.getCachedImagePath(url);
    return cachedPath;
  }

  build() {
    Image(this.hasError ? this.errorHolder : (this.cachedImagePath || this.src))
      .width(this.bookWidth)
      .height(this.bookHeight)
      .borderRadius(this.radius)
      .objectFit(this.objectFit)
      .alt(this.placeholder)
      .onError(() => {
        this.hasError = true;
      })
  }
}

@Component
export struct SimpleBookCover {
  @Prop @Watch('onSrcChange') src: string | Resource = '';
  @Prop bookWidth: number = 80;
  @Prop bookHeight: number = 120;
  @Prop radius: number = 4;
  @Prop placeholder: Resource = $r('app.media.startIcon');
  @Prop errorHolder: Resource = $r('app.media.startIcon');
  @Prop objectFit: ImageFit = ImageFit.Cover;

  @State private hasError: boolean = false;

  onSrcChange() {
    this.hasError = false;
  }

  build() {
    Image(this.hasError ? this.errorHolder : this.src)
      .width(this.bookWidth)
      .height(this.bookHeight)
      .borderRadius(this.radius)
      .objectFit(this.objectFit)
      .alt(this.placeholder)
      .onError(() => {
        this.hasError = true;
      })
  }
}
