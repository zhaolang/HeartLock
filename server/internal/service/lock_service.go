package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/zhaolang/heartlock/internal/crypto"
	"github.com/zhaolang/heartlock/internal/dto"
	"github.com/zhaolang/heartlock/internal/model"
	"github.com/zhaolang/heartlock/internal/repository"
)

// LockService 心锁业务服务
type LockService struct {
	lockRepo    *repository.LockRepo
	userRepo    *repository.UserRepo
	pushService *PushService
	logRepo     *repository.OperationLogRepo
	kms         *crypto.KMS
}

// NewLockService 创建心锁服务
func NewLockService(
	lockRepo *repository.LockRepo,
	userRepo *repository.UserRepo,
	pushService *PushService,
	logRepo *repository.OperationLogRepo,
	kms *crypto.KMS,
) *LockService {
	return &LockService{
		lockRepo:    lockRepo,
		userRepo:    userRepo,
		pushService: pushService,
		logRepo:     logRepo,
		kms:         kms,
	}
}

// CreateLock 创建心锁（核心业务方法，含匹配检测）
// 实现：RULE-010 ~ RULE-014, RULE-030 ~ RULE-033
func (s *LockService) CreateLock(ctx context.Context, userID string, req dto.CreateLockRequest, ipAddress string) (*dto.CreateLockResponse, error) {
	// --- 业务规则校验 ---

	// RULE-012: 目标手机号不能为空
	if req.TargetPhone == "" {
		return nil, model.NewValidationError("target_phone", "手机号不能为空")
	}

	// 查询当前用户
	currentUser, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		slog.Error("find current user failed", "error", err, "user_id", userID)
		return nil, model.ErrNotFound
	}
	if currentUser.DeletedAt != nil {
		return nil, model.ErrAccountDeleted
	}

	// RULE-002a: 手机号必须已授权
	if currentUser.PhoneHash == "" {
		return nil, model.ErrPhoneRequired
	}

	// RULE-012b: 目标手机号不能是自己的
	if crypto.VerifyPhoneSHA256(req.TargetPhone, currentUser.PhoneHashSHA256) {
		return nil, model.ErrSelfLock
	}

	// RULE-013: 内容 1-500 字
	contentLen := len([]rune(req.Content))
	if contentLen < 1 {
		return nil, model.NewValidationError("content", "内容不能为空")
	}
	if contentLen > 500 {
		return nil, model.NewValidationError("content", "内容不能超过 500 个字符")
	}

	// 计算目标手机号哈希
	targetPhoneHash, _, err := crypto.HashPhone(req.TargetPhone)
	if err != nil {
		slog.Error("hash target phone failed", "error", err)
		return nil, model.ErrInternal
	}
	targetPhoneHashSHA256 := crypto.HashPhoneSHA256(req.TargetPhone)

	// RULE-010: 同一用户对同一目标只能有一条记录
	existingLock, _ := s.lockRepo.FindExistingLock(ctx, userID, targetPhoneHashSHA256)
	if existingLock != nil {
		return nil, model.ErrDuplicateLock
	}

	// RULE-011: WAITING 状态数 < 3
	waitingCount, err := s.lockRepo.CountWaitingByUserID(ctx, userID)
	if err != nil {
		slog.Error("count waiting locks failed", "error", err, "user_id", userID)
		return nil, model.ErrDBOperation
	}
	if waitingCount >= 3 {
		return nil, model.ErrLockLimit
	}

	// --- 加密内容（RULE-013c）---
	encryptedContent, contentNonce, err := s.kms.EncryptContent(req.Content)
	if err != nil {
		slog.Error("encrypt content failed", "error", err)
		return nil, model.ErrCryptoFailed
	}

	// --- 创建心锁记录 ---
	lock, err := s.lockRepo.Create(ctx, userID, targetPhoneHash, targetPhoneHashSHA256, encryptedContent, contentNonce)
	if err != nil {
		slog.Error("create lock failed", "error", err)
		return nil, model.ErrDBOperation
	}

	// --- 匹配检测（RULE-030 ~ RULE-033）---
	matchedLock, err := s.lockRepo.FindMatch(ctx, currentUser.PhoneHashSHA256, targetPhoneHashSHA256)
	if err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			// 真正的查询错误
			slog.Error("match detection query failed", "error", err)
		}
		matchedLock = nil
	}

	if matchedLock != nil {
		// RULE-032: 同时更新两条记录为 MATCHED，matched_at 相同
		now := time.Now()
		if err := s.lockRepo.MarkMatched(ctx, lock.ID, matchedLock.ID, now); err != nil {
			slog.Error("mark matched failed", "error", err)
			// 标记匹配失败，返回未匹配状态
			waitingCount++
			return &dto.CreateLockResponse{
				ID:           lock.ID,
				Status:       string(model.LockStatusWAITING),
				Matched:      false,
				CurrentCount: waitingCount,
				MaxCount:     3,
			}, nil
		}

		// 解密对方的内容
		theirContent, err := s.kms.DecryptContent(matchedLock.EncryptedContent, matchedLock.ContentNonce)
		if err != nil {
			slog.Error("decrypt matched content failed", "error", err)
			theirContent = ""
		}

		// 异步推送双方通知
		go s.pushService.SendMatchNotification(context.Background(), userID, matchedLock.FromUserID, theirContent)

		// 记录操作日志
		s.logOperation(ctx, &userID, "heart_lock.match", "heart_lock", &lock.ID, nil, ipAddress)

		return &dto.CreateLockResponse{
			ID:           lock.ID,
			Status:       string(model.LockStatusMATCHED),
			Matched:      true,
			MatchedAt:    &now,
			TheirWords:   &theirContent,
			CurrentCount: waitingCount, // 新创建的已变为 MATCHED，不增加 WAITING 计数
			MaxCount:     3,
		}, nil
	}

	// 未匹配
	waitingCount++
	s.logOperation(ctx, &userID, "heart_lock.create", "heart_lock", &lock.ID, nil, ipAddress)

	return &dto.CreateLockResponse{
		ID:           lock.ID,
		Status:       string(model.LockStatusWAITING),
		Matched:      false,
		CurrentCount: waitingCount,
		MaxCount:     3,
	}, nil
}

// ListLocks 获取心锁列表
func (s *LockService) ListLocks(ctx context.Context, userID string, status string, page, pageSize int) (*dto.ListLocksData, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 50 {
		pageSize = 20
	}

	locks, total, err := s.lockRepo.FindByUserID(ctx, userID, status, page, pageSize)
	if err != nil {
		slog.Error("find locks by user id failed", "error", err, "user_id", userID)
		return nil, model.ErrDBOperation
	}

	// 统计当前 WAITING 数量
	waitingCount, _ := s.lockRepo.CountWaitingByUserID(ctx, userID)

	var lockBriefs []dto.LockBrief
	for _, lock := range locks {
		brief := dto.LockBrief{
			ID:        lock.ID,
			Status:    string(lock.Status),
			CreatedAt: lock.CreatedAt,
		}

		// RULE-054: 不返回明文手机号
		if lock.ToPhoneHash != "" {
			brief.ToPhonePrefix = "***"
		}

		// MATCHED 状态返回对方第一句话前 50 字
		if lock.Status == model.LockStatusMATCHED {
			theirContent, err := s.kms.DecryptContent(lock.EncryptedContent, lock.ContentNonce)
			if err == nil && theirContent != "" {
				preview := truncateText(theirContent, 50)
				brief.ContentPreview = &preview
			}
		}

		// 等待天数（仅 WAITING）
		if lock.Status == model.LockStatusWAITING {
			brief.WaitingDays = int(time.Since(lock.CreatedAt).Hours() / 24)
		}

		if lock.Status == model.LockStatusMATCHED {
			brief.MatchedAt = lock.MatchedAt
		}

		lockBriefs = append(lockBriefs, brief)
	}

	totalPages := (total + pageSize - 1) / pageSize
	if totalPages < 1 {
		totalPages = 1
	}

	return &dto.ListLocksData{
		Locks:        lockBriefs,
		Total:        total,
		Page:         page,
		PageSize:     pageSize,
		CurrentCount: waitingCount,
		MaxCount:     3,
	}, nil
}

// GetLockDetail 获取心锁详情
func (s *LockService) GetLockDetail(ctx context.Context, userID, lockID string) (*dto.LockDetailResponse, error) {
	lock, err := s.lockRepo.FindByID(ctx, lockID)
	if err != nil {
		return nil, model.ErrNotFound
	}

	// 验证权限：只能查看自己的心锁
	if lock.FromUserID != userID {
		return nil, model.ErrNotFound
	}

	resp := &dto.LockDetailResponse{
		ID:        lock.ID,
		Status:    string(lock.Status),
		CreatedAt: lock.CreatedAt,
	}

	if lock.ToPhoneHash != "" {
		resp.ToPhonePrefix = "***"
	}

	switch lock.Status {
	case model.LockStatusWAITING:
		resp.WaitingDays = int(time.Since(lock.CreatedAt).Hours() / 24)
		resp.CanRevoke = true
		resp.CanDestroy = false
	case model.LockStatusMATCHED:
		resp.MatchedAt = lock.MatchedAt
		resp.CanRevoke = false
		resp.CanDestroy = false

		// 解密自己的内容
		myWords, err := s.kms.DecryptContent(lock.EncryptedContent, lock.ContentNonce)
		if err == nil {
			resp.MyWords = &myWords
		}

		// 从匹配的心锁中获取对方的内容
		matchedLock, err := s.lockRepo.FindMatchedPartner(ctx, lock.ID)
		if err == nil && matchedLock != nil {
			theirWords, err := s.kms.DecryptContent(matchedLock.EncryptedContent, matchedLock.ContentNonce)
			if err == nil {
				resp.TheirWords = &theirWords
			}
		}
	case model.LockStatusREVOKED:
		resp.RevokedAt = lock.RevokedAt
		resp.CanRevoke = false
		resp.CanDestroy = true
	case model.LockStatusDESTROYED:
		resp.CanRevoke = false
		resp.CanDestroy = false
	}

	return resp, nil
}

// RevokeLock 撤回心锁（WAITING → REVOKED）
// RULE-023: 保留所有元数据，仅标记状态变更
func (s *LockService) RevokeLock(ctx context.Context, userID, lockID string, ipAddress string) (*dto.RevokeLockResponse, error) {
	lock, err := s.lockRepo.FindByID(ctx, lockID)
	if err != nil {
		return nil, model.ErrNotFound
	}
	if lock.FromUserID != userID {
		return nil, model.ErrNotFound
	}
	if lock.Status != model.LockStatusWAITING {
		return nil, model.ErrInvalidStatus
	}

	if err := s.lockRepo.Revoke(ctx, lockID); err != nil {
		slog.Error("revoke lock failed", "error", err, "lock_id", lockID)
		return nil, model.ErrDBOperation
	}

	s.logOperation(ctx, &userID, "heart_lock.revoke", "heart_lock", &lockID, nil, ipAddress)

	return &dto.RevokeLockResponse{
		ID:        lockID,
		Status:    string(model.LockStatusREVOKED),
		RevokedAt: time.Now(),
	}, nil
}

// DestroyLock 永久删除心锁（REVOKED → DESTROYED）
// RULE-024: 加密内容置为 NULL，元数据保留 30 天
func (s *LockService) DestroyLock(ctx context.Context, userID, lockID string, ipAddress string) (*dto.DestroyLockResponse, error) {
	lock, err := s.lockRepo.FindByID(ctx, lockID)
	if err != nil {
		return nil, model.ErrNotFound
	}
	if lock.FromUserID != userID {
		return nil, model.ErrNotFound
	}
	if lock.Status != model.LockStatusREVOKED {
		return nil, model.ErrInvalidStatus
	}

	if err := s.lockRepo.Destroy(ctx, lockID); err != nil {
		slog.Error("destroy lock failed", "error", err, "lock_id", lockID)
		return nil, model.ErrDBOperation
	}

	s.logOperation(ctx, &userID, "heart_lock.destroy", "heart_lock", &lockID, nil, ipAddress)

	return &dto.DestroyLockResponse{
		ID:     lockID,
		Status: string(model.LockStatusDESTROYED),
	}, nil
}

// GenerateInvitationCard 生成邀请卡片
// RULE-061: 不包含发送者身份信息
// RULE-063: 每个心锁仅可生成一张
func (s *LockService) GenerateInvitationCard(ctx context.Context, userID, lockID, ipAddress string) (*dto.InvitationCardResponse, error) {
	lock, err := s.lockRepo.FindByID(ctx, lockID)
	if err != nil {
		return nil, model.ErrNotFound
	}
	if lock.FromUserID != userID {
		return nil, model.ErrNotFound
	}
	if lock.Status != model.LockStatusWAITING {
		return nil, model.ErrInvalidStatus
	}

	now := time.Now()
	cardID := fmt.Sprintf("card_%s", lock.ID)

	s.logOperation(ctx, &userID, "heart_lock.invitation_card", "heart_lock", &lockID, nil, ipAddress)

	return &dto.InvitationCardResponse{
		CardID:    cardID,
		CardURL:   fmt.Sprintf("https://api.heartlock.app/v1/cards/%s", cardID),
		CreatedAt: now,
	}, nil
}

// logOperation 记录操作日志
func (s *LockService) logOperation(ctx context.Context, userID *string, action, resource string, resourceID *string, detail interface{}, ipAddress string) {
	if err := s.logRepo.Create(ctx, userID, action, &resource, resourceID, nil, ipAddress); err != nil {
		slog.Error("write operation log failed", "error", err, "action", action)
	}
}

// truncateText 截断文本到指定长度
func truncateText(text string, maxLen int) string {
	runes := []rune(text)
	if len(runes) <= maxLen {
		return text
	}
	return string(runes[:maxLen]) + "..."
}
