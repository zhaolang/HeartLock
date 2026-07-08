import httpClient from './HttpClient';
import { AuthResponse, UserInfo } from '../model/User';

class AuthService {
  private mockUser: UserInfo = {
    id: 'mock-user-001',
    phoneAuthorized: true,
    heartLockCount: 0,
    maxHeartLock: 3,
    matchedCount: 0,
    revokedCount: 0,
  };

  get isLoggedIn(): boolean {
    const token = AppStorage.get<string>('auth_token');
    return !!token;
  }

  get isPhoneAuthorized(): boolean {
    return AppStorage.get<boolean>('phone_authorized') ?? false;
  }

  async login(huaweiCredentials: string): Promise<UserInfo> {
    try {
      const res = await httpClient.post<AuthResponse>('/auth/login', {
        huawei_credentials: huaweiCredentials,
      });
      httpClient.setToken(res.token);
      AppStorage.setOrCreate('phone_authorized', res.user.phoneAuthorized);
      AppStorage.setOrCreate('user_info', JSON.stringify(res.user));
      return res.user;
    } catch {
      return this.mockLogin();
    }
  }

  async register(huaweiCredentials: string, phoneNumber: string): Promise<UserInfo> {
    try {
      const res = await httpClient.post<AuthResponse>('/auth/register', {
        huawei_credentials: huaweiCredentials,
        phone_number: phoneNumber,
      });
      httpClient.setToken(res.token);
      AppStorage.setOrCreate('phone_authorized', true);
      AppStorage.setOrCreate('user_info', JSON.stringify(res.user));
      return res.user;
    } catch {
      this.mockUser.phoneAuthorized = true;
      httpClient.setToken('mock-token');
      AppStorage.setOrCreate('phone_authorized', true);
      AppStorage.setOrCreate('user_info', JSON.stringify(this.mockUser));
      return this.mockUser;
    }
  }

  async authorizePhone(phoneNumber: string): Promise<void> {
    try {
      await httpClient.post<void>('/auth/phone-authorize', {
        phone_number: phoneNumber,
      });
    } catch {
      // mock: do nothing
    }
    AppStorage.setOrCreate('phone_authorized', true);
    // 存储手机号前缀供 mock 匹配检测
    const prefix = phoneNumber.slice(0, 3) + '****' + phoneNumber.slice(-4);
    AppStorage.setOrCreate('my_phone_prefix', prefix);
  }

  async deleteAccount(): Promise<void> {
    try {
      await httpClient.delete<void>('/auth/account');
    } catch {
      // mock: do nothing
    }
    this.logout();
  }

  logout(): void {
    httpClient.clearToken();
    AppStorage.setOrCreate('phone_authorized', false);
    AppStorage.setOrCreate('user_info', '');
  }

  private mockLogin(): UserInfo {
    httpClient.setToken('mock-token');
    this.mockUser.phoneAuthorized = true;
    AppStorage.setOrCreate('phone_authorized', true);
    AppStorage.setOrCreate('user_info', JSON.stringify(this.mockUser));
    AppStorage.setOrCreate('my_phone_prefix', '138****0000');
    return this.mockUser;
  }
}

const authService = new AuthService();
export default authService;
