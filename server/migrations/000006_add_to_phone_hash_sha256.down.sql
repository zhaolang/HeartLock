DROP INDEX IF EXISTS idx_heart_locks_match_check_new;
DROP INDEX IF EXISTS idx_heart_locks_to_phone_hash_sha256;
ALTER TABLE heart_locks DROP COLUMN IF EXISTS to_phone_hash_sha256;
