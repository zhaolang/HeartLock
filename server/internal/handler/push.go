package handler

import (
	"net/http"

	"github.com/zhaolang/heartlock/internal/dto"
	"github.com/zhaolang/heartlock/internal/middleware"
	"github.com/zhaolang/heartlock/internal/model"
	"github.com/zhaolang/heartlock/internal/service"
)

// PushHandler 推送处理器
type PushHandler struct {
	pushService *service.PushService
}

// NewPushHandler 创建推送处理器
func NewPushHandler(pushService *service.PushService) *PushHandler {
	return &PushHandler{pushService: pushService}
}

// RegisterToken POST /push/token 注册推送 Token
func (h *PushHandler) RegisterToken(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	if userID == "" {
		writeAppError(w, model.ErrAuthFailed, getRequestID(r))
		return
	}

	var req dto.RegisterPushTokenRequest
	if err := model.ReadJSON(r.Body, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, dto.APIResponse{
			Code:      40001,
			Message:   "请求参数格式错误",
			RequestID: getRequestID(r),
		})
		return
	}

	if req.PushToken == "" {
		writeAppError(w, model.NewValidationError("push_token", "推送 Token 不能为空"), getRequestID(r))
		return
	}
	if req.DeviceID == "" {
		writeAppError(w, model.NewValidationError("device_id", "设备 ID 不能为空"), getRequestID(r))
		return
	}

	if err := h.pushService.RegisterToken(r.Context(), userID, req.PushToken, req.DeviceID); err != nil {
		writeJSON(w, http.StatusInternalServerError, dto.APIResponse{
			Code:      50002,
			Message:   "注册推送 Token 失败",
			RequestID: getRequestID(r),
		})
		return
	}

	writeJSON(w, http.StatusOK, dto.APIResponse{
		Code:    0,
		Message: "success",
		Data:    dto.PushTokenResponse{Success: true},
		RequestID: getRequestID(r),
	})
}

// DeleteToken DELETE /push/token 删除推送 Token
func (h *PushHandler) DeleteToken(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	if userID == "" {
		writeAppError(w, model.ErrAuthFailed, getRequestID(r))
		return
	}

	var req dto.DeletePushTokenRequest
	if err := model.ReadJSON(r.Body, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, dto.APIResponse{
			Code:      40001,
			Message:   "请求参数格式错误",
			RequestID: getRequestID(r),
		})
		return
	}

	if req.DeviceID == "" {
		writeAppError(w, model.NewValidationError("device_id", "设备 ID 不能为空"), getRequestID(r))
		return
	}

	if err := h.pushService.DeleteToken(r.Context(), userID, req.DeviceID); err != nil {
		writeJSON(w, http.StatusInternalServerError, dto.APIResponse{
			Code:      50002,
			Message:   "删除推送 Token 失败",
			RequestID: getRequestID(r),
		})
		return
	}

	writeJSON(w, http.StatusOK, dto.APIResponse{
		Code:    0,
		Message: "success",
		Data:    dto.PushTokenResponse{Success: true},
		RequestID: getRequestID(r),
	})
}
