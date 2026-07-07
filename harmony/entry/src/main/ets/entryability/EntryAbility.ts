import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0001, 'EntryAbility', 'onCreate');
    AppStorage.setOrCreate('context', this.context);
  }

  onDestroy(): void {
    hilog.info(0x0001, 'EntryAbility', 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/SplashPage', (err) => {
      if (err.code) {
        hilog.error(0x0001, 'EntryAbility',
          'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0001, 'EntryAbility', 'Succeeded in loading content');
    });
  }

  onForeground(): void {
    hilog.info(0x0001, 'EntryAbility', 'onForeground');
  }

  onBackground(): void {
    hilog.info(0x0001, 'EntryAbility', 'onBackground');
  }
}
