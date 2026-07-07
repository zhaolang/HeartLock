import { LockItem, LockStatus } from '../model/Lock';
import { LockCard } from '../component/LockCard';
import { LogoHeader } from '../component/LogoHeader';
import lockService from '../service/LockService';

@Entry
@Component
struct HomePage {
  @State lockList: LockItem[] = [];
  @State currentCount: number = 0;
  @State maxCount: number = 3;
  @State isRefreshing: boolean = false;
  @State showEmptyState: boolean = true;

  aboutToAppear(): void {
    this.loadLocks();
  }

  loadLocks(): void {
    this.isRefreshing = true;
    lockService.getLocks().then((res) => {
      this.lockList = res.locks;
      this.currentCount = res.currentCount;
      this.maxCount = res.maxCount;
      this.showEmptyState = res.locks.length === 0;
      this.isRefreshing = false;
    }).catch(() => {
      this.isRefreshing = false;
    });
  }

  navigateToCreate(): void {
    try {
      const ctx = AppStorage.get<object>('context') as any;
      if (ctx) {
        ctx.router.pushUrl({ url: 'pages/CreateLockPage' });
      }
    } catch (e) {
      console.error('nav error', JSON.stringify(e));
    }
  }

  navigateToDetail(lock: LockItem): void {
    try {
      const ctx = AppStorage.get<object>('context') as any;
      if (ctx) {
        ctx.router.pushUrl({
          url: 'pages/LockDetailPage',
          params: { lockId: lock.id }
        });
      }
    } catch (e) {
      console.error('nav error', JSON.stringify(e));
    }
  }

  @Builder
  emptyState(): void {
    Column({ space: 16 }) {
      Text('🔒')
        .fontSize(56)
        .opacity(0.6)

      Text('尚未收藏任何喜欢')
        .fontSize(18)
        .fontColor('#99FFFFFF')

      Text('第一份喜欢，值得好好想想')
        .fontSize(14)
        .fontColor('#66FFFFFF')
    }
    .width('100%')
    .padding({ top: 80 })
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      // Header
      LogoHeader()

      // Status bar
      Row({ space: 8 }) {
        Text(`❤️ 心锁 ${this.currentCount} / ${this.maxCount}`)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)

        Blank()

        Button()
          .width(36)
          .height(36)
          .backgroundColor('#2A2A2A')
          .borderRadius(18)
          .onClick(() => this.navigateToCreate())
          .overlay({
            builder: () => Text('+')
              .fontSize(20)
              .fontColor('#D4A574')
          })
      }
      .padding({ left: 20, right: 20, bottom: 12 })

      // Content area
      if (this.showEmptyState) {
        Scroll() {
          this.emptyState()
        }
        .layoutWeight(1)
        .scrollable(ScrollDirection.Vertical)
      } else {
        List({ space: 12 }) {
          ForEach(this.lockList, (lock: LockItem) => {
            ListItem() {
              LockCard({ lockItem: lock })
            }
            .onClick(() => this.navigateToDetail(lock))
          }, (lock: LockItem) => lock.id)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
    .onPageShow(() => {
      this.loadLocks();
    })
  }
}
