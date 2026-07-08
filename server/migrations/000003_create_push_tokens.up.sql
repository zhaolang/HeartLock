CREATE TABLE push_tokens (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL REFERENCES users(id),
    push_token VARCHAR(512) NOT NULL,
    device_id  VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_push_tokens_user ON push_tokens(user_id);
CREATE UNIQUE INDEX idx_push_tokens_device ON push_tokens(user_id, device_id);
