import { Navigation } from '../ui-kit/Navigation';
import { PageHeader } from '../ui-kit/PageHeader';
import { pasteboard } from '@kit.BasicServicesKit';
import { vibrator } from '@kit.SensorServiceKit';

@Entry
@Component
struct InvitationCardPage {
  @State lockId: string = '';
  @State isGenerating: boolean = false;
  @State pageOpacity: number = 0;

  aboutToAppear(): void {
    const params = Navigation.getParams();
    this.lockId = (params?.['lockId'] as string) ?? '';

    animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.pageOpacity = 1;
    });
  }

  handleSave(): void {
    try { vibrator.startVibration({ type: 'preset', effectId: 'haptic.medium' }, { usage: 'alarm' }, (e: Error | null) => {}); } catch (_) {}
    AlertDialog.show({
      title: '已保存到相册',
      message: '你可以通过系统分享将邀请卡片发送给 TA',
      confirm: { value: '好的', action: () => {} }
    });
  }

  handleShare(): void {
    try { vibrator.startVibration({ type: 'preset', effectId: 'haptic.medium' }, { usage: 'alarm' }, (e: Error | null) => {}); } catch (_) {}
    
    AlertDialog.show({
      title: '分享邀请卡片',
      message: '选择分享方式',
      primaryButton: {
        value: '复制链接',
        action: () => this.handleCopyLink()
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }

  handleCopyLink(): void {
    try {
      const pasteData = pasteboard.createData('text/plain',
        'https://heartlock.app/invite/' + this.lockId);
      const pb = pasteboard.getSystemPasteboard();
      pb.setData(pasteData);
      AlertDialog.show({
        title: '已复制',
        message: '邀请链接已复制到剪贴板',
        confirm: { value: '好的', action: () => {} }
      });
    } catch (_) {}
  }

  build() {
    Column() {
      PageHeader({ title: '邀请卡片' })

      Scroll() {
        Column({ space: 0 }) {
          // ── 卡片预览 ──
          Column({ space: 0 }) {
            // 卡片容器
            Column() {
              Column() {
                Column().height('18%')

                // 锁图标 + 光晕
                Stack({ alignContent: Alignment.Center }) {
                  Circle()
                    .width(100)
                    .height(100)
                    .fill('#18D4A574')

                  Image($rawfile('icons/lock-closed.svg'))
                    .width(52)
                    .height(52)
                    .objectFit(ImageFit.Contain)
                }

                // 主要文案
                Text('有人把一份喜欢放进了心锁')
                  .fontSize(19)
                  .fontColor('#FFFFFF')
                  .fontWeight(FontWeight.Bold)
                  .textAlign(TextAlign.Center)
                  .margin({ top: 24 })

                Column().layoutWeight(1)

                // 副文案
                Column({ space: 2 }) {
                  Text('当你想起 TA 的时候')
                    .fontSize(13)
                    .fontColor('#99FFFFFF')
                    .textAlign(TextAlign.Center)

                  Text('这把锁才会打开')
                    .fontSize(13)
                    .fontColor('#99FFFFFF')
                    .textAlign(TextAlign.Center)
                    .margin({ bottom: 16 })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)

                // 卡片内的「打开心锁」按钮
                Text('■ 打开心锁')
                  .fontSize(14)
                  .fontColor('#D4A574')
                  .fontWeight(FontWeight.Medium)
                  .letterSpacing(2)
                  .padding({ left: 32, right: 32, top: 12, bottom: 12 })
                  .border({ width: 1, color: '#D4A57466' })
                  .borderRadius(20)

                Column().layoutWeight(0.6)

                // 品牌 Slogan
                Text('秘密属于一个人，答案属于两个人')
                  .fontSize(10)
                  .fontColor('#66FFFFFF')
                  .textAlign(TextAlign.Center)
                  .margin({ bottom: 20 })
                  .letterSpacing(1)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
            }
            .width('85%')
            .aspectRatio(0.68)
            .backgroundColor('#111111')
            .borderRadius(16)
            .border({ width: 1, color: '#2A2A2A' })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding(24)
          .opacity(this.pageOpacity)

          // ── 操作按钮 ──
          Column({ space: 12 }) {
            Button('保存到相册')
              .width('80%')
              .height(48)
              .backgroundColor('#D4A574')
              .fontColor('#0D0D0D')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .borderRadius(24)
              .shadow({ radius: 12, color: '#30D4A574', offsetX: 0, offsetY: 4 })
              .onClick(() => this.handleSave())

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
          .margin({ top: 8, bottom: 16 })
          .opacity(this.pageOpacity)

          // ── 底部提示 ──
          Text('通过此卡片下载 App 并输入对应手机号即可完成解锁')
            .fontSize(11)
            .fontColor('#66FFFFFF')
            .textAlign(TextAlign.Center)
            .padding({ left: 32, right: 32, bottom: 24 })
            .opacity(this.pageOpacity)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
    .opacity(this.pageOpacity)
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.EaseInOut })
      .opacity(0)
    PageTransitionExit({ duration: 300, curve: Curve.EaseInOut })
      .opacity(0)
  }

}
