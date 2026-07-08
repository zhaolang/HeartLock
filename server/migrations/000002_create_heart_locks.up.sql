CREATE TABLE heart_locks (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id      UUID         NOT NULL REFERENCES users(id),
    to_phone_hash     VARCHAR(255) NOT NULL,
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
CREATE INDEX idx_heart_locks_from_user ON heart_locks(from_user_id);
CREATE INDEX idx_heart_locks_to_phone_hash ON heart_locks(to_phone_hash);
CREATE UNIQUE INDEX idx_heart_locks_from_to_unique ON heart_locks(from_user_id, to_phone_hash);
CREATE INDEX idx_heart_locks_match_check ON heart_locks(from_user_id, to_phone_hash, status) WHERE status = 'WAITING';
