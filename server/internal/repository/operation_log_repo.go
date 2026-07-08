package repository

import (
	"context"
	"encoding/json"

	"github.com/jackc/pgx/v5/pgxpool"
)

// OperationLogRepo 操作日志数据仓库
type OperationLogRepo struct {
	db *pgxpool.Pool
}

// NewOperationLogRepo 创建操作日志仓库
func NewOperationLogRepo(db *pgxpool.Pool) *OperationLogRepo {
	return &OperationLogRepo{db: db}
}

// Create 创建操作日志
func (r *OperationLogRepo) Create(ctx context.Context, userID *string, action string, resource *string, resourceID *string, detail json.RawMessage, ipAddress string) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO operation_logs (user_id, action, resource, resource_id, detail, ip_address)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		userID, action, resource, resourceID, detail, ipAddress,
	)
	return err
}

// CleanupOld 清理 7 天前的操作日志
func (r *OperationLogRepo) CleanupOld(ctx context.Context) (int64, error) {
	result, err := r.db.Exec(ctx,
		`DELETE FROM operation_logs WHERE created_at < NOW() - INTERVAL '7 days'`,
	)
	if err != nil {
		return 0, err
	}
	return result.RowsAffected(), nil
}
