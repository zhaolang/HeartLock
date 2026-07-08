import { Navigation } from '../ui-kit/Navigation';
import { IBestInit } from '@ibestservices/ibest-ui';
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
  @State staggerItems: number[] = [];
  @State private animGeneration: number = 0;

  aboutToAppear(): void {
    IBestInit();
    this.loadLocks();
  }

  loadLocks(): void {
    this.isRefreshing = true;
    const gen = ++this.animGeneration;

    lockService.getLocks().then((res) => {
      if (gen !== this.animGeneration) {
        this.isRefreshing = false;
        return;
      }
      this.lockList = res.locks;
      this.currentCount = res.currentCount;
      this.maxCount = res.maxCount;
      this.showEmptyState = res.locks.length === 0;
      this.isRefreshing = false;

      // 重置交错动画
      this.staggerItems = [];
      setTimeout(() => {
        if (gen !== this.animGeneration) return;
        const indices: number[] = [];
        for (let i = 0; i < this.lockList.length; i++) {
          setTimeout(() => {
            if (gen !== this.animGeneration) return;
            indices.push(i);
            this.staggerItems = [...indices];
          }, i * 80);
        }
      }, 100);
    }).catch(() => {
      this.isRefreshing = false;
    });
  }

  @Builder
  emptyState(): void {
    Column({ space: 20 }) {
      Column().height('20%')

      // 锁图标
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(90)
          .height(90)
          .fill('#18D4A574')

        Image($rawfile('icons/lock-closed.svg'))
          .width(44)
          .height(44)
          .objectFit(ImageFit.Contain)
          .opacity(0.5)
      }

      Column({ space: 8 }) {
        Text('尚未收藏任何喜欢')
          .fontSize(18)
          .fontColor('#99FFFFFF')
          .fontWeight(FontWeight.Medium)

        Text('第一份喜欢，值得好好想想')
          .fontSize(14)
          .fontColor('#66FFFFFF')
          .lineHeight(20)

        // ── 空状态 CTA 按钮 ──
        Button('放进第一份喜欢')
          .width(200)
          .height(46)
          .backgroundColor('#D4A574')
          .fontColor('#0D0D0D')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .borderRadius(23)
          .margin({ top: 20 })
          .onClick(() => Navigation.push('pages/CreateLockPage'))
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  onPageShow(): void {
    this.loadLocks();
  }

  build() {
    Column() {
      // ── 顶部品牌 Header ──
      LogoHeader()

      // ── 状态栏: 心锁计数 + 创建按钮 ──
      Row({ space: 8 }) {
        Row({ space: 6 }) {
          Text('❤️')
            .fontSize(16)
          Text(`心锁 ${this.currentCount} / ${this.maxCount}`)
            .fontSize(16)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
        }
        .alignItems(VerticalAlign.Center)

        Blank()

        Button() {
          Text('+')
            .fontSize(22)
            .fontColor('#D4A574')
        }
        .width(36)
        .height(36)
        .backgroundColor('#2A2A2A')
        .borderRadius(18)
        .onClick(() => {
          Navigation.push('pages/CreateLockPage');
        })
      }
      .padding({ left: 20, right: 20, bottom: 14, top: 6 })

      // ── 内容区 ──
      if (this.showEmptyState) {
        Scroll() {
          this.emptyState()
        }
        .layoutWeight(1)
        .scrollable(ScrollDirection.Vertical)
        .edgeEffect(EdgeEffect.Spring)
      } else {
        List({ space: 12 }) {
          ForEach(this.lockList, (lock: LockItem, idx?: number) => {
            ListItem() {
              LockCard({ lockItem: lock })
                .opacity(this.staggerItems.includes((idx as number)) ? 1 : 0)
                .offset({
                  y: this.staggerItems.includes((idx as number)) ? 0 : 30
                })
                .animation({
                  duration: 400,
                  curve: Curve.EaseOut,
                  delay: (idx as number) * 80
                })
            }
            .onClick(() => {
              const params: Record<string, Object> = {};
params["lockId"] = lock.id;
              Navigation.push('pages/LockDetailPage', params);
            })
          }, (lock: LockItem) => lock.id)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 8 })
        .edgeEffect(EdgeEffect.Spring)
      }
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
