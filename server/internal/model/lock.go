package model

import (
	"time"
)

// LockStatus 心锁状态
type LockStatus string

const (
	LockStatusWAITING   LockStatus = "WAITING"
	LockStatusMATCHED   LockStatus = "MATCHED"
	LockStatusREVOKED   LockStatus = "REVOKED"
	LockStatusDESTROYED LockStatus = "DESTROYED"
)

// Lock 心锁模型
type Lock struct {
	ID               string     `json:"id"`
	FromUserID       string     `json:"from_user_id"`
	ToPhoneHash      string     `json:"-"` // 不返回给客户端
	ToPhoneHashSHA256 string     `json:"-"`
	EncryptedContent []byte     `json:"-"`
	ContentNonce     []byte     `json:"-"`
	Status           LockStatus `json:"status"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
	MatchedAt        *time.Time `json:"matched_at,omitempty"`
	RevokedAt        *time.Time `json:"revoked_at,omitempty"`
	DestroyedAt      *time.Time `json:"destroyed_at,omitempty"`
}
