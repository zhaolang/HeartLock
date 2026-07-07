import lockService from '../service/LockService';

@Entry
@Component
struct InvitationCardPage {
  @State lockId: string = '';
  @State cardUrl: string = '';
  @State isGenerating: boolean = false;

  aboutToAppear(): void {
    const ctx = AppStorage.get<object>('context') as any;
    const params = ctx?.router?.getParams?.();
    this.lockId = (params?.['lockId'] as string) ?? '';
    if (this.lockId) {
      this.generateCard();
    }
  }

  generateCard(): void {
    this.isGenerating = true;
    lockService.generateInvitationCard(this.lockId).then((res) => {
      this.cardUrl = res.cardUrl;
      this.isGenerating = false;
    }).catch(() => {
      this.isGenerating = false;
    });
  }

  handleSave(): void {
    // In production: use @ohos.multimedia.image to save bitmap
    // For preview: show success
    AlertDialog.show({
      message: '卡片已保存到相册',
      confirm: { value: '好的', action: () => {} }
    });
  }

  handleShare(): void {
    // In production: use system share sheet
    AlertDialog.show({
      message: '分享功能',
      confirm: { value: '好的', action: () => {} }
    });
  }

  build() {
    Column() {
      // Back button
      Row() {
        Button()
          .width(36)
          .height(36)
          .backgroundColor('transparent')
          .onClick(() => {
            try {
              const ctx = AppStorage.get<object>('context') as any;
              if (ctx) ctx.router.back();
            } catch (e) {}
          })
          .overlay({
            builder: () => Text('←')
              .fontSize(22)
              .fontColor('#FFFFFF')
          })
        Blank()
      }
      .width('100%')
      .padding({ left: 8, top: 8 })

      Scroll() {
        Column({ space: 0 }) {
          // Card preview area
          Column({ space: 24 }) {
            Column() {
              // Spacer
              Column().height('15%')

              Text('🔒')
                .fontSize(72)

              Text('有人把一份喜欢放进了心锁')
                .fontSize(18)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Bold)
                .textAlign(TextAlign.Center)
                .margin({ top: 20 })

              Text('只有当你也想起 TA 的时候')
                .fontSize(14)
                .fontColor('#99FFFFFF')
                .textAlign(TextAlign.Center)

              Text('这把锁才会打开')
                .fontSize(14)
                .fontColor('#99FFFFFF')
                .textAlign(TextAlign.Center)

              Column().layoutWeight(1)

              Text('秘密属于一个人，答案属于两个人')
                .fontSize(12)
                .fontColor('#66FFFFFF')
                .textAlign(TextAlign.Center)
                .margin({ bottom: 24 })
            }
            .width('85%')
            .aspectRatio(0.7)
            .backgroundColor('#111111')
            .borderRadius(16)
            .border({ width: 1, color: '#2A2A2A' })
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding(24)

          // Action buttons
          Column({ space: 12 }) {
            Button('保存到相册')
              .width('80%')
              .height(48)
              .backgroundColor('#D4A574')
              .fontColor('#0D0D0D')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .borderRadius(24)
              .onClick(() => this.handleSave())
              .loading(this.isGenerating)

            Button('分享')
              .width('80%')
              .height(44)
              .backgroundColor('transparent')
              .fontColor('#FFFFFF')
              .fontSize(16)
              .border({ width: 1, color: '#2A2A2A' })
              .borderRadius(22)
              .onClick(() => this.handleShare())
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 12 })
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
  }
}
