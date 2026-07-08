package handler

import (
	"net/http"

	"github.com/zhaolang/heartlock/internal/dto"
	"github.com/zhaolang/heartlock/internal/middleware"
	"github.com/zhaolang/heartlock/internal/model"
	"github.com/zhaolang/heartlock/internal/service"
)

// AuthHandler 认证处理器
type AuthHandler struct {
	authService *service.AuthService
}

// NewAuthHandler 创建认证处理器
func NewAuthHandler(authService *service.AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

// Register POST /auth/register 用户注册
func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req dto.RegisterRequest
	if err := model.ReadJSON(r.Body, &req); err != nil {
		writeError(w, http.StatusBadRequest, 40001, "请求参数格式错误", getRequestID(r))
		return
	}

	resp, appErr := h.authService.Register(r.Context(), req, cleanIP(r.RemoteAddr))
	if appErr != nil {
		writeAppError(w, appErr, getRequestID(r))
		return
	}

	writeJSON(w, http.StatusCreated, dto.APIResponse{
		Code:      0,
		Message:   "success",
		Data:      resp,
		RequestID: getRequestID(r),
	})
}

// Login POST /auth/login 用户登录
func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req dto.LoginRequest
	if err := model.ReadJSON(r.Body, &req); err != nil {
		writeError(w, http.StatusBadRequest, 40001, "请求参数格式错误", getRequestID(r))
		return
	}

	resp, appErr := h.authService.Login(r.Context(), req, cleanIP(r.RemoteAddr))
	if appErr != nil {
		writeAppError(w, appErr, getRequestID(r))
		return
	}

	writeJSON(w, http.StatusOK, dto.APIResponse{
		Code:      0,
		Message:   "success",
		Data:      resp,
		RequestID: getRequestID(r),
	})
}

// AuthorizePhone POST /auth/phone-authorize 手机号授权
func (h *AuthHandler) AuthorizePhone(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	if userID == "" {
		writeAppError(w, model.ErrAuthFailed, getRequestID(r))
		return
	}

	var req dto.PhoneAuthorizeRequest
	if err := model.ReadJSON(r.Body, &req); err != nil {
		writeError(w, http.StatusBadRequest, 40001, "请求参数格式错误", getRequestID(r))
		return
	}

	resp, appErr := h.authService.AuthorizePhone(r.Context(), userID, req.PhoneNumber, cleanIP(r.RemoteAddr))
	if appErr != nil {
		writeAppError(w, appErr, getRequestID(r))
		return
	}

	writeJSON(w, http.StatusOK, dto.APIResponse{
		Code:      0,
		Message:   "success",
		Data:      resp,
		RequestID: getRequestID(r),
	})
}

// DeleteAccount DELETE /auth/account 注销账户
func (h *AuthHandler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	if userID == "" {
		writeAppError(w, model.ErrAuthFailed, getRequestID(r))
		return
	}

	resp, appErr := h.authService.DeleteAccount(r.Context(), userID, cleanIP(r.RemoteAddr))
	if appErr != nil {
		writeAppError(w, appErr, getRequestID(r))
		return
	}

	writeJSON(w, http.StatusOK, dto.APIResponse{
		Code:      0,
		Message:   "success",
		Data:      resp,
		RequestID: getRequestID(r),
	})
}
