@Entry
@Component
struct UnlockCeremonyPage {
  @State phase: number = 0;  // 0=black, 1=lock closed, 2=lock opening, 3=open, 4=hearts, 5=words
  @State lockRotation: number = 0;
  @State theirWords: string = '';

  aboutToAppear(): void {
    const ctx = AppStorage.get<object>('context') as any;
    const params = ctx?.router?.getParams?.();
    this.theirWords = (params?.['theirWords'] as string) ?? '我也喜欢你很久了。';

    // Phase 0: black (instant)
    this.phase = 0;

    // Phase 1: lock appears after 300ms
    setTimeout(() => {
      this.phase = 1;

      // Phase 2: lock starts opening after 500ms
      setTimeout(() => {
        this.phase = 2;
        // Animate rotation
        animateTo({ duration: 1500, curve: Curve.EaseInOut }, () => {
          this.lockRotation = 180;
        });

        // Phase 3: open complete
        setTimeout(() => {
          this.phase = 3;

          // Phase 4: hearts appear
          setTimeout(() => {
            this.phase = 4;

            // Phase 5: their words
            setTimeout(() => {
              this.phase = 5;
            }, 500);
          }, 800);
        }, 1600);
      }, 500);
    }, 300);
  }

  handleContinue(): void {
    // Navigate back to home
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
      Column({ space: 24 }) {
        // Phase 1-3: Lock animation
        if (this.phase >= 1 && this.phase <= 3) {
          Text(this.phase === 3 ? '🔓' : '🔒')
            .fontSize(80)
            .rotate({ angle: this.lockRotation })
            .animation({ duration: 1500, curve: Curve.EaseInOut })
            .opacity(this.phase >= 1 ? 1 : 0)
        }

        // Phase 4: hearts + title
        if (this.phase >= 4) {
          Text('❤️ ❤️ ❤️')
            .fontSize(32)
            .opacity(this.phase >= 4 ? 1 : 0)

          Text('心锁已打开')
            .fontSize(24)
            .fontColor('#D4A574')
            .fontWeight(FontWeight.Bold)
            .opacity(this.phase >= 4 ? 1 : 0)

          Text('因为你们互相喜欢')
            .fontSize(15)
            .fontColor('#99FFFFFF')
            .opacity(this.phase >= 4 ? 1 : 0)
        }

        // Phase 5: their words
        if (this.phase >= 5) {
          Column({ space: 16 }) {
            Text('TA 写给你的第一句话……')
              .fontSize(13)
              .fontColor('#66FFFFFF')

            Text(`"${this.theirWords}"`)
              .fontSize(18)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
              .lineHeight(28)
              .textAlign(TextAlign.Center)
              .padding({ left: 24, right: 24 })

            Button('继续')
              .width('70%')
              .height(48)
              .backgroundColor('#D4A574')
              .fontColor('#0D0D0D')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .borderRadius(24)
              .onClick(() => this.handleContinue())
              .margin({ top: 12 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding(24)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
