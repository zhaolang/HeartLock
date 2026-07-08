package service

import (
	"context"
	"fmt"
	"log/slog"
	"regexp"
	"strings"
	"time"
	"encoding/json"

	"github.com/zhaolang/heartlock/internal/crypto"
	"github.com/zhaolang/heartlock/internal/dto"
	"github.com/zhaolang/heartlock/internal/model"
	"github.com/zhaolang/heartlock/internal/repository"
)

// AuthService 认证业务服务
type AuthService struct {
	userRepo    *repository.UserRepo
	lockRepo    *repository.LockRepo
	pushRepo    *repository.PushRepo
	logRepo     *repository.OperationLogRepo
	kms         *crypto.KMS
	tokenMgr    *crypto.TokenManager
}

// NewAuthService 创建认证服务
func NewAuthService(
	userRepo *repository.UserRepo,
	lockRepo *repository.LockRepo,
	pushRepo *repository.PushRepo,
	logRepo *repository.OperationLogRepo,
	kms *crypto.KMS,
	tokenMgr *crypto.TokenManager,
) *AuthService {
	return &AuthService{
		userRepo: userRepo,
		lockRepo: lockRepo,
		pushRepo: pushRepo,
		logRepo:  logRepo,
		kms:      kms,
		tokenMgr: tokenMgr,
	}
}

// Register 用户注册
// RULE-001: 华为账号登录
// RULE-002: 手机号授权
// RULE-003: 一个手机号只能注册一个账户
func (s *AuthService) Register(ctx context.Context, req dto.RegisterRequest, ipAddress string) (*dto.RegisterResponse, error) {
	// 验证手机号格式（中国大陆手机号）
	if !isValidPhone(req.PhoneNumber) {
		return nil, model.NewValidationError("phone_number", "手机号格式不正确，需为 11 位数字")
	}

	// 验证华为 credentials（简化实现，生产环境需调用华为 OAuth API）
	if req.HuaweiCredentials == "" {
		return nil, model.ErrHuaweiAuthFailed
	}
	huaweiOpenID := fmt.Sprintf("huawei_%s", hashString(req.HuaweiCredentials))

	// 计算手机号哈希
	phoneHash, phoneHashSalt, err := crypto.HashPhone(req.PhoneNumber)
	if err != nil {
		slog.Error("hash phone failed", "error", err)
		return nil, model.ErrInternal
	}
	phoneHashSHA256 := crypto.HashPhoneSHA256(req.PhoneNumber)

	// 检查手机号是否已注册（RULE-003）
	existingUser, _ := s.userRepo.FindByPhoneHashSHA256(ctx, phoneHashSHA256)
	if existingUser != nil {
		if existingUser.DeletedAt != nil {
			// RULE-005: 已注销的手机号不能再注册
			return nil, &model.AppError{Code: 40001, Message: "该手机号已注册过 HeartLock，注销后不可重新注册"}
		}
		return nil, &model.AppError{Code: 40001, Message: "该手机号已注册"}
	}

	// 创建用户
	user, err := s.userRepo.Create(ctx, huaweiOpenID, phoneHash, phoneHashSalt, phoneHashSHA256)
	if err != nil {
		// 处理唯一约束冲突
		if strings.Contains(err.Error(), "duplicate key") {
			return nil, &model.AppError{Code: 40001, Message: "该华为账号已注册"}
		}
		slog.Error("create user failed", "error", err)
		return nil, model.ErrDBOperation
	}

	// 签发 JWT
	token, err := s.tokenMgr.Generate(user.ID)
	if err != nil {
		slog.Error("generate token failed", "error", err)
		return nil, model.ErrInternal
	}

	// 记录操作日志
	s.logOperation(ctx, &user.ID, "user.register", "user", &user.ID, nil, ipAddress)

	return &dto.RegisterResponse{
		Token: token,
		User: dto.UserBrief{
			ID:              user.ID,
			HeartLockCount:  0,
			MaxHeartLock:    3,
			PhoneAuthorized: true,
			CreatedAt:       user.CreatedAt.Format(time.RFC3339),
		},
	}, nil
}

// Login 用户登录
func (s *AuthService) Login(ctx context.Context, req dto.LoginRequest, ipAddress string) (*dto.LoginResponse, error) {
	if req.HuaweiCredentials == "" {
		return nil, model.ErrHuaweiAuthFailed
	}
	huaweiOpenID := fmt.Sprintf("huawei_%s", hashString(req.HuaweiCredentials))

	// 查找用户
	user, err := s.userRepo.FindByHuaweiOpenID(ctx, huaweiOpenID)
	if err != nil {
		return nil, model.ErrAuthFailed
	}

	// 检查是否已注销（RULE-005）
	if user.DeletedAt != nil {
		return nil, model.ErrAccountDeleted
	}

	// 检查手机号是否已授权
	phoneAuthorized := user.PhoneHash != ""

	// 统计 WAITING 心锁数
	waitingCount, _ := s.userRepo.CountWaitingLocks(ctx, user.ID)

	// 签发 JWT
	token, err := s.tokenMgr.Generate(user.ID)
	if err != nil {
		slog.Error("generate token failed", "error", err)
		return nil, model.ErrInternal
	}

	s.logOperation(ctx, &user.ID, "user.login", "user", &user.ID, nil, ipAddress)

	return &dto.LoginResponse{
		Token: token,
		User: dto.UserBrief{
			ID:              user.ID,
			HeartLockCount:  waitingCount,
			MaxHeartLock:    3,
			PhoneAuthorized: phoneAuthorized,
			CreatedAt:       user.CreatedAt.Format(time.RFC3339),
		},
	}, nil
}

// AuthorizePhone 手机号授权
func (s *AuthService) AuthorizePhone(ctx context.Context, userID, phoneNumber string, ipAddress string) (*dto.PhoneAuthorizeResponse, error) {
	if !isValidPhone(phoneNumber) {
		return nil, model.NewValidationError("phone_number", "手机号格式不正确，需为 11 位数字")
	}

	phoneHash, phoneHashSalt, err := crypto.HashPhone(phoneNumber)
	if err != nil {
		slog.Error("hash phone failed", "error", err)
		return nil, model.ErrInternal
	}
	phoneHashSHA256 := crypto.HashPhoneSHA256(phoneNumber)

	if err := s.userRepo.UpdatePhoneHash(ctx, userID, phoneHash, phoneHashSalt, phoneHashSHA256); err != nil {
		slog.Error("update phone hash failed", "error", err, "user_id", userID)
		return nil, model.ErrDBOperation
	}

	s.logOperation(ctx, &userID, "user.phone_authorize", "user", &userID, nil, ipAddress)

	return &dto.PhoneAuthorizeResponse{PhoneAuthorized: true}, nil
}

// DeleteAccount 注销账户
// RULE-004: 二次确认（由客户端处理）
// RULE-005: 注销后不可再次注册
// RULE-006: 删除所有数据
func (s *AuthService) DeleteAccount(ctx context.Context, userID string, ipAddress string) (*dto.DeleteAccountResponse, error) {
	// 获取用户信息
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, model.ErrNotFound
	}
	if user.DeletedAt != nil {
		return nil, model.ErrAccountDeleted
	}

	// 删除推送 Token（RULE-006c）
	if err := s.pushRepo.DeleteByUserID(ctx, userID); err != nil {
		slog.Error("delete push tokens failed", "error", err, "user_id", userID)
		// 继续执行，不中断注销流程
	}

	// 删除心锁记录（RULE-006b）
	if err := s.lockRepo.DeleteByUserID(ctx, userID); err != nil {
		slog.Error("delete heart locks failed", "error", err, "user_id", userID)
		return nil, model.ErrDBOperation
	}

	// 删除用户记录（RULE-006a）
	if err := s.userRepo.HardDelete(ctx, userID); err != nil {
		slog.Error("delete user failed", "error", err, "user_id", userID)
		return nil, model.ErrDBOperation
	}

	// 记录操作日志（RULE-006d：保留 7 天后清除）
	s.logOperation(ctx, &userID, "account.delete", "account", &userID, nil, ipAddress)

	return &dto.DeleteAccountResponse{Message: "账户已注销，所有数据已删除"}, nil
}

// GetUserByID 获取用户信息
func (s *AuthService) GetUserByID(ctx context.Context, userID string) (*model.User, error) {
	return s.userRepo.FindByID(ctx, userID)
}

// GetUserPhoneHash 获取用户手机号哈希
func (s *AuthService) GetUserPhoneHash(ctx context.Context, userID string) (string, error) {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return "", err
	}
	return user.PhoneHash, nil
}

// logOperation 记录操作日志
func (s *AuthService) logOperation(ctx context.Context, userID *string, action, resource string, resourceID *string, detail json.RawMessage, ipAddress string) {
	if err := s.logRepo.Create(ctx, userID, action, &resource, resourceID, detail, ipAddress); err != nil {
		slog.Error("write operation log failed", "error", err, "action", action)
	}
}

// isValidPhone 验证中国大陆手机号格式
func isValidPhone(phone string) bool {
	matched, _ := regexp.MatchString(`^1\d{10}$`, phone)
	return matched
}

// hashString 简单字符串哈希（用于模拟华为 OpenID 生成）
func hashString(s string) string {
	// 简化实现：取 SHA256 前 16 位
	// 生产环境应使用实际华为 OAuth 验证返回的 OpenID
	h := 0
	for _, c := range s {
		h = h*31 + int(c)
	}
	return fmt.Sprintf("%016x", h)
}
