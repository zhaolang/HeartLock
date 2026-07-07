@Entry
@Component
struct LoginPage {
  @State sloganLines: string[] = [
    '所有单向的喜欢，都会永远保密',
    '只有双向的喜欢，才值得被世界知道'
  ];
  @State buttonText: string = '心锁已打开';

  handleLogin(): void {
    // Mock Huawei account login
    // In production: call Huawei Account Kit SDK, then authService.login()
    try {
      const ctx = AppStorage.get<object>('context') as any;
      if (ctx) {
        ctx.router.replaceUrl({ url: 'pages/HomePage' });
      }
    } catch (e) {
      console.error('nav error', JSON.stringify(e));
    }
  }

  build() {
    Column({ space: 0 }) {
      // Top spacer
      Column()
        .height('15%')

      // Logo area
      Column({ space: 12 }) {
        Text('🔒')
          .fontSize(48)

        Text('心锁')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // Spacer
      Column()
        .layoutWeight(1)

      // Slogan
      Column({ space: 8 }) {
        ForEach(this.sloganLines, (line: string) => {
          Text(line)
            .fontSize(15)
            .fontColor('#99FFFFFF')
            .textAlign(TextAlign.Center)
            .lineHeight(22)
        }, (line: string) => line)
      }
      .padding({ bottom: 40 })

      // Login button
      Button(this.buttonText)
        .width('85%')
        .height(50)
        .backgroundColor('#D4A574')
        .fontColor('#0D0D0D')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .borderRadius(25)
        .onClick(() => this.handleLogin())

      // Subtitle
      Text('首次登录将自动创建账户')
        .fontSize(13)
        .fontColor('#66FFFFFF')
        .margin({ top: 12, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
    .alignItems(HorizontalAlign.Center)
  }
}
