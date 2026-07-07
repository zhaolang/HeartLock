import { http } from '@kit.NetworkKit';

class HttpClient {
  private baseUrl: string = 'https://api.heartlock.app/v1';
  private token: string = '';

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
    if (stored) {
      this.token = stored;
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
              reject({ code: json.code, message: json.message });
            }
          } catch {
            reject({ code: -1, message: '解析响应失败' });
          }
        } else {
          reject({ code: res.responseCode, message: `HTTP ${res.responseCode}` });
        }
      }).catch((err) => {
        req.destroy();
        reject({ code: -2, message: '网络请求失败', detail: err });
      });
    });
  }

  get<T>(path: string): Promise<T> {
    return this.request<T>(http.RequestMethod.GET, path);
  }

  post<T>(path: string, body: object): Promise<T> {
    return this.request<T>(http.RequestMethod.POST, path, body);
  }

  patch<T>(path: string, body?: object): Promise<T> {
    return this.request<T>(http.RequestMethod.PATCH, path, body);
  }

  delete<T>(path: string, body?: object): Promise<T> {
    return this.request<T>(http.RequestMethod.DELETE, path, body);
  }
}

const httpClient = new HttpClient();
export default httpClient;
