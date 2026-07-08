package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/zhaolang/heartlock/internal/model"
)

// UserRepo 用户数据仓库
type UserRepo struct {
	db *pgxpool.Pool
}

// NewUserRepo 创建用户仓库
func NewUserRepo(db *pgxpool.Pool) *UserRepo {
	return &UserRepo{db: db}
}

// Create 创建用户
func (r *UserRepo) Create(ctx context.Context, huaweiOpenID, phoneHash, phoneHashSalt, phoneHashSHA256 string) (*model.User, error) {
	user := &model.User{}
	err := r.db.QueryRow(ctx,
		`INSERT INTO users (huawei_open_id, phone_hash, phone_hash_salt, phone_hash_sha256)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, huawei_open_id, phone_hash, phone_hash_salt, phone_hash_sha256, created_at, updated_at`,
		huaweiOpenID, phoneHash, phoneHashSalt, phoneHashSHA256,
	).Scan(&user.ID, &user.HuaweiOpenID, &user.PhoneHash, &user.PhoneHashSalt, &user.PhoneHashSHA256, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// FindByHuaweiOpenID 根据华为 OpenID 查找用户
func (r *UserRepo) FindByHuaweiOpenID(ctx context.Context, huaweiOpenID string) (*model.User, error) {
	user := &model.User{}
	err := r.db.QueryRow(ctx,
		`SELECT id, huawei_open_id, phone_hash, phone_hash_salt, phone_hash_sha256, created_at, updated_at, deleted_at
		 FROM users WHERE huawei_open_id = $1`,
		huaweiOpenID,
	).Scan(&user.ID, &user.HuaweiOpenID, &user.PhoneHash, &user.PhoneHashSalt, &user.PhoneHashSHA256, &user.CreatedAt, &user.UpdatedAt, &user.DeletedAt)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// FindByPhoneHash 根据手机号哈希查找用户
func (r *UserRepo) FindByPhoneHash(ctx context.Context, phoneHash string) (*model.User, error) {
	user := &model.User{}
	err := r.db.QueryRow(ctx,
		`SELECT id, huawei_open_id, phone_hash, phone_hash_salt, phone_hash_sha256, created_at, updated_at, deleted_at
		 FROM users WHERE phone_hash = $1`,
		phoneHash,
	).Scan(&user.ID, &user.HuaweiOpenID, &user.PhoneHash, &user.PhoneHashSalt, &user.PhoneHashSHA256, &user.CreatedAt, &user.UpdatedAt, &user.DeletedAt)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// FindByPhoneHashSHA256 根据手机号 SHA-256 哈希查找用户（用于查重和匹配检测）
func (r *UserRepo) FindByPhoneHashSHA256(ctx context.Context, phoneHashSHA256 string) (*model.User, error) {
	user := &model.User{}
	err := r.db.QueryRow(ctx,
		`SELECT id, huawei_open_id, phone_hash, phone_hash_salt, phone_hash_sha256, created_at, updated_at, deleted_at
		 FROM users WHERE phone_hash_sha256 = $1`,
		phoneHashSHA256,
	).Scan(&user.ID, &user.HuaweiOpenID, &user.PhoneHash, &user.PhoneHashSalt, &user.PhoneHashSHA256, &user.CreatedAt, &user.UpdatedAt, &user.DeletedAt)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// FindByID 根据 ID 查找用户
func (r *UserRepo) FindByID(ctx context.Context, id string) (*model.User, error) {
	user := &model.User{}
	err := r.db.QueryRow(ctx,
		`SELECT id, huawei_open_id, phone_hash, phone_hash_salt, phone_hash_sha256, created_at, updated_at, deleted_at
		 FROM users WHERE id = $1`,
		id,
	).Scan(&user.ID, &user.HuaweiOpenID, &user.PhoneHash, &user.PhoneHashSalt, &user.PhoneHashSHA256, &user.CreatedAt, &user.UpdatedAt, &user.DeletedAt)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// UpdatePhoneHash 更新手机号哈希（手机号授权更新）
func (r *UserRepo) UpdatePhoneHash(ctx context.Context, id, phoneHash, phoneHashSalt, phoneHashSHA256 string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE users SET phone_hash = $1, phone_hash_salt = $2, phone_hash_sha256 = $3, updated_at = NOW() WHERE id = $4`,
		phoneHash, phoneHashSalt, phoneHashSHA256, id,
	)
	return err
}

// SoftDelete 软删除用户（标记注销时间）
func (r *UserRepo) SoftDelete(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE users SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1`,
		id,
	)
	return err
}

// HardDelete 硬删除用户（彻底删除，账户注销用）
func (r *UserRepo) HardDelete(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM users WHERE id = $1`,
		id,
	)
	return err
}

// CountWaitingLocks 统计用户 WAITING 状态的心锁数量
func (r *UserRepo) CountWaitingLocks(ctx context.Context, userID string) (int, error) {
	var count int
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM heart_locks WHERE from_user_id = $1 AND status = 'WAITING'`,
		userID,
	).Scan(&count)
	return count, err
}
