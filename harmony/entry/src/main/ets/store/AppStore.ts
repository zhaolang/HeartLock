export class AppStore {
  // User state
  @StorageLink('auth_token') token: string = '';
  @StorageLink('phone_authorized') phoneAuthorized: boolean = false;
  @StorageLink('user_info') userInfoStr: string = '';

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

  navigateTo(url: string, context?: object): void {
    try {
      const ctx = AppStorage.get<object>('context') as any;
      if (ctx) {
        ctx.router.pushUrl({ url: url });
      }
    } catch (err) {
      console.error('Navigation failed', JSON.stringify(err));
    }
  }

  navigateBack(): void {
    try {
      const ctx = AppStorage.get<object>('context') as any;
      if (ctx) {
        ctx.router.back();
      }
    } catch (err) {
      console.error('Navigate back failed', JSON.stringify(err));
    }
  }
}

const appStore = new AppStore();
export default appStore;
