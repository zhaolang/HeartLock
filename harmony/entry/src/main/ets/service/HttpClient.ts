import { http } from '@kit.NetworkKit';
import networkUtil from '../util/NetworkUtil';

class HttpClient {
  private baseUrl: string = 'http://47.97.44.109:8081/v1';
  private token: string = '';
  private onUnauthorized?: () => void;

  /**
   * 设置未授权回调（Token 过期时调用）
   */
  setUnauthorizedCallback(callback: () => void): void {
    this.onUnauthorized = callback;
  }

  setToken(token: string): void {
    this.token = token;
    AppStorage.setOrCreate('auth_token', token);
  }

  clearToken(): void {
    this.token = '';
    AppStorage.setOrCreate('auth_token', '');
  }

  loadToken(): void {
    const stored = AppStorage.get<string>('auth_token');
    // 过滤旧 Mock 模式的残留 token
    if (stored && stored !== '' && stored !== 'mock-token') {
      this.token = stored;
    } else {
      this.token = '';
    }
  }

  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    return headers;
  }

  async request<T>(method: http.RequestMethod, path: string, body?: object): Promise<T> {
    // Interaction.md 6.2: 网络不可用时提前拒绝
    if (!networkUtil.connected) {
      throw { code: -3, message: '当前网络不可用' };
    }

    this.loadToken();
    const url = this.baseUrl + path;

    return new Promise<T>((resolve, reject) => {
      const req = http.createHttp();
      const options: http.HttpRequestOptions = {
        method: method,
        header: this.getHeaders(),
        connectTimeout: 10000,
        readTimeout: 10000,
        extraData: body ? JSON.stringify(body) : undefined,
      };

      req.request(url, options).then((res) => {
        req.destroy();
        if (res.responseCode === 200 || res.responseCode === 201) {
          try {
            const json = JSON.parse(res.result as string);
            if (json.code === 0) {
              resolve(json.data as T);
            } else {
              // Token 过期处理
              if (json.code === 40002) {
                this.handleUnauthorized();
              }
              reject({ code: json.code, message: json.message });
            }
          } catch {
            reject({ code: -1, message: '解析响应失败' });
          }
        } else if (res.responseCode === 401) {
          // HTTP 401 也触发未授权处理
          this.handleUnauthorized();
          reject({ code: 40002, message: '登录已过期，请重新登录' });
        } else {
          reject({ code: res.responseCode, message: `HTTP ${res.responseCode}` });
        }
      }).catch((err) => {
        req.destroy();
        reject({ code: -2, message: '网络请求失败', detail: err });
      });
    });
  }

  /**
   * 处理未授权（Token 过期）
   */
  private handleUnauthorized(): void {
    this.clearToken();
    if (this.onUnauthorized) {
      this.onUnauthorized();
    }
  }

  get<T>(path: string): Promise<T> {
    return this.request<T>(http.RequestMethod.GET, path);
  }

  post<T>(path: string, body: object): Promise<T> {
    return this.request<T>(http.RequestMethod.POST, path, body);
  }

  patch<T>(path: string, body?: object): Promise<T> {
     // 使用 POST 替代 PATCH（@ohos.net.http.RequestMethod 不支持 PATCH）
     return this.request<T>(http.RequestMethod.POST, path, body);
  }

  delete<T>(path: string, body?: object): Promise<T> {
    return this.request<T>(http.RequestMethod.DELETE, path, body);
  }
}

const httpClient = new HttpClient();
export default httpClient;
