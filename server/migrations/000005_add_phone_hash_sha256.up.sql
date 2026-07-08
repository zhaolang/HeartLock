-- ============================================================
-- Migration: Add phone_hash_sha256 column for deterministic matching
-- ============================================================

-- 添加手机号 SHA-256 哈希列（用于匹配检测和查重）
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_hash_sha256 VARCHAR(64);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone_hash_sha256 ON users(phone_hash_sha256);
