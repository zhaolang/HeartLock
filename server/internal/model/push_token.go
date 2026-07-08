package model

import "time"

// PushToken 推送 Token 模型
type PushToken struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	PushToken string    `json:"push_token"`
	DeviceID  string    `json:"device_id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
