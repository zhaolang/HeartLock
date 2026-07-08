package model

import (
	"time"
)

// User 用户模型
type User struct {
	ID              string     `json:"id"`
	HuaweiOpenID    string     `json:"huawei_open_id"`
	PhoneHash       string     `json:"-"` // 不返回给客户端
	PhoneHashSalt   string     `json:"-"`
	PhoneHashSHA256 string     `json:"-"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	DeletedAt       *time.Time `json:"-"`
}
