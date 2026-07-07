@Component
export struct LogoHeader {
  private showProfile: boolean = true;

  build() {
    Row() {
      // Left: brand
      Row({ space: 8 }) {
        Image($r('app.media.app_icon'))
          .width(28)
          .height(28)
          .borderRadius(14)
        Text('心锁')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      // Right: profile / placeholder
      if (this.showProfile) {
        Image($r('app.media.app_icon'))
          .width(32)
          .height(32)
          .borderRadius(16)
          .onClick(() => {
            try {
              const ctx = AppStorage.get<object>('context') as any;
              if (ctx) {
                ctx.router.pushUrl({ url: 'pages/ProfilePage' });
              }
            } catch (e) {
              console.error('nav error', JSON.stringify(e));
            }
          })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 20 })
  }
}
