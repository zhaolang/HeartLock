import lockService from '../service/LockService';

@Entry
@Component
struct CreateLockPage {
  @State targetPhone: string = '';
  @State lockContent: string = '';
  @State charCount: number = 0;
  @State errorMsg: string = '';
  @State isSubmitting: boolean = false;

  get isFormValid(): boolean {
    return this.targetPhone.length === 11
      && this.lockContent.length >= 1
      && this.lockContent.length <= 500
      && this.errorMsg === '';
  }

  onPhoneInput(val: string): void {
    const digits = val.replace(/\D/g, '');
    this.targetPhone = digits.slice(0, 11);
    this.errorMsg = '';
  }

  onContentInput(val: string): void {
    this.lockContent = val;
    this.charCount = val.length;
    this.errorMsg = '';
  }

  validateForm(): boolean {
    if (this.targetPhone.length !== 11) {
      this.errorMsg = '手机号格式不正确';
      return false;
    }
    if (this.lockContent.length < 1 || this.lockContent.length > 500) {
      this.errorMsg = '心锁内容需在 1-500 字之间';
      return false;
    }
    return true;
  }

  showConfirmDialog(): void {
    AlertDialog.show({
      title: '确认将这份喜欢放进心锁？',
      message: '此操作不可撤销，请确认手机号正确',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认',
        action: () => this.submitLock()
      }
    });
  }

  submitLock(): void {
    if (!this.validateForm() || this.isSubmitting) return;
    this.isSubmitting = true;

    lockService.createLock({
      targetPhone: this.targetPhone,
      content: this.lockContent
    }).then((res) => {
      this.isSubmitting = false;
      if (res.matched) {
        // Navigate to ceremony
        try {
          const ctx = AppStorage.get<object>('context') as any;
          if (ctx) {
            ctx.router.replaceUrl({
              url: 'pages/UnlockCeremonyPage',
              params: { lockId: res.id }
            });
          }
        } catch (e) {
          console.error('nav error', JSON.stringify(e));
        }
      } else {
        // Go back to home
        try {
          const ctx = AppStorage.get<object>('context') as any;
          if (ctx) {
            ctx.router.back();
          }
        } catch (e) {
          console.error('nav error', JSON.stringify(e));
        }
      }
    }).catch((err) => {
      this.isSubmitting = false;
      this.errorMsg = err.message || '操作失败，请稍后重试';
    });
  }

  build() {
    Column() {
      // Title
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
      .padding({ left: 8, right: 20, top: 8 })

      Scroll() {
        Column({ space: 24 }) {
          // Page title
          Text('把你的喜欢存进心锁')
            .fontSize(22)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .margin({ top: 12 })

          // Phone input
          Column({ space: 8 }) {
            Text('对方手机号')
              .fontSize(14)
              .fontColor('#99FFFFFF')

            TextInput({ placeholder: '输入对方手机号', text: this.targetPhone })
              .type(InputType.Number)
              .maxLength(11)
              .fontSize(16)
              .fontColor('#FFFFFF')
              .placeholderColor('#66FFFFFF')
              .backgroundColor('#1A1A1A')
              .borderRadius(12)
              .height(50)
              .padding({ left: 16 })
              .onChange((val) => this.onPhoneInput(val))
          }

          // Content input
          Column({ space: 8 }) {
            Row() {
              Text('想对 TA 说的话')
                .fontSize(14)
                .fontColor('#99FFFFFF')
              Blank()
              Text(`${this.charCount}/500`)
                .fontSize(12)
                .fontColor(this.charCount > 500 ? '#FF4444' : '#66FFFFFF')
            }

            TextArea({ placeholder: '写下你想对 TA 说的话……', text: this.lockContent })
              .fontSize(15)
              .fontColor('#FFFFFF')
              .placeholderColor('#66FFFFFF')
              .backgroundColor('#1A1A1A')
              .borderRadius(12)
              .height(160)
              .padding(16)
              .onChange((val) => this.onContentInput(val))
          }

          // Error message
          if (this.errorMsg) {
            Text(this.errorMsg)
              .fontSize(13)
              .fontColor('#FF4444')
          }

          // Submit button
          Button('放进心锁')
            .width('100%')
            .height(50)
            .backgroundColor(this.isFormValid ? '#D4A574' : '#33D4A574')
            .fontColor(this.isFormValid ? '#0D0D0D' : '#66FFFFFF')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .borderRadius(12)
            .enabled(this.isFormValid && !this.isSubmitting)
            .onClick(() => this.showConfirmDialog())
            .margin({ top: 12 })

          // Hint
          Text('一份喜欢，一生只给同一个人一次')
            .fontSize(13)
            .fontColor('#66FFFFFF')
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        .width('100%')
        .padding(20)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
    .alignItems(HorizontalAlign.Start)
  }
}
