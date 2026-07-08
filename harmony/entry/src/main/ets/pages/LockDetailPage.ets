import { Navigation } from '../ui-kit/Navigation';
import { LockItem, LockStatus } from '../model/Lock';
import lockService from '../service/LockService';
import { PageHeader } from '../ui-kit/PageHeader';
import { vibrator } from '@kit.SensorServiceKit';

@Entry
@Component
struct LockDetailPage {
  @State lockItem: LockItem | null = null;
  @State pageOpacity: number = 0;

  aboutToAppear(): void {
    const params = Navigation.getParams();
    const lockId = params?.['lockId'] as string;
    if (lockId) {
      this.loadDetail(lockId);
    }
    animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.pageOpacity = 1;
    });
  }

  loadDetail(id: string): void {
    lockService.getLockDetail(id).then((lock) => {
      this.lockItem = lock;
    }).catch(() => {});
  }

  handleRevoke(): void {
    try { vibrator.startVibration({ type: 'preset', effectId: 'haptic.medium' }, { usage: 'alarm' }, (e: Error | null) => {}); } catch (_) {}
    AlertDialog.show({
      title: '确定撤回这份喜欢？',
      message: '撤回后仍可查看历史记录',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认撤回',
        action: () => {
          if (this.lockItem) {
            lockService.revokeLock(this.lockItem.id).then(() => {
              this.loadDetail(this.lockItem!.id);
            });
          }
        }
      }
    });
  }

  handleDestroy(): void {
    try { vibrator.startVibration({ type: 'preset', effectId: 'haptic.medium' }, { usage: 'alarm' }, (e: Error | null) => {}); } catch (_) {}
    AlertDialog.show({
      title: '确定永久删除？此操作不可恢复',
      message: '',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认删除',
        action: () => {
          if (this.lockItem) {
            lockService.destroyLock(this.lockItem.id).then(() => {
              Navigation.back();
            });
          }
        }
      }
    });
  }

  handleGenerateCard(): void {
    try { vibrator.startVibration({ type: 'preset', effectId: 'haptic.medium' }, { usage: 'alarm' }, (e: Error | null) => {}); } catch (_) {}
    if (this.lockItem) {
      lockService.generateInvitationCard(this.lockItem.id).then((cardRes) => {
        const p1: Record<string, Object> = {};
p1["lockId"] = this.lockItem!.id;
p1["cardUrl"] = cardRes.cardUrl;
        Navigation.push('pages/InvitationCardPage', p1);
      }).catch(() => {
        const p2: Record<string, Object> = {};
p2["lockId"] = this.lockItem!.id;
        Navigation.push('pages/InvitationCardPage', p2);
      });
    }
  }

  @Builder
  waitingView(): void {
    Column({ space: 24 }) {
      Blank().layoutWeight(1)

      // ── 状态图标 ──
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(100)
          .height(100)
          .fill('#18D4A574')

        Image($rawfile('icons/lock-closed.svg'))
          .width(52)
          .height(52)
          .objectFit(ImageFit.Contain)
          .opacity(0.85)
      }

      // ── 状态文字 ──
      Text('等待中')
        .fontSize(20)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)

      // ── 对方手机号脱敏 ──
      Text(this.lockItem?.toPhonePrefix ?? '')
        .fontSize(24)
        .fontColor('#D4A574')
        .fontWeight(FontWeight.Bold)
        .letterSpacing(2)

      Text(`已经等待 ${this.lockItem?.waitingDays ?? 0} 天`)
        .fontSize(14)
        .fontColor('#66FFFFFF')

      Blank().layoutWeight(1)

      // ── 操作按钮 ──
      Column({ space: 12 }) {
        Button('生成邀请卡片')
          .width('80%')
          .height(48)
          .backgroundColor('#D4A574')
          .fontColor('#0D0D0D')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .borderRadius(24)
          .shadow({ radius: 12, color: '#30D4A574', offsetX: 0, offsetY: 4 })
          .onClick(() => this.handleGenerateCard())

        Button('撤回')
          .width('80%')
          .height(44)
          .backgroundColor('transparent')
          .fontColor('#FF4444')
          .fontSize(16)
          .border({ width: 1, color: '#FF444466' })
          .borderRadius(22)
          .onClick(() => this.handleRevoke())
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: 40 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  matchedView(): void {
    Column({ space: 20 }) {
      Blank().layoutWeight(1)

      // ── 打开锁图标 ──
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(100)
          .height(100)
          .fill('#26D4A574')

        Image($rawfile('icons/lock-open.svg'))
          .width(52)
          .height(52)
          .objectFit(ImageFit.Contain)
      }

      Text('心锁已打开')
        .fontSize(22)
        .fontColor('#D4A574')
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1)

      Text(this.lockItem?.matchedAt?.slice(0, 10) ?? '')
        .fontSize(13)
        .fontColor('#66FFFFFF')

      Blank().layoutWeight(0.5)

      // ── 对方的话 ──
      Column({ space: 10 }) {
        Row({ space: 6 }) {
          Image($rawfile('icons/heart.svg'))
            .width(14)
            .height(14)
            .objectFit(ImageFit.Contain)
          Text('对方写给你的话')
            .fontSize(13)
            .fontColor('#99FFFFFF')
        }
        .alignItems(VerticalAlign.Center)

        Text(this.lockItem?.theirWords ?? '打开心锁的那一刻，才有答案。')
          .fontSize(15)
          .fontColor('#FFFFFF')
          .lineHeight(24)
          .padding(16)
          .backgroundColor('#1A1A1A')
          .borderRadius(12)
          .width('100%')
          .border({ width: 1, color: '#2A2A2A' })
      }
      .width('100%')

      // ── 你当初的话 ──
      Column({ space: 10 }) {
        Text('你当初写的话')
          .fontSize(13)
          .fontColor('#66FFFFFF')

        Text(this.lockItem?.myWords ?? '我喜欢你。')
          .fontSize(15)
          .fontColor('#99FFFFFF')
          .lineHeight(24)
          .padding(16)
          .backgroundColor('#151515')
          .borderRadius(12)
          .width('100%')
          .border({ width: 1, color: '#2A2A2A' })
      }
      .width('100%')

      Blank().layoutWeight(0.5)
    }
    .width('100%')
    .padding({ bottom: 40 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  revokedView(): void {
    Column({ space: 24 }) {
      Blank().layoutWeight(1)

      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(100)
          .height(100)
          .fill('#1AFFFFFF')

        Image($rawfile('icons/lock-closed.svg'))
          .width(52)
          .height(52)
          .objectFit(ImageFit.Contain)
          .opacity(0.3)
      }

      Text('已撤回')
        .fontSize(20)
        .fontColor('#66FFFFFF')

      Text(this.lockItem?.toPhonePrefix ?? '')
        .fontSize(18)
        .fontColor('#66FFFFFF')

      Blank().layoutWeight(1)

      Button('永久删除')
        .width('80%')
        .height(44)
        .backgroundColor('transparent')
        .fontColor('#FF4444')
        .fontSize(16)
        .border({ width: 1, color: '#FF444466' })
        .borderRadius(22)
        .onClick(() => this.handleDestroy())
        .margin({ bottom: 40 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      PageHeader({ title: '心锁详情' })

      // ── 内容区 ──
      Scroll() {
        Column() {
          if (this.lockItem?.status === LockStatus.WAITING) {
            this.waitingView()
          } else if (this.lockItem?.status === LockStatus.MATCHED) {
            this.matchedView()
          } else if (this.lockItem?.status === LockStatus.REVOKED) {
            this.revokedView()
          }
        }
        .opacity(this.pageOpacity)
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding(24)
      }
      .layoutWeight(1)
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
