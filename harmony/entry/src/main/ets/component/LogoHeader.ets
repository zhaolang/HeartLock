import { Navigation } from '../ui-kit/Navigation';

@Component
export struct LogoHeader {
  private showProfile: boolean = true;

  build() {
    Row() {
      // Left: brand logo + name
      Row({ space: 10 }) {
        Image($rawfile('icons/lock-closed.svg'))
          .width(22)
          .height(22)
          .objectFit(ImageFit.Contain)
          .opacity(0.85)

        Text('心锁')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .letterSpacing(2)
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      // Right: profile icon
      if (this.showProfile) {
        Stack({ alignContent: Alignment.Center }) {
         Circle()
           .width(32)
           .height(32)
           .fill('#1AFFFFFF')

          Text('我')
            .fontSize(13)
            .fontColor('#CCFFFFFF')
            .fontWeight(FontWeight.Medium)
       }
        .onClick(() => {
         Navigation.push('pages/ProfilePage');
       })
     }
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 20 })
  }
}
