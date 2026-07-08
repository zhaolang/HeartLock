package model

import "fmt"

// AppError 业务错误基类
type AppError struct {
	Code    int    // 业务错误码
	Message string // 用户可见的错误描述
	Err     error  // 内部错误（不返回给客户端）
}

func (e *AppError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("[%d] %s: %v", e.Code, e.Message, e.Err)
	}
	return fmt.Sprintf("[%d] %s", e.Code, e.Message)
}

func (e *AppError) Unwrap() error {
	return e.Err
}

// 预定义业务错误
var (
	ErrAuthFailed       = &AppError{Code: 40002, Message: "认证失败"}
	ErrPhoneRequired    = &AppError{Code: 40003, Message: "手机号未授权，无法创建心锁"}
	ErrNotFound         = &AppError{Code: 40004, Message: "资源不存在"}
	ErrHuaweiAuthFailed = &AppError{Code: 40005, Message: "华为账号验证失败"}
	ErrInvalidPushToken = &AppError{Code: 40006, Message: "华为推送 Token 无效"}

	ErrLockLimit     = &AppError{Code: 40010, Message: "心锁已达上限（3/3），需要先撤回一个"}
	ErrDuplicateLock = &AppError{Code: 40011, Message: "已经收藏过这份喜欢了"}
	ErrSelfLock      = &AppError{Code: 40012, Message: "不能向自己创建心锁"}
	ErrInvalidStatus = &AppError{Code: 40013, Message: "心锁状态不允许此操作"}

	ErrMatchDetect   = &AppError{Code: 40020, Message: "匹配检测异常"}
	ErrCardExists    = &AppError{Code: 40030, Message: "邀请卡片已存在"}
	ErrAccountDeleted = &AppError{Code: 40100, Message: "用户已注销"}

	ErrInternal     = &AppError{Code: 50001, Message: "服务器内部错误"}
	ErrDBOperation  = &AppError{Code: 50002, Message: "数据库操作异常"}
	ErrCryptoFailed = &AppError{Code: 50003, Message: "加密/解密失败"}
	ErrHuaweiAPI    = &AppError{Code: 50004, Message: "华为 API 调用失败"}
	ErrKMSUnavailable = &AppError{Code: 50005, Message: "密钥管理服务不可用"}
)

// 错误码到 HTTP 状态码映射
var ErrorCodeToHTTP = map[int]int{
	0:     200,
	40001: 400, // 请求参数错误
	40002: 401, // 认证失败
	40003: 403, // 手机号未授权
	40004: 404, // 资源不存在
	40005: 401, // 华为账号验证失败
	40006: 400, // 推送 Token 无效
	40010: 409, // 心锁已达上限
	40011: 409, // 已创建过心锁
	40012: 400, // 不能向自己创建
	40013: 409, // 状态不允许
	40020: 500, // 匹配检测异常
	40030: 409, // 邀请卡片已存在
	40100: 410, // 用户已注销
	50001: 500, // 服务器内部错误
	50002: 500, // 数据库异常
	50003: 500, // 加密失败
	50004: 502, // 华为 API 调用失败
	50005: 503, // 密钥服务不可用
}

// ValidationError 请求参数验证错误
type ValidationError struct {
	Field  string `json:"field"`
	Reason string `json:"reason"`
}

// NewValidationError 创建参数验证错误
func NewValidationError(field, reason string) *AppError {
	return &AppError{
		Code:    40001,
		Message: field + ": " + reason,
		Err:     fmt.Errorf("validation error: %s - %s", field, reason),
	}
}
