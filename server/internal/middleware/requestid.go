package middleware

import (
	"context"
	"net/http"

	"github.com/google/uuid"
)

type contextKey string

const (
	CtxKeyRequestID contextKey = "request_id"
)

// GetRequestID 从上下文中获取请求 ID
func GetRequestID(ctx context.Context) string {
	if id, ok := ctx.Value(CtxKeyRequestID).(string); ok {
		return id
	}
	return ""
}

// RequestID 为每个请求生成/透传唯一 ID
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-ID")
		if id == "" {
			id = uuid.New().String()
		}
		ctx := context.WithValue(r.Context(), CtxKeyRequestID, id)
		w.Header().Set("X-Request-ID", id)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
