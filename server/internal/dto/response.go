package dto

import "time"

// ---------- 通用 ----------

// APIResponse 统一 API 响应
type APIResponse struct {
	Code      int         `json:"code"`
	Message   string      `json:"message"`
	Data      interface{} `json:"data"`
	RequestID string      `json:"request_id"`
}

// PaginatedResponse 分页响应
type PaginatedResponse struct {
	Items      interface{} `json:"items"`
	Total      int         `json:"total"`
	Page       int         `json:"page"`
	PageSize   int         `json:"page_size"`
	TotalPages int         `json:"total_pages"`
}

// ---------- 健康检查 ----------

type HealthResponse struct {
	Status       string `json:"status"`
	Version      string `json:"version"`
	DBConnected  bool   `json:"db_connected"`
	UptimeSeconds int64 `json:"uptime_seconds"`
	Timestamp    string `json:"timestamp"`
}

// ---------- 认证模块 ----------

type RegisterResponse struct {
	Token string     `json:"token"`
	User  UserBrief  `json:"user"`
}

type LoginResponse struct {
	Token string    `json:"token"`
	User  UserBrief `json:"user"`
}

type UserBrief struct {
	ID              string `json:"id"`
	HeartLockCount  int    `json:"heart_lock_count"`
	MaxHeartLock    int    `json:"max_heart_lock"`
	PhoneAuthorized bool   `json:"phone_authorized"`
	CreatedAt       string `json:"created_at"`
}

type PhoneAuthorizeResponse struct {
	PhoneAuthorized bool `json:"phone_authorized"`
}

type DeleteAccountResponse struct {
	Message string `json:"message"`
}

// ---------- 心锁模块 ----------

type LockBrief struct {
	ID              string      `json:"id"`
	Status          string      `json:"status"`
	ToPhonePrefix   string      `json:"to_phone_prefix"`
	ContentPreview  *string     `json:"content_preview"`
	CreatedAt       time.Time   `json:"created_at"`
	MatchedAt       *time.Time  `json:"matched_at,omitempty"`
	WaitingDays     int         `json:"waiting_days,omitempty"`
}

type ListLocksData struct {
	Locks        []LockBrief `json:"locks"`
	Total        int         `json:"total"`
	Page         int         `json:"page"`
	PageSize     int         `json:"page_size"`
	CurrentCount int         `json:"current_count"`
	MaxCount     int         `json:"max_count"`
}

type LockDetailResponse struct {
	ID                string     `json:"id"`
	Status            string     `json:"status"`
	ToPhonePrefix     string     `json:"to_phone_prefix"`
	CreatedAt         time.Time  `json:"created_at"`
	MatchedAt         *time.Time `json:"matched_at,omitempty"`
	RevokedAt         *time.Time `json:"revoked_at,omitempty"`
	WaitingDays       int        `json:"waiting_days,omitempty"`
	MyWords           *string    `json:"my_words,omitempty"`
	TheirWords        *string    `json:"their_words,omitempty"`
	CanRevoke         bool       `json:"can_revoke"`
	CanDestroy        bool       `json:"can_destroy"`
	HasInvitationCard bool       `json:"has_invitation_card"`
}

type CreateLockResponse struct {
	ID           string     `json:"id"`
	Status       string     `json:"status"`
	Matched      bool       `json:"matched"`
	MatchedAt    *time.Time `json:"matched_at,omitempty"`
	TheirWords   *string    `json:"their_words,omitempty"`
	CurrentCount int        `json:"current_count"`
	MaxCount     int        `json:"max_count"`
}

type RevokeLockResponse struct {
	ID        string    `json:"id"`
	Status    string    `json:"status"`
	RevokedAt time.Time `json:"revoked_at"`
}

type DestroyLockResponse struct {
	ID     string `json:"id"`
	Status string `json:"status"`
}

// ---------- 邀请卡片 ----------

type InvitationCardResponse struct {
	CardID    string    `json:"card_id"`
	CardURL   string    `json:"card_url"`
	CreatedAt time.Time `json:"created_at"`
}

// ---------- Push Token ----------

type PushTokenResponse struct {
	Success bool `json:"success"`
}
