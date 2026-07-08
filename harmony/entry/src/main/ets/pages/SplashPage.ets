import { Navigation } from '../ui-kit/Navigation';
import { IBestInit } from '@ibestservices/ibest-ui';

@Entry
@Component
struct SplashPage {
  @State bgOpacity: number = 0;
  @State lockOpacity: number = 0;
  @State lockScale: number = 0.6;
  @State glowOpacity: number = 0;
  @State sloganOpacity: number = 0;
  @State sloganOffset: number = 20;
  @State brandOpacity: number = 0;

  aboutToAppear(): void {
    IBestInit();
    // 背景淡入 (300ms)
    animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.bgOpacity = 1;
    });

    // 锁图标淡入 + 缩放 (600ms)
    setTimeout(() => {
      animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
        this.lockOpacity = 1;
        this.lockScale = 1;
        this.glowOpacity = 0.25;
      });
    }, 200);

    // Slogan 出现 (600ms 后)
    setTimeout(() => {
      animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.sloganOpacity = 1;
        this.sloganOffset = 0;
      });
    }, 900);

    // 品牌名出现 (1.5s 后)
    setTimeout(() => {
      animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.brandOpacity = 1;
      });
    }, 1500);

    // 2.5s 后跳转
    setTimeout(() => {
      this.navigateNext();
    }, 2500);
  }

  navigateNext(): void {
    const token = AppStorage.get<string>('auth_token');
    const target = token ? 'pages/HomePage' : 'pages/LoginPage';
    try {
      Navigation.replace(target);
    } catch (e) {
      console.error('nav error', JSON.stringify(e));
    }
  }

  build() {
    Column({ space: 24 }) {
      // 弹性间距
      Blank().layoutWeight(1)

      // ── 锁图标区域 ──
      Stack({ alignContent: Alignment.Center }) {
        // 金色光晕
        Circle()
          .width(130)
          .height(130)
          .fill('#24D4A574')
          .opacity(this.glowOpacity)
          .scale({ x: 1.2 + this.glowOpacity * 0.5, y: 1.2 + this.glowOpacity * 0.5 })

        // 锁图标
        Image($rawfile('icons/lock-closed.svg'))
          .width(72)
          .height(72)
          .objectFit(ImageFit.Contain)
          .opacity(this.lockOpacity)
          .scale({ x: this.lockScale, y: this.lockScale })
      }
      .width(140)
      .height(140)
      .shadow({ radius: 20, color: '#20D4A574', offsetX: 0, offsetY: 0 })

      // ── 品牌名 ──
      Text('心锁')
        .fontSize(14)
        .fontColor('#99FFFFFF')
        .letterSpacing(6)
        .opacity(this.brandOpacity)

      // 弹性间距
      Blank().layoutWeight(1)

      // ── 品牌 Slogan ──
      Text('秘密属于一个人，答案属于两个人')
        .fontSize(16)
        .fontColor('#D4A574')
        .textAlign(TextAlign.Center)
        .opacity(this.sloganOpacity)
        .lineHeight(24)
        .offset({ y: this.sloganOffset })

      // 底部间距
      Column().height(60)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .opacity(this.bgOpacity)
  }
}
