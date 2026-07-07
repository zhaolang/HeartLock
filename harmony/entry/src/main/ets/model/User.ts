export interface UserInfo {
  id: string
  phoneAuthorized: boolean
  heartLockCount: number
  maxHeartLock: number
  matchedCount: number
  revokedCount: number
}

export interface AuthResponse {
  token: string
  user: UserInfo
}

export interface HealthCheckResponse {
  status: string
  version: string
  dbConnected: boolean
  uptimeSeconds: number
}
