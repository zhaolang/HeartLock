import { Navigation } from '../ui-kit/Navigation';
import authService from '../service/AuthService';

@Entry
@Component
struct LoginPage {
  @State sloganLines: string[] = [
    '所有单向的喜欢，都会永远保密',
    '只有双向的喜欢，才值得被世界知道'
  ];
  @State contentOpacity: number = 0;
  @State contentOffset: number = 30;
  @State buttonOpacity: number = 0;

  aboutToAppear(): void {
    // 内容淡入 + 上移 (600ms)
    animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
      this.contentOpacity = 1;
      this.contentOffset = 0;
    });

    // 按钮延迟淡入 (700ms)
    setTimeout(() => {
      animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.buttonOpacity = 1;
      });
    }, 700);
  }

  handleLogin(): void {
    authService.login('mock-huawei-credential').then(() => {
      if (!authService.isPhoneAuthorized) {
        this.showPhoneAuthDialog();
      } else {
        Navigation.replace('pages/HomePage');
      }
    }).catch(() => {
      Navigation.replace('pages/HomePage');
    });
  }

  showPhoneAuthDialog(): void {
    AlertDialog.show({
      title: '授权手机号',
      message: '为匹配心锁，需要授权您的手机号。您的手机号将以加密哈希方式存储，不会泄露号码明文。',
      primaryButton: {
        value: '暂不授权',
        action: () => {
          Navigation.replace('pages/HomePage');
        }
      },
      secondaryButton: {
        value: '授权',
        action: () => {
          authService.authorizePhone('13800000000').then(() => {
            Navigation.replace('pages/HomePage');
          });
        }
      }
    });
  }

  build() {
    Column({ space: 0 }) {
      // ── 顶部留白 ──
      Column().height('14%')

      // ── Logo 与品牌名 ──
      Column({ space: 16 }) {
        Image($rawfile('icons/logo.svg'))
          .width(56)
          .height(56)
          .objectFit(ImageFit.Contain)

        Text('心锁')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .letterSpacing(6)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // ── 弹性间距 ──
      Blank().layoutWeight(1)

      // ── 品牌理念文案 ──
      Column({ space: 12 }) {
        ForEach(this.sloganLines, (line: string) => {
          Text(line)
            .fontSize(15)
            .fontColor('#B0FFFFFF')
            .textAlign(TextAlign.Center)
            .lineHeight(24)
        }, (line: string) => line)
      }
      .opacity(this.contentOpacity)
      .offset({ y: this.contentOffset })
      .padding({ bottom: 40 })
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // ── 华为账号一键登录 ──
      Button() {
        Row({ space: 10 }) {
          Stack({ alignContent: Alignment.Center }) {
            Circle()
              .width(24)
              .height(24)
              .fill('#0D0D0D')
              .opacity(0.15)
            Circle()
              .width(8)
              .height(8)
              .fill('#0D0D0D')
              .offset({ y: -4 })
            Path()
              .commands('M12,22 Q12,16 18,16 Q24,16 24,22')
              .fill('#0D0D0D')
              .width(12)
              .height(6)
              .offset({ y: 5 })
          }
          .width(26)
          .height(26)

          Text('华为账号一键登录')
            .fontSize(17)
            .fontColor('#0D0D0D')
            .fontWeight(FontWeight.Bold)
        }
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .width('85%')
      .height(52)
      .backgroundColor('#D4A574')
      .borderRadius(26)
      .opacity(this.buttonOpacity)
      .shadow({ radius: 16, color: '#30D4A574', offsetX: 0, offsetY: 4 })
      .onClick(() => this.handleLogin())

      // ── 手机号登录（备选） ──
      Row({ space: 8 }) {
        Divider()
          .color('#2A2A2A')
          .width('30%')
        Text('或')
          .fontSize(13)
          .fontColor('#66FFFFFF')
        Divider()
          .color('#2A2A2A')
          .width('30%')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ top: 28 })
      .opacity(this.buttonOpacity)

      Button('手机号登录')
        .width('85%')
        .height(46)
        .backgroundColor('transparent')
        .fontColor('#FFFFFF')
        .fontSize(16)
        .border({ width: 1, color: '#2A2A2A' })
        .borderRadius(23)
        .opacity(this.buttonOpacity)
        .onClick(() => this.handleLogin())

      Blank().height(16)

      Text('首次使用将自动创建心锁账户')
        .fontSize(12)
        .fontColor('#66FFFFFF')
        .margin({ bottom: 50 })
        .opacity(this.buttonOpacity)

    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#0D0D0D', 0], ['#1A1A1A', 1]]
    })
    .alignItems(HorizontalAlign.Center)
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.EaseInOut })
      .opacity(0)
    PageTransitionExit({ duration: 300, curve: Curve.EaseInOut })
      .opacity(0)
  }

}
