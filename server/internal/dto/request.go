package dto

// ---------- 认证模块 ----------

// RegisterRequest 注册请求
type RegisterRequest struct {
	HuaweiCredentials string `json:"huawei_credentials"`
	PhoneNumber       string `json:"phone_number"`
}

// LoginRequest 登录请求
type LoginRequest struct {
	HuaweiCredentials string `json:"huawei_credentials"`
}

// PhoneAuthorizeRequest 手机号授权请求
type PhoneAuthorizeRequest struct {
	PhoneNumber string `json:"phone_number"`
}

// ---------- 心锁模块 ----------

// CreateLockRequest 创建心锁请求
type CreateLockRequest struct {
	TargetPhone string `json:"target_phone"`
	Content     string `json:"content"`
}

// ListLocksQuery 心锁列表查询参数
type ListLocksQuery struct {
	Status   string `json:"status"`
	Page     int    `json:"page"`
	PageSize int    `json:"page_size"`
}

// ---------- Push Token 模块 ----------

// RegisterPushTokenRequest 注册推送 Token 请求
type RegisterPushTokenRequest struct {
	PushToken string `json:"push_token"`
	DeviceID  string `json:"device_id"`
}

// DeletePushTokenRequest 删除推送 Token 请求
type DeletePushTokenRequest struct {
	DeviceID string `json:"device_id"`
}
