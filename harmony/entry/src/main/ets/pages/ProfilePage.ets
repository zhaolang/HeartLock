import { Navigation } from '../ui-kit/Navigation';
import authService from '../service/AuthService';
import { PageHeader } from '../ui-kit/PageHeader';

interface UserProfileInfo {
  id: string
  heartLockCount: number
  maxHeartLock: number
  matchedCount: number
  revokedCount: number
}

@Entry
@Component
struct ProfilePage {
  @StorageLink('phone_authorized') phoneAuthorized: boolean = false;
  @StorageLink('user_info') userInfoStr: string = '';
  @State pageOpacity: number = 0;
  @State statsAnimOpacity: number = 0;
  @State statsAnimOffset: number = 20;

  aboutToAppear(): void {
    animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.pageOpacity = 1;
    });

    setTimeout(() => {
      animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.statsAnimOpacity = 1;
        this.statsAnimOffset = 0;
      });
    }, 200);
  }

  get userInfo(): UserProfileInfo | null {
    if (!this.userInfoStr) return null;
    try {
      return JSON.parse(this.userInfoStr);
    } catch {
      return null;
    }
  }

  handleLogout(): void {
    AlertDialog.show({
      title: '确定注销？所有数据将永久删除',
      message: '',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认注销',
        action: () => {
          AlertDialog.show({
            title: '再次确认？此操作不可撤销',
            message: '',
            primaryButton: {
              value: '取消',
              action: () => {}
            },
            secondaryButton: {
              value: '确认注销',
              action: () => {
                authService.deleteAccount().then(() => {
                  Navigation.replace('pages/LoginPage');
                });
              }
            }
          });
        }
      }
    });
  }

  build() {
    Column() {
      PageHeader({ title: '个人中心' })

      Scroll() {
        Column({ space: 0 }) {
          // ── 头像 & 信息 ──
          Column({ space: 14 }) {
            Stack({ alignContent: Alignment.Center }) {
              Circle()
                .width(72)
                .height(72)
                .fill('#18D4A574')

              Image($rawfile('icons/lock-closed.svg'))
                .width(36)
                .height(36)
                .objectFit(ImageFit.Contain)
                .opacity(0.6)
            }

            Text('心锁用户')
              .fontSize(20)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)

            if (!this.phoneAuthorized) {
              Text('未授权手机号')
                .fontSize(13)
                .fontColor('#FF4444')
                .margin({ top: 4 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 28, bottom: 36 })

          // ── 统计卡片 ──
          Row({ space: 0 }) {
            this.statItem('心锁', String(this.userInfo?.heartLockCount ?? 0))
            Column().width(1).height(36).backgroundColor('#2A2A2A')
            this.statItem('已解锁', String(this.userInfo?.matchedCount ?? 0))
            Column().width(1).height(36).backgroundColor('#2A2A2A')
            this.statItem('已撤回', String(this.userInfo?.revokedCount ?? 0))
          }
          .width('90%')
          .height(88)
          .backgroundColor('#1A1A1A')
          .borderRadius(12)
          .justifyContent(FlexAlign.Center)
          .border({ width: 1, color: '#2A2A2A' })
          .opacity(this.statsAnimOpacity)
          .offset({ y: this.statsAnimOffset })

          // ── 间距 ──
          Column().height(48)

          // ── 操作区 ──
          Column({ space: 12 }) {
            Column({ space: 8 }) {
              Divider()
                .width('90%')
                .color('#2A2A2A')
                .margin({ bottom: 8 })

              Button() {
                Row({ space: 8 }) {
                  Text('⨯')
                    .fontSize(16)
                    .fontColor('#FF4444')
                  Text('注销账户')
                    .fontSize(16)
                    .fontColor('#FF4444')
                }
                .alignItems(VerticalAlign.Center)
                .justifyContent(FlexAlign.Center)
              }
              .width('90%')
              .height(48)
              .backgroundColor('transparent')
              .border({ width: 1, color: '#FF444433' })
              .borderRadius(12)
              .onClick(() => this.handleLogout())
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)

            Text('注销后所有数据将不可恢复')
              .fontSize(12)
              .fontColor('#66FFFFFF')
              .textAlign(TextAlign.Center)
              .opacity(0.5)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .opacity(this.statsAnimOpacity)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
    .opacity(this.pageOpacity)
  }

  @Builder
  statItem(label: string, value: string): void {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(26)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontSize(13)
        .fontColor('#66FFFFFF')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.EaseInOut })
      .opacity(0)
    PageTransitionExit({ duration: 300, curve: Curve.EaseInOut })
      .opacity(0)
  }

}
