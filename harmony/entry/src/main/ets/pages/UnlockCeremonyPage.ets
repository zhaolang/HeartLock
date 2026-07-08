import { Navigation } from '../ui-kit/Navigation';
import { IBestInit } from '@ibestservices/ibest-ui';
import { vibrator } from '@kit.SensorServiceKit';

@Entry
@Component
struct UnlockCeremonyPage {
  // 动画场景: 0=初始 1=渐黑+震动 2=锁出现 3=锁打开 4=心+标题 5=对方的话
  @State scene: number = 0;
  @State bgOpacity: number = 0;
  @State lockOpacity: number = 0;
  @State lockScale: number = 0.6;
  @State lockRotation: number = 0;
  @State lockGlowOpacity: number = 0;
  @State lockedVisible: boolean = true;
  @State heartOpacity: number = 0;
  @State titleOpacity: number = 0;
  @State subtitleOpacity: number = 0;
  @State wordsOpacity: number = 0;
  @State showContinue: boolean = false;
  @State theirWords: string = '';

  aboutToAppear(): void {
    IBestInit();
    const params = Navigation.getParams();
    this.theirWords = (params?.['theirWords'] as string) ?? '打开心锁的那一刻，才有答案。';
    this.startCeremony();
  }

  startCeremony(): void {
    // 触发震动
    this.triggerVibration();

    // === 场景 1: 屏幕渐黑 + 震动 (300ms) ===
    this.scene = 1;
    animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.bgOpacity = 1;
    });

    // === 场景 2: 锁出现 + 金色光晕 (400ms) ===
    setTimeout(() => {
      this.scene = 2;
      animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.lockOpacity = 1;
        this.lockScale = 1;
        this.lockGlowOpacity = 0.35;
      });

      // === 场景 3: 锁打开 (700ms 后开始旋转) ===
      setTimeout(() => {
        this.scene = 3;
        animateTo({ duration: 1200, curve: Curve.EaseInOut }, () => {
          this.lockRotation = 120;
          this.lockedVisible = false;
          this.lockGlowOpacity = 0.6;
        });

        // === 场景 4: 心 + 标题 (1200ms 后) ===
        setTimeout(() => {
          this.scene = 4;
          animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
            this.heartOpacity = 1;
            this.titleOpacity = 1;
          });

          // 副标题 (300ms 后)
          setTimeout(() => {
            animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
              this.subtitleOpacity = 1;
            });

            // === 场景 5: 对方的话 (300ms 后) ===
            setTimeout(() => {
              this.scene = 5;
              animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
                this.wordsOpacity = 1;
              });

              // 继续按钮 (400ms 后)
              setTimeout(() => {
                animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
                  this.showContinue = true;
                });
              }, 400);
            }, 300);
          }, 300);
        }, 1200);
      }, 700);
    }, 400);
  }

  triggerVibration(): void {
    try {
      vibrator.startVibration({
        type: 'preset',
        effectId: 'haptic.shock',
      }, {
        usage: 'alarm'
      }, (error: Error | null) => {});
    } catch (_) {}
  }

  handleContinue(): void {
    try {
      Navigation.replace('pages/HomePage');
    } catch (e) {
      console.error('nav error', JSON.stringify(e));
    }
  }

  build() {
    Stack() {
      // ── 深色背景填充 (渐黑效果) ──
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#0D0D0D')
        .opacity(this.bgOpacity)

      // ═══ 场景 1-3: 锁开启动画 ═══
      if (this.scene >= 1 && this.scene <= 3) {
        Stack({ alignContent: Alignment.Center }) {
          // 金色光晕
          Circle()
            .width(160)
            .height(160)
            .fill('#24D4A574')
            .opacity(this.lockGlowOpacity)
            .scale({ x: 1.2 + this.lockGlowOpacity * 0.4, y: 1.2 + this.lockGlowOpacity * 0.4 })

          // 闭合锁
          if (this.lockedVisible) {
            Image($rawfile('icons/lock-closed.svg'))
              .width(80)
              .height(80)
              .objectFit(ImageFit.Contain)
              .opacity(this.lockOpacity)
              .scale({ x: this.lockScale, y: this.lockScale })
              .rotate({ x: 0, y: 1, z: 0, angle: this.lockRotation, centerX: 40, centerY: 40 })
          }

          // 打开锁
          if (!this.lockedVisible) {
            Image($rawfile('icons/lock-open.svg'))
              .width(80)
              .height(80)
              .objectFit(ImageFit.Contain)
              .opacity(this.lockOpacity)
              .scale({ x: this.lockScale, y: this.lockScale })
              .rotate({ x: 0, y: 1, z: 0, angle: this.lockRotation, centerX: 40, centerY: 40 })
          }
        }
        .width('100%')
        .height('40%')
        .margin({ top: '25%' })
        .shadow({ radius: 30, color: '#30D4A574', offsetX: 0, offsetY: 0 })
      }

      // ═══ 场景 4: 心 + "心锁已打开" ═══
      if (this.scene >= 4) {
        Column({ space: 16 }) {

          Image($rawfile('icons/heart.svg'))
            .width(44)
            .height(44)
            .objectFit(ImageFit.Contain)
            .opacity(this.heartOpacity)
            .scale({ x: 0.8 + this.heartOpacity * 0.2, y: 0.8 + this.heartOpacity * 0.2 })

          Text('心锁已打开')
            .fontSize(28)
            .fontColor('#D4A574')
            .fontWeight(FontWeight.Bold)
            .opacity(this.titleOpacity)
            .letterSpacing(2)

          Text('因为你们互相喜欢')
            .fontSize(15)
            .fontColor('#B0FFFFFF')
            .lineHeight(22)
            .opacity(this.subtitleOpacity)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 100 })
      }

      // ═══ 场景 5: 对方的话 + 继续按钮 ═══
      if (this.scene >= 5) {
        Column({ space: 16 }) {
          Column().height('35%')

          Column({ space: 16 }) {
            Row({ space: 8 }) {
              Image($rawfile('icons/heart.svg'))
                .width(14)
                .height(14)
                .objectFit(ImageFit.Contain)
              Text('TA 写给你的第一句话……')
                .fontSize(13)
                .fontColor('#66FFFFFF')
            }
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .opacity(this.wordsOpacity)

            Text(`"${this.theirWords}"`)
              .fontSize(20)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
              .lineHeight(32)
              .textAlign(TextAlign.Center)
              .padding({ left: 32, right: 32 })
              .opacity(this.wordsOpacity)

            if (this.showContinue) {
              Button('继续')
                .width('70%')
                .height(50)
                .backgroundColor('#D4A574')
                .fontColor('#0D0D0D')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .borderRadius(25)
                .onClick(() => this.handleContinue())
                .margin({ top: 24 })
                .shadow({ radius: 12, color: '#33D4A574', offsetX: 0, offsetY: 4 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 100 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.EaseInOut })
      .opacity(0)
    PageTransitionExit({ duration: 300, curve: Curve.EaseInOut })
      .opacity(0)
  }

}
