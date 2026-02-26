/**
 * BookCoverImage - 书籍封面图片组件
 * 使用鸿蒙原生 Image 组件实现
 */

@ComponentV2
export struct BookCoverImage {
  @Param src: string | Resource = '';
  @Param bookWidth: number = 80;
  @Param bookHeight: number = 120;
  @Param radius: number = 4;
  @Param imageBlur: number = 0;
  @Param circleCrop: boolean = false;
  @Param imageGrayscale: boolean = false;
  @Param placeholder: Resource = $r('app.media.startIcon');
  @Param errorHolder: Resource = $r('app.media.startIcon');
  @Param objectFit: ImageFit = ImageFit.Cover;

  @Local private hasError: boolean = false;

  @Monitor('src')
  onSrcChange(): void {
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

@ComponentV2
export struct SimpleBookCover {
  @Param src: string | Resource = '';
  @Param bookWidth: number = 80;
  @Param bookHeight: number = 120;
  @Param radius: number = 4;
  @Param placeholder: Resource = $r('app.media.startIcon');
  @Param errorHolder: Resource = $r('app.media.startIcon');
  @Param objectFit: ImageFit = ImageFit.Cover;

  @Local private hasError: boolean = false;

  @Monitor('src')
  onSrcChange(): void {
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
