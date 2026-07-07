@Entry
@Component
struct SplashPage {
  @State lockOpacity: number = 0;
  @State sloganOpacity: number = 0;

  aboutToAppear(): void {
    // Lock icon fade-in 500ms
    animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
      this.lockOpacity = 1;
    });

    // Slogan fade-in after 500ms
    setTimeout(() => {
      animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.sloganOpacity = 1;
      });
    }, 500);

    // Navigate after 2.5s
    setTimeout(() => {
      this.navigateNext();
    }, 2500);
  }

  navigateNext(): void {
    const token = AppStorage.get<string>('auth_token');
    const target = token ? 'pages/HomePage' : 'pages/LoginPage';
    try {
      const ctx = AppStorage.get<object>('context') as any;
      if (ctx) {
        ctx.router.pushUrl({ url: target });
      }
    } catch (e) {
      console.error('nav error', JSON.stringify(e));
    }
  }

  build() {
    Column({ space: 24 }) {
      // Lock icon
      Text('🔒')
        .fontSize(64)
        .opacity(this.lockOpacity)

      // Slogan
      Text('秘密属于一个人，答案属于两个人')
        .fontSize(16)
        .fontColor('#D4A574')
        .textAlign(TextAlign.Center)
        .opacity(this.sloganOpacity)
        .lineHeight(24)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
