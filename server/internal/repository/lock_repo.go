package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/zhaolang/heartlock/internal/model"
)

// LockRepo 心锁数据仓库
type LockRepo struct {
	db *pgxpool.Pool
}

// NewLockRepo 创建心锁仓库
func NewLockRepo(db *pgxpool.Pool) *LockRepo {
	return &LockRepo{db: db}
}

// Create 创建心锁
func (r *LockRepo) Create(ctx context.Context, fromUserID, toPhoneHash, toPhoneHashSHA256 string, encryptedContent, contentNonce []byte) (*model.Lock, error) {
	lock := &model.Lock{}
	err := r.db.QueryRow(ctx,
		`INSERT INTO heart_locks (from_user_id, to_phone_hash, to_phone_hash_sha256, encrypted_content, content_nonce, status)
		 VALUES ($1, $2, $3, $4, $5, 'WAITING')
		 RETURNING id, from_user_id, to_phone_hash, to_phone_hash_sha256, encrypted_content, content_nonce, status,
		           created_at, updated_at, matched_at, revoked_at, destroyed_at`,
		fromUserID, toPhoneHash, toPhoneHashSHA256, encryptedContent, contentNonce,
	).Scan(&lock.ID, &lock.FromUserID, &lock.ToPhoneHash, &lock.ToPhoneHashSHA256, &lock.EncryptedContent, &lock.ContentNonce,
		&lock.Status, &lock.CreatedAt, &lock.UpdatedAt, &lock.MatchedAt, &lock.RevokedAt, &lock.DestroyedAt)
	if err != nil {
		return nil, err
	}
	return lock, nil
}

// FindByID 根据 ID 查找心锁
func (r *LockRepo) FindByID(ctx context.Context, id string) (*model.Lock, error) {
	lock := &model.Lock{}
	err := r.db.QueryRow(ctx,
		`SELECT id, from_user_id, to_phone_hash, to_phone_hash_sha256, encrypted_content, content_nonce, status,
		        created_at, updated_at, matched_at, revoked_at, destroyed_at
		 FROM heart_locks WHERE id = $1`,
		id,
	).Scan(&lock.ID, &lock.FromUserID, &lock.ToPhoneHash, &lock.ToPhoneHashSHA256, &lock.EncryptedContent, &lock.ContentNonce,
		&lock.Status, &lock.CreatedAt, &lock.UpdatedAt, &lock.MatchedAt, &lock.RevokedAt, &lock.DestroyedAt)
	if err != nil {
		return nil, err
	}
	return lock, nil
}

// FindByUserID 获取用户的心锁列表
func (r *LockRepo) FindByUserID(ctx context.Context, userID string, status string, page, pageSize int) ([]*model.Lock, int, error) {
	offset := (page - 1) * pageSize

	// 计数
	var total int
	countSQL := `SELECT COUNT(*) FROM heart_locks WHERE from_user_id = $1`
	countArgs := []interface{}{userID}
	if status != "" {
		countSQL += ` AND status = $2`
		countArgs = append(countArgs, status)
	}
	err := r.db.QueryRow(ctx, countSQL, countArgs...).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	// 查询列表
	paramIdx := 1
	baseWhere := fmt.Sprintf(`from_user_id = $%d`, paramIdx)
	listArgs := []interface{}{userID}
	paramIdx++

	if status != "" {
		baseWhere += fmt.Sprintf(` AND status = $%d`, paramIdx)
		listArgs = append(listArgs, status)
		paramIdx++
	}

	listSQL := fmt.Sprintf(
		`SELECT id, from_user_id, to_phone_hash, to_phone_hash_sha256, encrypted_content, content_nonce, status,
		        created_at, updated_at, matched_at, revoked_at, destroyed_at
		 FROM heart_locks WHERE %s ORDER BY created_at DESC LIMIT $%d OFFSET $%d`,
		baseWhere, paramIdx, paramIdx+1,
	)
	listArgs = append(listArgs, pageSize, offset)

	rows, err := r.db.Query(ctx, listSQL, listArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var locks []*model.Lock
	for rows.Next() {
		lock := &model.Lock{}
		err := rows.Scan(&lock.ID, &lock.FromUserID, &lock.ToPhoneHash, &lock.ToPhoneHashSHA256, &lock.EncryptedContent, &lock.ContentNonce,
			&lock.Status, &lock.CreatedAt, &lock.UpdatedAt, &lock.MatchedAt, &lock.RevokedAt, &lock.DestroyedAt)
		if err != nil {
			return nil, 0, err
		}
		locks = append(locks, lock)
	}
	return locks, total, nil
}

// FindExistingLock 查找用户对同一目标是否存在记录（RULE-010）
func (r *LockRepo) FindExistingLock(ctx context.Context, fromUserID, toPhoneHashSHA256 string) (*model.Lock, error) {
	lock := &model.Lock{}
	err := r.db.QueryRow(ctx,
		`SELECT id, from_user_id, to_phone_hash, to_phone_hash_sha256, encrypted_content, content_nonce, status,
		        created_at, updated_at, matched_at, revoked_at, destroyed_at
		 FROM heart_locks WHERE from_user_id = $1 AND to_phone_hash_sha256 = $2
		 LIMIT 1`,
		fromUserID, toPhoneHashSHA256,
	).Scan(&lock.ID, &lock.FromUserID, &lock.ToPhoneHash, &lock.ToPhoneHashSHA256, &lock.EncryptedContent, &lock.ContentNonce,
		&lock.Status, &lock.CreatedAt, &lock.UpdatedAt, &lock.MatchedAt, &lock.RevokedAt, &lock.DestroyedAt)
	if err != nil {
		return nil, err
	}
	return lock, nil
}

// FindMatch 匹配检测（RULE-030 ~ RULE-031）
func (r *LockRepo) FindMatch(ctx context.Context, currentUserPhoneHashSHA256, targetPhoneHashSHA256 string) (*model.Lock, error) {
	lock := &model.Lock{}
	err := r.db.QueryRow(ctx,
		`SELECT hl.id, hl.from_user_id, hl.to_phone_hash, hl.to_phone_hash_sha256, hl.encrypted_content, hl.content_nonce,
		        hl.status, hl.created_at, hl.updated_at, hl.matched_at, hl.revoked_at, hl.destroyed_at
		 FROM heart_locks hl
		 JOIN users u ON u.id = hl.from_user_id
		 WHERE hl.to_phone_hash_sha256 = $1
		   AND u.phone_hash_sha256 = $2
		   AND hl.status = 'WAITING'
		 LIMIT 1`,
		currentUserPhoneHashSHA256,
		targetPhoneHashSHA256,
	).Scan(&lock.ID, &lock.FromUserID, &lock.ToPhoneHash, &lock.ToPhoneHashSHA256, &lock.EncryptedContent, &lock.ContentNonce,
		&lock.Status, &lock.CreatedAt, &lock.UpdatedAt, &lock.MatchedAt, &lock.RevokedAt, &lock.DestroyedAt)
	if err != nil {
		return nil, err
	}
	return lock, nil
}

// FindMatchedPartner 根据当前心锁 ID 查找匹配的对方心锁
func (r *LockRepo) FindMatchedPartner(ctx context.Context, lockID string) (*model.Lock, error) {
	lock := &model.Lock{}
	err := r.db.QueryRow(ctx,
		`SELECT hl.id, hl.from_user_id, hl.to_phone_hash, hl.to_phone_hash_sha256, hl.encrypted_content, hl.content_nonce,
		        hl.status, hl.created_at, hl.updated_at, hl.matched_at, hl.revoked_at, hl.destroyed_at
		 FROM heart_locks hl
		 WHERE hl.status = 'MATCHED'
		   AND hl.matched_at = (SELECT matched_at FROM heart_locks WHERE id = $1)
		   AND hl.from_user_id != (SELECT from_user_id FROM heart_locks WHERE id = $1)
		 LIMIT 1`,
		lockID,
	).Scan(&lock.ID, &lock.FromUserID, &lock.ToPhoneHash, &lock.ToPhoneHashSHA256, &lock.EncryptedContent, &lock.ContentNonce,
		&lock.Status, &lock.CreatedAt, &lock.UpdatedAt, &lock.MatchedAt, &lock.RevokedAt, &lock.DestroyedAt)
	if err != nil {
		return nil, err
	}
	return lock, nil
}

// MarkMatched 将两条心锁标记为 MATCHED（RULE-032）
func (r *LockRepo) MarkMatched(ctx context.Context, lockID1, lockID2 string, matchedAt time.Time) error {
	_, err := r.db.Exec(ctx,
		`UPDATE heart_locks
		 SET status = 'MATCHED', matched_at = $1, updated_at = NOW()
		 WHERE id IN ($2, $3)`,
		matchedAt, lockID1, lockID2,
	)
	return err
}

// Revoke 撤回心锁（WAITING → REVOKED）
func (r *LockRepo) Revoke(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE heart_locks
		 SET status = 'REVOKED', revoked_at = NOW(), updated_at = NOW()
		 WHERE id = $1 AND status = 'WAITING'`,
		id,
	)
	return err
}

// Destroy 永久删除心锁（REVOKED → DESTROYED）
func (r *LockRepo) Destroy(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE heart_locks
		 SET status = 'DESTROYED', encrypted_content = NULL, content_nonce = NULL,
		     destroyed_at = NOW(), updated_at = NOW()
		 WHERE id = $1 AND status = 'REVOKED'`,
		id,
	)
	return err
}

// DeleteByUserID 删除用户的所有心锁（账户注销用）
func (r *LockRepo) DeleteByUserID(ctx context.Context, userID string) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM heart_locks WHERE from_user_id = $1`,
		userID,
	)
	return err
}

// CountWaitingByUserID 统计用户 WAITING 状态的心锁数
func (r *LockRepo) CountWaitingByUserID(ctx context.Context, userID string) (int, error) {
	var count int
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM heart_locks WHERE from_user_id = $1 AND status = 'WAITING'`,
		userID,
	).Scan(&count)
	return count, err
}

// CleanupRevoked 清理 30 天前撤回的元数据（定时任务）
func (r *LockRepo) CleanupRevoked(ctx context.Context) (int64, error) {
	result, err := r.db.Exec(ctx,
		`DELETE FROM heart_locks WHERE status = 'REVOKED' AND revoked_at < NOW() - INTERVAL '30 days'`,
	)
	if err != nil {
		return 0, err
	}
	return result.RowsAffected(), nil
}
