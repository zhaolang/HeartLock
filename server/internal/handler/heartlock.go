package handler

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/zhaolang/heartlock/internal/dto"
	"github.com/zhaolang/heartlock/internal/middleware"
	"github.com/zhaolang/heartlock/internal/model"
	"github.com/zhaolang/heartlock/internal/service"
)

// LockHandler 心锁处理器
type LockHandler struct {
	lockService *service.LockService
}

// NewLockHandler 创建心锁处理器
func NewLockHandler(lockService *service.LockService) *LockHandler {
	return &LockHandler{lockService: lockService}
}

// List GET /heart-locks 获取心锁列表
func (h *LockHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	if userID == "" {
		writeAppError(w, model.ErrAuthFailed, getRequestID(r))
		return
	}

	status := r.URL.Query().Get("status")
	pageStr := r.URL.Query().Get("page")
	pageSizeStr := r.URL.Query().Get("page_size")

	page := 1
	pageSize := 20
	if p, err := strconv.Atoi(pageStr); err == nil && p >= 1 {
		page = p
	}
	if ps, err := strconv.Atoi(pageSizeStr); err == nil && ps >= 1 && ps <= 50 {
		pageSize = ps
	}

	// 验证 status 参数
	if status != "" && !isValidStatus(status) {
		writeAppError(w, model.NewValidationError("status", "状态值无效，仅允许 WAITING/MATCHED/REVOKED"), getRequestID(r))
		return
	}

	resp, appErr := h.lockService.ListLocks(r.Context(), userID, status, page, pageSize)
	if appErr != nil {
		writeAppError(w, appErr, getRequestID(r))
		return
	}

	writeJSON(w, http.StatusOK, dto.APIResponse{
		Code:    0,
		Message: "success",
		Data:    resp,
		RequestID: getRequestID(r),
	})
}

// Create POST /heart-locks 创建心锁
func (h *LockHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	if userID == "" {
		writeAppError(w, model.ErrAuthFailed, getRequestID(r))
		return
	}

	var req dto.CreateLockRequest
	if err := model.ReadJSON(r.Body, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, dto.APIResponse{
			Code:    40001,
			Message: "请求参数格式错误",
			RequestID: getRequestID(r),
		})
		return
	}

	resp, appErr := h.lockService.CreateLock(r.Context(), userID, req, cleanIP(r.RemoteAddr))
	if appErr != nil {
		writeAppError(w, appErr, getRequestID(r))
		return
	}

	writeJSON(w, http.StatusCreated, dto.APIResponse{
		Code:    0,
		Message: "success",
		Data:    resp,
		RequestID: getRequestID(r),
	})
}

// GetDetail GET /heart-locks/{id} 获取心锁详情
func (h *LockHandler) GetDetail(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	if userID == "" {
		writeAppError(w, model.ErrAuthFailed, getRequestID(r))
		return
	}

	lockID := chi.URLParam(r, "id")
	if lockID == "" {
		writeAppError(w, model.NewValidationError("id", "心锁 ID 不能为空"), getRequestID(r))
		return
	}

	resp, appErr := h.lockService.GetLockDetail(r.Context(), userID, lockID)
	if appErr != nil {
		writeAppError(w, appErr, getRequestID(r))
		return
	}

	writeJSON(w, http.StatusOK, dto.APIResponse{
		Code:    0,
		Message: "success",
		Data:    resp,
		RequestID: getRequestID(r),
	})
}

// Revoke PATCH /heart-locks/{id}/revoke 撤回心锁
func (h *LockHandler) Revoke(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	if userID == "" {
		writeAppError(w, model.ErrAuthFailed, getRequestID(r))
		return
	}

	lockID := chi.URLParam(r, "id")
	if lockID == "" {
		writeAppError(w, model.NewValidationError("id", "心锁 ID 不能为空"), getRequestID(r))
		return
	}

	resp, appErr := h.lockService.RevokeLock(r.Context(), userID, lockID, cleanIP(r.RemoteAddr))
	if appErr != nil {
		writeAppError(w, appErr, getRequestID(r))
		return
	}

	writeJSON(w, http.StatusOK, dto.APIResponse{
		Code:    0,
		Message: "success",
		Data:    resp,
		RequestID: getRequestID(r),
	})
}

// Destroy DELETE /heart-locks/{id} 永久删除心锁
func (h *LockHandler) Destroy(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	if userID == "" {
		writeAppError(w, model.ErrAuthFailed, getRequestID(r))
		return
	}

	lockID := chi.URLParam(r, "id")
	if lockID == "" {
		writeAppError(w, model.NewValidationError("id", "心锁 ID 不能为空"), getRequestID(r))
		return
	}

	resp, appErr := h.lockService.DestroyLock(r.Context(), userID, lockID, cleanIP(r.RemoteAddr))
	if appErr != nil {
		writeAppError(w, appErr, getRequestID(r))
		return
	}

	writeJSON(w, http.StatusOK, dto.APIResponse{
		Code:    0,
		Message: "success",
		Data:    resp,
		RequestID: getRequestID(r),
	})
}

// GenerateInvitationCard POST /heart-locks/{id}/invitation-card 生成邀请卡片
func (h *LockHandler) GenerateInvitationCard(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	if userID == "" {
		writeAppError(w, model.ErrAuthFailed, getRequestID(r))
		return
	}

	lockID := chi.URLParam(r, "id")
	if lockID == "" {
		writeAppError(w, model.NewValidationError("id", "心锁 ID 不能为空"), getRequestID(r))
		return
	}

	resp, appErr := h.lockService.GenerateInvitationCard(r.Context(), userID, lockID, cleanIP(r.RemoteAddr))
	if appErr != nil {
		writeAppError(w, appErr, getRequestID(r))
		return
	}

	writeJSON(w, http.StatusCreated, dto.APIResponse{
		Code:    0,
		Message: "success",
		Data:    resp,
		RequestID: getRequestID(r),
	})
}

// isValidStatus 验证心锁状态值
func isValidStatus(status string) bool {
	upper := strings.ToUpper(status)
	switch upper {
	case "WAITING", "MATCHED", "REVOKED":
		return true
	}
	return false
}
