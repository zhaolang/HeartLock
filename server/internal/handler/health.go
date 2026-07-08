package handler

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/zhaolang/heartlock/internal/dto"
	"github.com/zhaolang/heartlock/internal/middleware"
	"github.com/zhaolang/heartlock/internal/model"
)

// HealthHandler 健康检查处理器
type HealthHandler struct {
	db      *pgxpool.Pool
	version string
	startAt time.Time
}

// NewHealthHandler 创建健康检查处理器
func NewHealthHandler(db *pgxpool.Pool, version string) *HealthHandler {
	return &HealthHandler{
		db:      db,
		version: version,
		startAt: time.Now(),
	}
}

// Health GET /health 健康检查
func (h *HealthHandler) Health(w http.ResponseWriter, r *http.Request) {
	// 检查数据库连接
	dbConnected := true
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()
	if err := h.db.Ping(ctx); err != nil {
		slog.Warn("health check: db ping failed", "error", err)
		dbConnected = false
	}

	// 服务启动前 5 秒允许 db_connected = false（启动阶段）
	uptime := int64(time.Since(h.startAt).Seconds())
	if uptime < 5 {
		dbConnected = true // 启动阶段允许
	}

	resp := dto.APIResponse{
		Code:    0,
		Message: "success",
		Data: dto.HealthResponse{
			Status:        "healthy",
			Version:       h.version,
			DBConnected:   dbConnected,
			UptimeSeconds: uptime,
			Timestamp:     time.Now().UTC().Format(time.RFC3339),
		},
		RequestID: getRequestID(r),
	}

	writeJSON(w, http.StatusOK, resp)
}

// ---------- 共享工具函数（供所有 handler 使用）----------

// writeJSON 写入 JSON 响应
func writeJSON(w http.ResponseWriter, httpStatusCode int, data dto.APIResponse) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(httpStatusCode)
	json.NewEncoder(w).Encode(data)
}

// getRequestID 从请求中获取 request_id
func getRequestID(r *http.Request) string {
	return middleware.GetRequestID(r.Context())
}

// writeError 写入业务错误响应
// httpStatusCode: HTTP 状态码
// bizCode: 业务错误码
// bizMessage: 业务错误信息
func writeError(w http.ResponseWriter, httpStatusCode, bizCode int, bizMessage, requestID string) {
	writeJSON(w, httpStatusCode, dto.APIResponse{
		Code:      bizCode,
		Message:   bizMessage,
		Data:      nil,
		RequestID: requestID,
	})
}

// writeAppError 根据 model.AppError 写入错误响应
func writeAppError(w http.ResponseWriter, appErr error, requestID string) {
	
	appErrPtr, ok := appErr.(*model.AppError)

	if !ok {
		appErrPtr = model.ErrInternal
	}
	httpCode := model.ErrorCodeToHTTP[appErrPtr.Code]
	if httpCode == 0 {
		httpCode = http.StatusInternalServerError
	}
	writeJSON(w, httpCode, dto.APIResponse{
		Code:      appErrPtr.Code,
		Message:   appErrPtr.Message,
		Data:      nil,
		RequestID: requestID,
	})
}

// cleanIP 从 RemoteAddr 中提取纯净的 IP 地址（去掉端口）
func cleanIP(remoteAddr string) string {
	if remoteAddr == "" {
		return ""
	}
	// 处理 [::1]:port 格式 (IPv6)
	if remoteAddr[0] == '[' {
		if idx := strings.Index(remoteAddr, "]:"); idx != -1 {
			return remoteAddr[1:idx]
		}
		return remoteAddr
	}
	// 处理 127.0.0.1:port 格式 (IPv4)
	if idx := strings.LastIndex(remoteAddr, ":"); idx != -1 {
		return remoteAddr[:idx]
	}
	return remoteAddr
}
