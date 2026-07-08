import { Navigation } from '../ui-kit/Navigation';
import authService from '../service/AuthService';
import lockService from '../service/LockService';
import { vibrator } from '@kit.SensorServiceKit';

@Entry
@Component
struct CreateLockPage {
  @State targetPhone: string = '';
  @State lockContent: string = '';
  @State charCount: number = 0;
  @State errorMsg: string = '';
  @State isSubmitting: boolean = false;
  @State inputBorderColor: string = '#2A2A2A';
  @State contentBorderColor: string = '#2A2A2A';
  @State contentOpacity: number = 0;
  @State contentOffset: number = 20;

  aboutToAppear(): void {
    animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
      this.contentOpacity = 1;
      this.contentOffset = 0;
    });
  }

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
    this.inputBorderColor = this.targetPhone.length > 0 ? '#D4A57466' : '#2A2A2A';
  }

  onContentInput(val: string): void {
    this.lockContent = val;
    this.charCount = val.length;
    this.errorMsg = '';
    const isOver = val.length > 500;
    this.contentBorderColor = isOver ? '#FF4444' : (val.length > 0 ? '#D4A57466' : '#2A2A2A');
  }

  validateForm(): boolean {
    if (this.targetPhone.length !== 11) {
      this.errorMsg = '手机号格式不正确';
      this.inputBorderColor = '#FF4444';
      return false;
    }
    if (this.lockContent.length < 1 || this.lockContent.length > 500) {
      this.errorMsg = '心锁内容需在 1-500 字之间';
      this.contentBorderColor = '#FF4444';
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
    // 触觉反馈
    try { vibrator.startVibration({ type: 'preset', effectId: 'haptic.medium' }, { usage: 'alarm' }, (e: Error | null) => {}); } catch (_) {}
    // 检查手机号授权（REQ-004）
    if (!authService.isPhoneAuthorized) {
      AlertDialog.show({
        title: '需要授权手机号',
        message: '创建心锁需要先授权手机号',
        confirm: { value: '好的', action: () => Navigation.back() }
      });
      return;
    }
    this.isSubmitting = true;

    lockService.createLock({
      targetPhone: this.targetPhone,
      content: this.lockContent
    }).then((res) => {
      this.isSubmitting = false;
      if (res.matched) {
        const p: Record<string, Object> = {};
p["lockId"] = res.id;
p["theirWords"] = res.theirWords ?? '';
        Navigation.replace('pages/UnlockCeremonyPage', p);
      } else {
        Navigation.back();
      }
    }).catch((err: Error) => {
      this.isSubmitting = false;
      this.errorMsg = err.message || '操作失败，请稍后重试';
    });
  }

  build() {
    Column() {
      // ── 返回按钮 ──
      Row() {
        Button() {
          Text('←')
            .fontSize(22)
            .fontColor('#FFFFFF')
        }
        .width(36)
        .height(36)
        .backgroundColor('transparent')
        .onClick(() => Navigation.back())

        Blank()
      }
      .width('100%')
      .padding({ left: 8, right: 20, top: 8 })

      Scroll() {
        Column({ space: 0 }) {
          // ── 顶部图标 + 标题 ──
          Column({ space: 16 }) {
            Stack({ alignContent: Alignment.Center }) {
              Circle()
                .width(72)
                .height(72)
                .fill('#18D4A574')
              Image($rawfile('icons/lock-closed.svg'))
                .width(40)
                .height(40)
                .objectFit(ImageFit.Contain)
                .opacity(0.7)
            }

            Text('把你的喜欢存进心锁')
              .fontSize(22)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 16, bottom: 32 })

          // ── 手机号输入 ──
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
              .border({ width: 1, color: this.inputBorderColor })
              .borderRadius(12)
              .height(50)
              .padding({ left: 16 })
              .onChange((val) => this.onPhoneInput(val))
          }
          .opacity(this.contentOpacity)
          .offset({ y: this.contentOffset })

          // ── 心锁内容输入 ──
          Column({ space: 8 }) {
            Row() {
              Text('想对 TA 说的话')
                .fontSize(14)
                .fontColor('#99FFFFFF')
              Blank()
              Text(`${this.charCount} / 500`)
                .fontSize(12)
                .fontColor(this.charCount > 500 ? '#FF4444' : (this.charCount > 0 ? '#D4A574' : '#66FFFFFF'))
            }

            TextArea({ placeholder: '写下你想对 TA 说的话……', text: this.lockContent })
              .fontSize(15)
              .fontColor('#FFFFFF')
              .placeholderColor('#66FFFFFF')
              .backgroundColor('#1A1A1A')
              .border({ width: 1, color: this.contentBorderColor })
              .borderRadius(12)
              .height(160)
              .padding(16)
              .onChange((val) => this.onContentInput(val))
          }
          .margin({ top: 24 })
          .opacity(this.contentOpacity)
          .offset({ y: this.contentOffset })

          // ── 错误信息 ──
          if (this.errorMsg) {
            Text(this.errorMsg)
              .fontSize(13)
              .fontColor('#FF4444')
              .margin({ top: 8 })
              .opacity(this.contentOpacity)
          }

          // ── 提交按钮 ──
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
            .margin({ top: 20 })
            .shadow({ radius: this.isFormValid ? 12 : 0, color: '#30D4A574', offsetX: 0, offsetY: 4 })

          // ── 提示文字 ──
          Text('一份喜欢，一生只给同一个人一次')
            .fontSize(13)
            .fontColor('#66FFFFFF')
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 16, bottom: 24 })
            .opacity(this.contentOpacity)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
    .alignItems(HorizontalAlign.Start)
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.EaseInOut })
      .opacity(0)
    PageTransitionExit({ duration: 300, curve: Curve.EaseInOut })
      .opacity(0)
  }

}
