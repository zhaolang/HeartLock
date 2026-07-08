package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/zhaolang/heartlock/internal/crypto"
	"github.com/zhaolang/heartlock/internal/dto"
)

const (
	CtxKeyUserID contextKey = "user_id"
)

// GetUserID 从上下文中获取用户 ID
func GetUserID(ctx context.Context) string {
	if id, ok := ctx.Value(CtxKeyUserID).(string); ok {
		return id
	}
	return ""
}

// Auth JWT 鉴权中间件
func Auth(tokenManager *crypto.TokenManager) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				WriteJSON(w, http.StatusUnauthorized, dto.APIResponse{
					Code:      40002,
					Message:   "认证失败，缺少 Authorization 头",
					RequestID: GetRequestID(r.Context()),
				})
				return
			}

			// 解析 Bearer Token
			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
				WriteJSON(w, http.StatusUnauthorized, dto.APIResponse{
					Code:      40002,
					Message:   "认证失败，Token 格式不正确",
					RequestID: GetRequestID(r.Context()),
				})
				return
			}

			claims, err := tokenManager.Validate(parts[1])
			if err != nil {
				WriteJSON(w, http.StatusUnauthorized, dto.APIResponse{
					Code:      40002,
					Message:   "认证失败，Token 无效或已过期",
					RequestID: GetRequestID(r.Context()),
				})
				return
			}

			ctx := context.WithValue(r.Context(), CtxKeyUserID, claims.UserID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
