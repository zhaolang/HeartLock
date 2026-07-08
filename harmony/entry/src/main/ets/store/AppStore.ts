import { router } from '@kit.ArkUI';

export class AppStore {
   get token(): string {
     return AppStorage.get<string>('auth_token') ?? '';
   }
   set token(val: string) {
     AppStorage.setOrCreate('auth_token', val);
   }
 
   get phoneAuthorized(): boolean {
     return AppStorage.get<boolean>('phone_authorized') ?? false;
   }
   set phoneAuthorized(val: boolean) {
     AppStorage.setOrCreate('phone_authorized', val);
   }
 
   get userInfoStr(): string {
     return AppStorage.get<string>('user_info') ?? '';
   }
   set userInfoStr(val: string) {
     AppStorage.setOrCreate('user_info', val);
   }

  get isLoggedIn(): boolean {
    return this.token !== '';
  }

  get userInfo(): { id: string; heartLockCount: number; maxHeartLock: number; matchedCount: number; revokedCount: number } | null {
    if (!this.userInfoStr) return null;
    try {
      return JSON.parse(this.userInfoStr);
    } catch {
      return null;
    }
  }

  get heartLockCount(): number {
    return this.userInfo?.heartLockCount ?? 0;
  }

  get maxHeartLock(): number {
    return this.userInfo?.maxHeartLock ?? 3;
  }

  get countDisplay(): string {
    return `心锁 ${this.heartLockCount} / ${this.maxHeartLock}`;
  }

  navigateTo(url: string, params?: Record<string, Object>): void {
    try {
      router.pushUrl({ url, params });
    } catch (err) {
      console.error('Navigation failed', JSON.stringify(err));
    }
  }

  navigateBack(): void {
    try {
      router.back();
    } catch (err) {
      console.error('Navigate back failed', JSON.stringify(err));
    }
  }
}

const appStore = new AppStore();
export default appStore;
