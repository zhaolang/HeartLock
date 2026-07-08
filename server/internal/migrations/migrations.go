package migrations

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Migration 数据库迁移步骤
type Migration struct {
	Version int
	Name    string
	SQL     string
}

// AllMigrations 所有迁移
var AllMigrations = []Migration{
	{
		Version: 1,
		Name:    "create_users",
		SQL: `CREATE TABLE IF NOT EXISTS users (
			id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
			huawei_open_id  VARCHAR(128) NOT NULL,
			phone_hash      VARCHAR(255) NOT NULL,
			phone_hash_salt VARCHAR(64)  NOT NULL,
			created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
			updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
			deleted_at      TIMESTAMPTZ  DEFAULT NULL
		);
		CREATE UNIQUE INDEX IF NOT EXISTS idx_users_huawei_open_id ON users(huawei_open_id);
		CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone_hash ON users(phone_hash);`,
	},
	{
		Version: 2,
		Name:    "create_heart_locks",
		SQL: `CREATE TABLE IF NOT EXISTS heart_locks (
			id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
			from_user_id      UUID         NOT NULL REFERENCES users(id),
			to_phone_hash     VARCHAR(255) NOT NULL,
			to_phone_hash_sha256 VARCHAR(64),
			encrypted_content BYTEA,
			content_nonce     BYTEA,
			status            VARCHAR(20)  NOT NULL DEFAULT 'WAITING'
			                  CHECK (status IN ('WAITING','MATCHED','REVOKED','DESTROYED')),
			created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
			updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
			matched_at        TIMESTAMPTZ  DEFAULT NULL,
			revoked_at        TIMESTAMPTZ  DEFAULT NULL,
			destroyed_at      TIMESTAMPTZ  DEFAULT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_heart_locks_from_user ON heart_locks(from_user_id);
		CREATE INDEX IF NOT EXISTS idx_heart_locks_to_phone_hash ON heart_locks(to_phone_hash);
		CREATE INDEX IF NOT EXISTS idx_heart_locks_to_phone_hash_sha256 ON heart_locks(to_phone_hash_sha256);
		CREATE UNIQUE INDEX IF NOT EXISTS idx_heart_locks_from_to_unique ON heart_locks(from_user_id, to_phone_hash);
		CREATE INDEX IF NOT EXISTS idx_heart_locks_match_check ON heart_locks(from_user_id, to_phone_hash_sha256, status) WHERE status = 'WAITING';`,
	},
	{
		Version: 3,
		Name:    "create_push_tokens",
		SQL: `CREATE TABLE IF NOT EXISTS push_tokens (
			id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
			user_id    UUID         NOT NULL REFERENCES users(id),
			push_token VARCHAR(512) NOT NULL,
			device_id  VARCHAR(128) NOT NULL,
			created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
			updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
		);
		CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON push_tokens(user_id);
		CREATE UNIQUE INDEX IF NOT EXISTS idx_push_tokens_device ON push_tokens(user_id, device_id);`,
	},
	{
		Version: 4,
		Name:    "create_operation_logs",
		SQL: `CREATE TABLE IF NOT EXISTS operation_logs (
			id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
			user_id     UUID         REFERENCES users(id),
			action      VARCHAR(64)  NOT NULL,
			resource    VARCHAR(64),
			resource_id UUID,
			detail      JSONB,
			ip_address  INET,
			created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
		);
		CREATE INDEX IF NOT EXISTS idx_operation_logs_user ON operation_logs(user_id);
		CREATE INDEX IF NOT EXISTS idx_operation_logs_created ON operation_logs(created_at);
		CREATE INDEX IF NOT EXISTS idx_operation_logs_action ON operation_logs(action);`,
	},
	{
		Version: 5,
		Name:    "add_phone_hash_sha256",
		SQL: `ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_hash_sha256 VARCHAR(64);
		CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone_hash_sha256 ON users(phone_hash_sha256);`,
	},
}

// RunMigrations 执行所有待执行的迁移
func RunMigrations(db *pgxpool.Pool) error {
	// 创建迁移版本表
	_, err := db.Exec(context.Background(), `CREATE TABLE IF NOT EXISTS schema_migrations (
		version    INTEGER      PRIMARY KEY,
		name       VARCHAR(128) NOT NULL,
		applied_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
	)`)
	if err != nil {
		return fmt.Errorf("create schema_migrations table: %w", err)
	}

	for _, m := range AllMigrations {
		var exists bool
		err := db.QueryRow(context.Background(),
			`SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)`, m.Version,
		).Scan(&exists)
		if err != nil {
			return fmt.Errorf("check migration %d: %w", m.Version, err)
		}
		if exists {
			slog.Debug("migration already applied", "version", m.Version, "name", m.Name)
			continue
		}

		slog.Info("applying migration", "version", m.Version, "name", m.Name)
		start := time.Now()

		_, err = db.Exec(context.Background(), m.SQL)
		if err != nil {
			return fmt.Errorf("apply migration %d (%s): %w", m.Version, m.Name, err)
		}

		_, err = db.Exec(context.Background(),
			`INSERT INTO schema_migrations (version, name) VALUES ($1, $2)`,
			m.Version, m.Name,
		)
		if err != nil {
			return fmt.Errorf("record migration %d: %w", m.Version, err)
		}

		slog.Info("migration applied", "version", m.Version, "name", m.Name,
			"duration_ms", time.Since(start).Milliseconds())
	}

	slog.Info("all migrations applied successfully")
	return nil
}
