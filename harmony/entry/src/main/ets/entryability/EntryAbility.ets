import { AbilityConstant, UIAbility, Want, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { IBestInit } from '@ibestservices/ibest-ui';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0001, 'EntryAbility', 'onCreate');
  }

  onDestroy(): void {
    hilog.info(0x0001, 'EntryAbility', 'onDestroy');
  }

 onWindowStageCreate(windowStage: window.WindowStage): void {
    // 配置窗口样式
    windowStage.getMainWindow((err, win) => {
      if (!err) {
        // 深色主题：状态栏白色文字
        win.setWindowLayoutFullScreen(false);
        win.setWindowSystemBarEnable(['status', 'navigation']);
        win.setWindowSystemBarProperties({
          statusBarContentColor: '#FFFFFF',
          navigationBarContentColor: '#FFFFFF',
          statusBarColor: '#0D0D0D',
          navigationBarColor: '#0D0D0D',
        }).catch(() => {});
      }
    });

    windowStage.loadContent('pages/SplashPage', (err) => {
      if (err && err.code) {
        hilog.error(0x0001, 'EntryAbility',
          'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0001, 'EntryAbility', 'Succeeded in loading content');
      // IBest-UI 初始化：必须在 loadContent 之后，此时 UIContext 才可用
      IBestInit(windowStage, this.context as common.UIAbilityContext);
    });
  }

  onForeground(): void {
    hilog.info(0x0001, 'EntryAbility', 'onForeground');
  }

  onBackground(): void {
    hilog.info(0x0001, 'EntryAbility', 'onBackground');
  }
}
