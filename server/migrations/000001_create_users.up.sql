CREATE TABLE users (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    huawei_open_id  VARCHAR(128) NOT NULL,
    phone_hash      VARCHAR(255) NOT NULL,
    phone_hash_salt VARCHAR(64)  NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ  DEFAULT NULL
);
CREATE UNIQUE INDEX idx_users_huawei_open_id ON users(huawei_open_id);
CREATE UNIQUE INDEX idx_users_phone_hash ON users(phone_hash);
