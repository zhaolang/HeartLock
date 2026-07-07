import { LockItem, LockStatus } from '../model/Lock';

@Component
export struct LockCard {
  private lockItem: LockItem = {
    id: '', status: LockStatus.WAITING, toPhonePrefix: '',
    createdAt: '', waitingDays: 0, canRevoke: false, canDestroy: false,
    hasInvitationCard: false
  };

  build() {
    Column() {
      Row({ space: 12 }) {
        // Status icon
        Text(this.statusIcon())
          .fontSize(24)

        Column({ space: 4 }) {
          Text(this.lockItem.toPhonePrefix)
            .fontSize(16)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)

          Text(this.lockItem.createdAt.slice(0, 10))
            .fontSize(13)
            .fontColor('#99FFFFFF')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // Status tag
        Text(this.statusLabel())
          .fontSize(13)
          .fontColor(this.statusColor())
          .backgroundColor(this.statusBgColor())
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
      }
      .width('100%')

      if (this.lockItem.status === LockStatus.WAITING) {
        Text(`已经等待 ${this.lockItem.waitingDays} 天`)
          .fontSize(13)
          .fontColor('#66FFFFFF')
          .margin({ top: 8 })
      }

      if (this.lockItem.status === LockStatus.MATCHED) {
        Text(this.lockItem.contentPreview ?? '心锁已打开')
          .fontSize(13)
          .fontColor('#D4A574')
          .margin({ top: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.cardBgColor())
    .borderRadius(12)
    .border({ width: this.borderWidth(), color: this.borderColor() })
  }

  statusIcon(): string {
    switch (this.lockItem.status) {
      case LockStatus.MATCHED: return '🔓';
      case LockStatus.REVOKED: return '🔒';
      default: return '🔒';
    }
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
      case LockStatus.MATCHED: return '#33D4A574';
      case LockStatus.REVOKED: return '#1AFFFFFF';
      default: return '#2A2A2A';
    }
  }

  cardBgColor(): ResourceColor {
    return this.lockItem.status === LockStatus.REVOKED ? '#151515' : '#1A1A1A';
  }

  borderWidth(): number {
    return this.lockItem.status === LockStatus.MATCHED ? 1 : 0;
  }

  borderColor(): ResourceColor {
    return this.lockItem.status === LockStatus.MATCHED ? '#D4A574' : '#00000000';
  }
}
