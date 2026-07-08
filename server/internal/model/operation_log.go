package model

import (
	"encoding/json"
	"time"
)

// OperationLog 操作日志模型
type OperationLog struct {
	ID         string          `json:"id"`
	UserID     *string         `json:"user_id,omitempty"`
	Action     string          `json:"action"`
	Resource   *string         `json:"resource,omitempty"`
	ResourceID *string         `json:"resource_id,omitempty"`
	Detail     json.RawMessage `json:"detail,omitempty"`
	IPAddress  string          `json:"ip_address,omitempty"`
	CreatedAt  time.Time       `json:"created_at"`
}
