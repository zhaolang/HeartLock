/**
 * 导航工具
 * 统一管理页面路由，避免直接操作 AppStorage('context')
 */
import { router } from '@kit.ArkUI';

export class Navigation {
  /**
   * 推入页面
   */
  static push(url: string, params?: Record<string, Object>): void {
    try {
      router.pushUrl({ url, params });
    } catch (e) {
      console.error(`Navigation.push failed: ${url}`, JSON.stringify(e));
    }
  }

  /**
   * 替换页面（不保留回退栈）
   */
  static replace(url: string, params?: Record<string, Object>): void {
    try {
      router.replaceUrl({ url, params });
    } catch (e) {
      console.error(`Navigation.replace failed: ${url}`, JSON.stringify(e));
    }
  }

  /**
   * 返回上一页
   */
  static back(): void {
    try {
      router.back();
    } catch (e) {
      console.error('Navigation.back failed', JSON.stringify(e));
    }
  }

  /**
   * 获取页面参数
   */
  static getParams(): Record<string, Object> {
    try {
      return router.getParams() as Record<string, Object>;
    } catch {
      return {};
    }
  }
}
