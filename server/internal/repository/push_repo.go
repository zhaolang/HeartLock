package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/zhaolang/heartlock/internal/model"
)

// PushRepo 推送 Token 数据仓库
type PushRepo struct {
	db *pgxpool.Pool
}

// NewPushRepo 创建推送 Token 仓库
func NewPushRepo(db *pgxpool.Pool) *PushRepo {
	return &PushRepo{db: db}
}

// Create 创建推送 Token
func (r *PushRepo) Create(ctx context.Context, userID, pushToken, deviceID string) (*model.PushToken, error) {
	token := &model.PushToken{}
	err := r.db.QueryRow(ctx,
		`INSERT INTO push_tokens (user_id, push_token, device_id)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (user_id, device_id) DO UPDATE SET push_token = $2, updated_at = NOW()
		 RETURNING id, user_id, push_token, device_id, created_at, updated_at`,
		userID, pushToken, deviceID,
	).Scan(&token.ID, &token.UserID, &token.PushToken, &token.DeviceID, &token.CreatedAt, &token.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return token, nil
}

// FindByUserID 获取用户的所有推送 Token
func (r *PushRepo) FindByUserID(ctx context.Context, userID string) ([]*model.PushToken, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, user_id, push_token, device_id, created_at, updated_at
		 FROM push_tokens WHERE user_id = $1`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []*model.PushToken
	for rows.Next() {
		t := &model.PushToken{}
		err := rows.Scan(&t.ID, &t.UserID, &t.PushToken, &t.DeviceID, &t.CreatedAt, &t.UpdatedAt)
		if err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, nil
}

// DeleteByUserID 删除用户的所有推送 Token（账户注销用）
func (r *PushRepo) DeleteByUserID(ctx context.Context, userID string) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM push_tokens WHERE user_id = $1`,
		userID,
	)
	return err
}

// DeleteByDevice 按设备删除推送 Token
func (r *PushRepo) DeleteByDevice(ctx context.Context, userID, deviceID string) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM push_tokens WHERE user_id = $1 AND device_id = $2`,
		userID, deviceID,
	)
	return err
}
