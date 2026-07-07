import { LockItem, LockStatus } from '../model/Lock';
import lockService from '../service/LockService';

@Entry
@Component
struct LockDetailPage {
  @State lockItem: LockItem | null = null;
  @State showConfirmRevoke: boolean = false;
  @State showConfirmDestroy: boolean = false;

  aboutToAppear(): void {
    const ctx = AppStorage.get<object>('context') as any;
    const params = ctx?.router?.getParams?.();
    const lockId = params?.['lockId'];
    if (lockId) {
      this.loadDetail(lockId as string);
    }
  }

  loadDetail(id: string): void {
    lockService.getLockDetail(id).then((lock) => {
      this.lockItem = lock;
    }).catch(() => {
      // Handle error
    });
  }

  handleRevoke(): void {
    AlertDialog.show({
      title: '确定撤回这份喜欢？',
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
    AlertDialog.show({
      title: '确定永久删除？此操作不可恢复',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认删除',
        action: () => {
          if (this.lockItem) {
            lockService.destroyLock(this.lockItem.id).then(() => {
              try {
                const ctx = AppStorage.get<object>('context') as any;
                if (ctx) ctx.router.back();
              } catch (e) {}
            });
          }
        }
      }
    });
  }

  handleGenerateCard(): void {
    if (this.lockItem) {
      try {
        const ctx = AppStorage.get<object>('context') as any;
        if (ctx) {
          ctx.router.pushUrl({
            url: 'pages/InvitationCardPage',
            params: { lockId: this.lockItem.id }
          });
        }
      } catch (e) {}
    }
  }

  @Builder
  waitingView(): void {
    Column({ space: 24 }) {
      Text('🔒')
        .fontSize(64)
        .opacity(0.9)

      Text('等待中')
        .fontSize(18)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)

      Text(this.lockItem?.toPhonePrefix ?? '')
        .fontSize(20)
        .fontColor('#D4A574')
        .fontWeight(FontWeight.Bold)

      Text(`已经等待 ${this.lockItem?.waitingDays ?? 0} 天`)
        .fontSize(14)
        .fontColor('#66FFFFFF')

      // Action buttons
      Column({ space: 12 }) {
        Button('生成邀请卡片')
          .width('80%')
          .height(48)
          .backgroundColor('#D4A574')
          .fontColor('#0D0D0D')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .borderRadius(24)
          .onClick(() => this.handleGenerateCard())

        Button('撤回')
          .width('80%')
          .height(44)
          .backgroundColor('transparent')
          .fontColor('#FF4444')
          .fontSize(16)
          .border({ width: 1, color: '#FF4444' })
          .borderRadius(22)
          .onClick(() => this.handleRevoke())
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  matchedView(): void {
    Column({ space: 20 }) {
      Text('🔓')
        .fontSize(64)

      Text('心锁已打开')
        .fontSize(18)
        .fontColor('#D4A574')
        .fontWeight(FontWeight.Bold)

      Text(this.lockItem?.matchedAt?.slice(0, 10) ?? '')
        .fontSize(13)
        .fontColor('#66FFFFFF')

      // Their words
      Column({ space: 8 }) {
        Text('对方写给你的话')
          .fontSize(13)
          .fontColor('#99FFFFFF')

        Text(this.lockItem?.theirWords ?? '打开心锁的那一刻，才有答案。')
          .fontSize(15)
          .fontColor('#FFFFFF')
          .lineHeight(24)
          .padding(16)
          .backgroundColor('#1A1A1A')
          .borderRadius(12)
          .width('100%')
      }
      .width('100%')

      // My words
      Column({ space: 8 }) {
        Text('你当初写的话')
          .fontSize(13)
          .fontColor('#99FFFFFF')

        Text(this.lockItem?.myWords ?? '我喜欢你。')
          .fontSize(15)
          .fontColor('#99FFFFFF')
          .lineHeight(24)
          .padding(16)
          .backgroundColor('#1A1A1A')
          .borderRadius(12)
          .width('100%')
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  revokedView(): void {
    Column({ space: 24 }) {
      Text('🔒')
        .fontSize(64)
        .opacity(0.4)

      Text('已撤回')
        .fontSize(18)
        .fontColor('#66FFFFFF')

      Text(this.lockItem?.toPhonePrefix ?? '')
        .fontSize(18)
        .fontColor('#66FFFFFF')

      Button('永久删除')
        .width('80%')
        .height(44)
        .backgroundColor('transparent')
        .fontColor('#FF4444')
        .fontSize(16)
        .border({ width: 1, color: '#FF4444' })
        .borderRadius(22)
        .onClick(() => this.handleDestroy())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      // Back button + title
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
        Text('心锁详情')
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
        Column() {
          if (this.lockItem?.status === LockStatus.WAITING) {
            this.waitingView()
          } else if (this.lockItem?.status === LockStatus.MATCHED) {
            this.matchedView()
          } else if (this.lockItem?.status === LockStatus.REVOKED) {
            this.revokedView()
          }
        }
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
}
