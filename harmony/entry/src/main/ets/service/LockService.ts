import httpClient from './HttpClient';
import { LockItem, LockListResponse, CreateLockRequest, CreateLockResponse, LockStatus, InvitationCardResponse } from '../model/Lock';

class LockService {
  // Mock data for development
  private nextId: number = 1;
  private mockLocks: LockItem[] = [];

  private genId(): string {
    return `mock-${String(this.nextId++).padStart(4, '0')}`;
  }

  async getLocks(status?: LockStatus, page: number = 1, pageSize: number = 20): Promise<LockListResponse> {
    try {
      const params = status ? `?status=${status}&page=${page}&page_size=${pageSize}` : `?page=${page}&page_size=${pageSize}`;
      return await httpClient.get<LockListResponse>(`/heart-locks${params}`);
    } catch {
      return this.getMockLocks(status);
    }
  }

  async getLockDetail(id: string): Promise<LockItem> {
    try {
      return await httpClient.get<LockItem>(`/heart-locks/${id}`);
    } catch {
      const lock = this.mockLocks.find(l => l.id === id);
      if (lock) {
        return lock;
      }
      throw { code: 40004, message: '资源不存在' };
    }
  }

  async createLock(request: CreateLockRequest): Promise<CreateLockResponse> {
    try {
      return await httpClient.post<CreateLockResponse>('/heart-locks', {
        target_phone: request.targetPhone,
        content: request.content,
      });
    } catch {
      return this.createMockLock(request);
    }
  }

  async revokeLock(id: string): Promise<void> {
    try {
      await httpClient.patch<void>(`/heart-locks/${id}/revoke`);
    } catch {
      const lock = this.mockLocks.find(l => l.id === id);
      if (lock) {
        lock.status = LockStatus.REVOKED;
        lock.canRevoke = false;
        lock.canDestroy = true;
      }
    }
  }

  async destroyLock(id: string): Promise<void> {
    try {
      await httpClient.delete<void>(`/heart-locks/${id}`);
    } catch {
      const idx = this.mockLocks.findIndex(l => l.id === id);
      if (idx !== -1) {
        this.mockLocks.splice(idx, 1);
      }
    }
  }

  async generateInvitationCard(lockId: string): Promise<InvitationCardResponse> {
    try {
      return await httpClient.post<InvitationCardResponse>(`/heart-locks/${lockId}/invitation-card`);
    } catch {
      return {
        cardId: this.genId(),
        cardUrl: 'https://heartlock.app/card/mock',
        createdAt: new Date().toISOString(),
      };
    }
  }

  // ── Mock data system ──

  private getMockLocks(status?: LockStatus): LockListResponse {
    let filtered = this.mockLocks;
    if (status) {
      filtered = this.mockLocks.filter(l => l.status === status);
    }
    return {
      locks: filtered,
      total: filtered.length,
      page: 1,
      pageSize: 20,
      currentCount: this.mockLocks.filter(l => l.status === LockStatus.WAITING).length,
      maxCount: 3,
    };
  }

  private createMockLock(request: CreateLockRequest): CreateLockResponse {
    const now = new Date();
    const mockPhone = `138****${request.targetPhone.slice(-4)}`;

    // Simulate match detection: find if there's a lock from this target phone to the user's phone
    const matched = false; // Simplified — in real app server handles this

    const lock: LockItem = {
      id: this.genId(),
      status: matched ? LockStatus.MATCHED : LockStatus.WAITING,
      toPhonePrefix: mockPhone,
      createdAt: now.toISOString(),
      waitingDays: 0,
      canRevoke: true,
      canDestroy: false,
      hasInvitationCard: false,
    };

    this.mockLocks.unshift(lock);

    const waitingCount = this.mockLocks.filter(l => l.status === LockStatus.WAITING).length;

    return {
      id: lock.id,
      status: lock.status,
      matched: matched,
      currentCount: waitingCount,
      maxCount: 3,
    };
  }
}

const lockService = new LockService();
export default lockService;
