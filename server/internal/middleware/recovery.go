package middleware

import (
	"log/slog"
	"net/http"
	"runtime/debug"

	"github.com/zhaolang/heartlock/internal/dto"
	"github.com/zhaolang/heartlock/internal/model"
)

// Recovery panic 恢复中间件
func Recovery(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				slog.Error("panic recovered",
					"panic", rec,
					"stack", string(debug.Stack()),
					"request_id", GetRequestID(r.Context()),
				)
				WriteJSON(w, http.StatusInternalServerError, dto.APIResponse{
					Code:      50001,
					Message:   "服务器内部错误",
					RequestID: GetRequestID(r.Context()),
				})
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// WriteJSON 写入 JSON 响应（工具函数，避免循环依赖）
func WriteJSON(w http.ResponseWriter, statusCode int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	if err := model.WriteJSON(w, data); err != nil {
		slog.Error("write json response failed", "error", err)
	}
}
