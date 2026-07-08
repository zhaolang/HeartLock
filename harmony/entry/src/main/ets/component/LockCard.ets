import { LockItem, LockStatus } from '../model/Lock';

@Component
export struct LockCard {
  @Prop lockItem: LockItem = {
    id: '', status: LockStatus.WAITING, toPhonePrefix: '',
    createdAt: '', waitingDays: 0, canRevoke: false, canDestroy: false,
    hasInvitationCard: false
  };
  @State isPressed: boolean = false;

  build() {
    Column() {
      Row({ space: 14 }) {
        // ── 状态图标 ──
        Stack({ alignContent: Alignment.Center }) {
          if (this.lockItem.status === LockStatus.MATCHED) {
            Circle()
              .width(36)
              .height(36)
              .fill('#24D4A574')
            Image($rawfile('icons/lock-open.svg'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
          } else if (this.lockItem.status === LockStatus.REVOKED) {
            Circle()
              .width(36)
              .height(36)
              .fill('#1AFFFFFF')
            Image($rawfile('icons/lock-closed.svg'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
              .opacity(0.4)
          } else {
            Circle()
              .width(36)
              .height(36)
              .fill('#2A2A2A')
            Image($rawfile('icons/lock-closed.svg'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
          }
        }

        // ── 手机号 + 时间 ──
        Column({ space: 4 }) {
          Text(this.lockItem.toPhonePrefix)
            .fontSize(16)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)

          if (this.lockItem.status === LockStatus.WAITING) {
            Text(`等待 ${this.lockItem.waitingDays} 天 · ${this.lockItem.createdAt.slice(0, 10)}`)
              .fontSize(13)
              .fontColor('#66FFFFFF')
          } else {
            Text(this.lockItem.createdAt.slice(0, 10))
              .fontSize(13)
              .fontColor('#99FFFFFF')
          }
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // ── 状态标签 ──
        Text(this.statusLabel())
          .fontSize(12)
          .fontColor(this.statusColor())
          .backgroundColor(this.statusBgColor())
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .borderRadius(12)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')

      // ── 等待/匹配详情行 ──
      if (this.lockItem.status === LockStatus.MATCHED) {
        Row({ space: 6 }) {
          Image($rawfile('icons/heart.svg'))
            .width(12)
            .height(12)
            .objectFit(ImageFit.Contain)

          Text(this.lockItem.contentPreview ?? '心锁已打开')
            .fontSize(13)
            .fontColor('#D4A574')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .margin({ top: 10 })
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.cardBgColor())
    .borderRadius(12)
    .border({ width: this.cardBorderWidth(), color: this.cardBorderColor() })
    .opacity(this.isPressed ? 0.85 : 1)
    .scale({ x: this.isPressed ? 0.98 : 1, y: this.isPressed ? 0.98 : 1 })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .transition({
      type: TransitionType.Insert,
      opacity: 0,
      translate: { y: 20 }
    })
  }

  statusLabel(): string {
    switch (this.lockItem.status) {
      case LockStatus.MATCHED: return '已解锁';
      case LockStatus.REVOKED: return '已撤回';
      default: return '等待中';
    }
  }

  statusColor(): ResourceColor {
    switch (this.lockItem.status) {
      case LockStatus.MATCHED: return '#D4A574';
      case LockStatus.REVOKED: return '#66FFFFFF';
      default: return '#FFFFFF';
    }
  }

  statusBgColor(): ResourceColor {
    switch (this.lockItem.status) {
      case LockStatus.MATCHED: return '#26D4A574';
      case LockStatus.REVOKED: return '#1AFFFFFF';
      default: return '#2A2A2A';
    }
  }

  cardBgColor(): ResourceColor {
    return this.lockItem.status === LockStatus.REVOKED ? '#151515' : '#1A1A1A';
  }

  cardBorderWidth(): number {
    return this.lockItem.status === LockStatus.MATCHED ? 1 : 0;
  }

  cardBorderColor(): ResourceColor {
    return this.lockItem.status === LockStatus.MATCHED ? '#D4A574' : '#00000000';
  }
}
