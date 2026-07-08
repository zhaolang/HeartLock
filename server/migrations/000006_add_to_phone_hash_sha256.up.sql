-- ============================================================
-- Migration: Add to_phone_hash_sha256 column to heart_locks
-- ============================================================

ALTER TABLE heart_locks ADD COLUMN IF NOT EXISTS to_phone_hash_sha256 VARCHAR(64);

-- 索引用于匹配检测时的快速查询
CREATE INDEX IF NOT EXISTS idx_heart_locks_to_phone_hash_sha256 ON heart_locks(to_phone_hash_sha256);

-- 新的匹配检测索引（基于确定性哈希，性能更好）
CREATE INDEX IF NOT EXISTS idx_heart_locks_match_check_new ON heart_locks(from_user_id, to_phone_hash_sha256, status) WHERE status = 'WAITING';
