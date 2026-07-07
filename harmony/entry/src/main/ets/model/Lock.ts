export enum LockStatus {
  WAITING = 'WAITING',
  MATCHED = 'MATCHED',
  REVOKED = 'REVOKED',
  DESTROYED = 'DESTROYED'
}

export interface LockItem {
  id: string
  status: LockStatus
  toPhonePrefix: string
  contentPreview?: string
  createdAt: string
  matchedAt?: string
  waitingDays: number
  canRevoke: boolean
  canDestroy: boolean
  hasInvitationCard: boolean
  theirWords?: string
  myWords?: string
}

export interface LockListResponse {
  locks: LockItem[]
  total: number
  page: number
  pageSize: number
  currentCount: number
  maxCount: number
}

export interface CreateLockRequest {
  targetPhone: string
  content: string
}

export interface CreateLockResponse {
  id: string
  status: LockStatus
  matched: boolean
  matchedAt?: string
  theirWords?: string
  currentCount: number
  maxCount: number
}

export interface InvitationCardResponse {
  cardId: string
  cardUrl: string
  createdAt: string
}
