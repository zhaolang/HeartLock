DROP INDEX IF EXISTS idx_users_phone_hash_sha256;
ALTER TABLE users DROP COLUMN IF EXISTS phone_hash_sha256;
