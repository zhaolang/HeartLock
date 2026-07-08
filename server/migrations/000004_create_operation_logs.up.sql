CREATE TABLE operation_logs (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID         REFERENCES users(id),
    action      VARCHAR(64)  NOT NULL,
    resource    VARCHAR(64),
    resource_id UUID,
    detail      JSONB,
    ip_address  INET,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_operation_logs_user ON operation_logs(user_id);
CREATE INDEX idx_operation_logs_created ON operation_logs(created_at);
CREATE INDEX idx_operation_logs_action ON operation_logs(action);
