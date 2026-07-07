import authService from '../service/AuthService';

@Entry
@Component
struct ProfilePage {
  @State showLogoutConfirm: boolean = false;
  @StorageLink('phone_authorized') phoneAuthorized: boolean = false;

  handleLogout(): void {
    AlertDialog.show({
      title: '确定注销？所有数据将永久删除',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认注销',
        action: () => {
          // Second confirmation
          AlertDialog.show({
            title: '再次确认？此操作不可撤销',
            primaryButton: {
              value: '取消',
              action: () => {}
            },
            secondaryButton: {
              value: '确认注销',
              action: () => {
                authService.deleteAccount().then(() => {
                  try {
                    const ctx = AppStorage.get<object>('context') as any;
                    if (ctx) {
                      ctx.router.replaceUrl({ url: 'pages/LoginPage' });
                    }
                  } catch (e) {}
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
      // Header
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
        Text('个人中心')
          .fontSize(18)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
        Blank()
        Row().width(36)
      }
      .width('100%')
      .padding({ left: 8, right: 20, top: 8 })
      .height(48)

      Scroll() {
        Column({ space: 0 }) {
          // Avatar & info
          Column({ space: 12 }) {
            Column({ space: 8 }) {
              Image($r('app.media.app_icon'))
                .width(64)
                .height(64)
                .borderRadius(32)
                .backgroundColor('#2A2A2A')

              Text('心锁用户')
                .fontSize(18)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
            }

            if (!this.phoneAuthorized) {
              Text('未授权手机号')
                .fontSize(13)
                .fontColor('#FF4444')
                .margin({ top: 8 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 24, bottom: 32 })

          // Stats
          Row({ space: 0 }) {
            this.statItem('心锁', '0')
            this.statItem('已解锁', '0')
            this.statItem('已撤回', '0')
          }
          .width('90%')
          .height(80)
          .backgroundColor('#1A1A1A')
          .borderRadius(12)
          .justifyContent(FlexAlign.Center)

          // Spacer
          Column().height(40)

          // Logout button
          Button('注销账户')
            .width('90%')
            .height(48)
            .backgroundColor('transparent')
            .fontColor('#FF4444')
            .fontSize(16)
            .border({ width: 1, color: '#FF444433' })
            .borderRadius(12)
            .onClick(() => this.handleLogout())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
  }

  @Builder
  statItem(label: string, value: string): void {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(24)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontSize(13)
        .fontColor('#66FFFFFF')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}
