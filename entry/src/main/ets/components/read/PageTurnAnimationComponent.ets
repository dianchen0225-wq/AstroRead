@ComponentV2
export struct PageTurnAnimationComponent {
  @Param pageTurnDirection: string = 'none';
  @Param pageTurnProgress: number = 0;

  build() {
    if (this.pageTurnDirection !== 'none') {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.pageTurnDirection === 'next' ?
          'rgba(0, 0, 0, 0.1)' : 'rgba(255, 255, 255, 0.1)')
        .opacity(this.pageTurnProgress > 0.5 ? 1 - this.pageTurnProgress : this.pageTurnProgress)
    }
  }
}
