/**
 * 心锁图标组件
 * 从 rawfile 加载 SVG 锁图标
 */
@Component
export struct LockIcon {
  private status: 'closed' | 'open' = 'closed';
  private size: number = 64;

  build() {
    if (this.status === 'open') {
      Image($rawfile('icons/lock-open.svg'))
        .width(this.size)
        .height(this.size)
        .objectFit(ImageFit.Contain)
    } else {
      Image($rawfile('icons/lock-closed.svg'))
        .width(this.size)
        .height(this.size)
        .objectFit(ImageFit.Contain)
    }
  }
}

/**
 * 心形图标组件
 */
@Component
export struct HeartIcon {
  private size: number = 32;

  build() {
    Image($rawfile('icons/heart.svg'))
      .width(this.size)
      .height(this.size)
      .objectFit(ImageFit.Contain)
  }
}

/**
 * 品牌 Logo 图标组件
 */
@Component
export struct LogoIcon {
  private size: number = 48;

  build() {
    Image($rawfile('icons/logo.svg'))
      .width(this.size)
      .height(this.size)
      .objectFit(ImageFit.Contain)
  }
}
