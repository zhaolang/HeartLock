package middleware

import (
	"html"
	"net/http"
	"regexp"
	"strings"
	"unicode/utf8"

	"github.com/zhaolang/heartlock/internal/dto"
)

const (
	MaxContentLength     = 500
	MinContentLength     = 1
	MaxPhoneLength       = 11
	MaxPushTokenLength   = 512
	MaxDeviceIDLength    = 128
)

var phoneRegex = regexp.MustCompile(`^1\d{10}$`)

var sqlKeywords = []string{
	"ALTER", "CREATE", "DROP", "TRUNCATE", "INSERT", "UPDATE", "DELETE",
	"SELECT", "UNION", "EXEC", "EXECUTE", "OR 1=1", "OR '1'='1'",
	"--", "/*", "*/", "CHAR(", "CONCAT(", "LOAD_FILE",
}

type ValidationResult struct {
	Valid  bool
	Field  string
	Reason string
}

func SanitizeInput(input string) string {
	return html.EscapeString(strings.TrimSpace(input))
}

func HasSQLInjection(input string) bool {
	upper := strings.ToUpper(input)
	for _, kw := range sqlKeywords {
		if strings.Contains(upper, kw) {
			return true
		}
	}
	return false
}

func ValidatePhone(phone string) *ValidationResult {
	clean := strings.TrimSpace(phone)
	if clean == "" {
		return &ValidationResult{Field: "target_phone", Reason: "手机号不能为空"}
	}
	if len(clean) != MaxPhoneLength {
		return &ValidationResult{Field: "target_phone", Reason: "手机号格式不正确，需为 11 位数字"}
	}
	if !phoneRegex.MatchString(clean) {
		return &ValidationResult{Field: "target_phone", Reason: "手机号格式不正确，需以 1 开头"}
	}
	if HasSQLInjection(clean) {
		return &ValidationResult{Field: "target_phone", Reason: "手机号包含非法字符"}
	}
	return nil
}

func ValidateContent(content string) *ValidationResult {
	clean := strings.TrimSpace(content)
	if clean == "" {
		return &ValidationResult{Field: "content", Reason: "内容不能为空"}
	}
	if len(strings.TrimSpace(clean)) == 0 {
		return &ValidationResult{Field: "content", Reason: "内容不能为纯空格"}
	}
	charCount := utf8.RuneCountInString(clean)
	if charCount < MinContentLength {
		return &ValidationResult{Field: "content", Reason: "内容不能为空"}
	}
	if charCount > MaxContentLength {
		return &ValidationResult{Field: "content", Reason: "内容不能超过 500 个字符"}
	}
	if HasSQLInjection(clean) {
		return &ValidationResult{Field: "content", Reason: "内容包含非法字符"}
	}
	return nil
}

func ValidateHeartLockStatus(status string) *ValidationResult {
	upper := strings.ToUpper(strings.TrimSpace(status))
	if upper == "" {
		return nil
	}
	switch upper {
	case "WAITING", "MATCHED", "REVOKED":
		return nil
	default:
		return &ValidationResult{Field: "status", Reason: "状态值无效，仅允许 WAITING/MATCHED/REVOKED"}
	}
}

func ValidatePage(page, pageSize int) *ValidationResult {
	if page < 1 {
		return &ValidationResult{Field: "page", Reason: "页码必须 >= 1"}
	}
	if pageSize < 1 || pageSize > 50 {
		return &ValidationResult{Field: "page_size", Reason: "每页数量必须为 1-50"}
	}
	return nil
}

func ValidatePushToken(token string) *ValidationResult {
	clean := strings.TrimSpace(token)
	if clean == "" {
		return &ValidationResult{Field: "push_token", Reason: "推送 Token 不能为空"}
	}
	if len(clean) > MaxPushTokenLength {
		return &ValidationResult{Field: "push_token", Reason: "推送 Token 过长"}
	}
	return nil
}

func ValidateDeviceID(deviceID string) *ValidationResult {
	clean := strings.TrimSpace(deviceID)
	if clean == "" {
		return &ValidationResult{Field: "device_id", Reason: "设备 ID 不能为空"}
	}
	if len(clean) > MaxDeviceIDLength {
		return &ValidationResult{Field: "device_id", Reason: "设备 ID 过长"}
	}
	return nil
}

func writeValidationError(w http.ResponseWriter, vr *ValidationResult, requestID string) {
	WriteJSON(w, http.StatusBadRequest, dto.APIResponse{
		Code:    40001,
		Message: vr.Field + ": " + vr.Reason,
		Data: map[string]string{
			"field":  vr.Field,
			"reason": vr.Reason,
		},
		RequestID: requestID,
	})
}
