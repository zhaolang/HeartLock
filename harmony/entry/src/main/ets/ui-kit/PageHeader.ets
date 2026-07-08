import { Navigation } from './Navigation';

/**
 * 通用页面头部：返回按钮 + 标题
 */
@Component
export struct PageHeader {
  title: string = '';
  private showBack: boolean = true;
  private onBack?: () => void;

  build() {
    Row() {
      // Back button
      if (this.showBack) {
        Button() {
          Text('←')
            .fontSize(22)
            .fontColor('#FFFFFF')
        }
        .width(36)
        .height(36)
        .backgroundColor('transparent')
        .onClick(() => {
          if (this.onBack) {
            this.onBack();
          } else {
            Navigation.back();
          }
        })
      }

      Blank()

      // Title
      Text(this.title)
        .fontSize(18)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)

      Blank()

      // Right spacer (balance)
      Row()
        .width(36)
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 20 })
    .backgroundColor('#0D0D0D')
  }
}
