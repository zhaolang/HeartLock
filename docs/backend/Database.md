# 文档信息

| 字段 | 内容 |
|---|---|
| 文档名称 | HeartLock（心锁）数据库设计 |
| 文档编号 | DB-V1.0 |
| 状态 | 草稿 |
| 作者 | Codex |
| 创建日期 | 2026-07-07 |
| 最后更新 | 2026-07-07 |

---

## 1. Purpose（目的）

定义 HeartLock（心锁）的数据库表结构、字段说明、索引策略和数据安全方案，为后端开发提供精确的数据层参考。

---

## 2. Scope（范围）

涵盖用户表、心锁表、Push Token 表、操作日志表的核心设计，以及加密方案、哈希方案、迁移策略和备份策略。

---

## 3. Definitions（术语）

| 术语 | 定义 |
|---|---|
| 手机号指纹 | 对用户手机号进行 bcrypt 加盐哈希后得到的标识字符串 |
| 加密内容 | 使用 AES-256-GCM 对心锁文字加密后的密文 |
| 数据密钥 | 用于加密心锁内容的对称密钥 |
| 主密钥 | 用于加密数据密钥的根密钥 |

---

## 4. Database Schema（数据库设计）

### 4.1 技术选型

- 数据库：PostgreSQL 16+
- 字符集：UTF-8
- 引擎：InnoDB 兼容 / PostgreSQL 默认存储引擎

### 4.2 实体关系概览

```mermaid
erDiagram
    users ||--o{ heart_locks : creates
    users ||--o{ push_tokens : registers
    users ||--o{ operation_logs : logs

    users {
        uuid id PK
        string huawei_open_id UK
        string phone_hash
        string phone_hash_sha256 UK
        string phone_hash_salt
        timestamp created_at
        timestamp updated_at
        timestamp deleted_at
    }

    heart_locks {
        uuid id PK
        uuid from_user_id FK
        string to_phone_hash
        bytea encrypted_content
        bytea content_nonce
        string status
        timestamp created_at
        timestamp updated_at
        timestamp matched_at
        timestamp revoked_at
        timestamp destroyed_at
    }

    push_tokens {
        uuid id PK
        uuid user_id FK
        string push_token
        string device_id
        timestamp created_at
        timestamp updated_at
    }

    operation_logs {
        uuid id PK
        uuid user_id FK
        string action
        string resource
        string resource_id
        json detail
        inet ip_address
        timestamp created_at
    }
```

### 4.3 表定义

#### 4.3.1 users（用户表）

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | UUID | PK, DEFAULT gen_random_uuid() | 用户唯一标识 |
| huawei_open_id | VARCHAR(128) | NOT NULL, UNIQUE | 华为账号 OpenID |
| phone_hash | VARCHAR(255) | NOT NULL, UNIQUE | bcrypt(phone + salt) |
| phone_hash_sha256 | VARCHAR(64) | UNIQUE | SHA-256(phone)，确定性哈希，用于匹配检测 |
| phone_hash_salt | VARCHAR(64) | NOT NULL | bcrypt salt |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 注册时间 |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 更新时间 |
| deleted_at | TIMESTAMPTZ | DEFAULT NULL | 注销时间（软删除标记用，不提供恢复） |

**索引：**

```sql
CREATE UNIQUE INDEX idx_users_huawei_open_id ON users(huawei_open_id);
CREATE UNIQUE INDEX idx_users_phone_hash ON users(phone_hash);
CREATE UNIQUE INDEX idx_users_phone_hash_sha256 ON users(phone_hash_sha256);
CREATE UNIQUE INDEX idx_users_phone_hash_sha256 ON users(phone_hash_sha256);
```

**说明：**

- phone_hash 是用户的手机号指纹（bcrypt）。phone_hash_sha256 是 SHA-256 哈希，用于匹配检测和查重。两个字段共同构成双层哈希方案：bcrypt 保证安全不可逆，SHA-256 保证匹配效率。
- 明文手机号永不落盘。
- deleted_at 仅在注销到彻底清理前的短暂窗口期内存在（清理后记录真实删除），不作为业务逻辑依赖。

#### 4.3.2 heart_locks（心锁表）

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | UUID | PK, DEFAULT gen_random_uuid() | 心锁唯一标识 |
| from_user_id | UUID | NOT NULL, FK -> users.id | 创建者用户 ID |
| to_phone_hash | VARCHAR(255) | NOT NULL | 目标用户的手机号指纹 |
| to_phone_hash_sha256 | VARCHAR(64) | NOT NULL | SHA-256(target_phone)，用于匹配检测和查重 |
| encrypted_content | BYTEA | -- | AES-256-GCM 加密内容（可为 NULL） |
| content_nonce | BYTEA | -- | AES-GCM 加密使用的 nonce |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'WAITING' | 状态：WAITING / MATCHED / REVOKED / DESTROYED |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 创建时间 |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 最后更新时间 |
| matched_at | TIMESTAMPTZ | DEFAULT NULL | 匹配成功时间 |
| revoked_at | TIMESTAMPTZ | DEFAULT NULL | 撤回时间 |
| destroyed_at | TIMESTAMPTZ | DEFAULT NULL | 永久删除时间 |

**索引：**

```sql
CREATE INDEX idx_heart_locks_from_user ON heart_locks(from_user_id);
CREATE INDEX idx_heart_locks_to_phone_hash ON heart_locks(to_phone_hash);
CREATE UNIQUE INDEX idx_heart_locks_from_to_unique ON heart_locks(from_user_id, to_phone_hash);
CREATE INDEX idx_heart_locks_to_phone_hash_sha256 ON heart_locks(to_phone_hash_sha256);
CREATE INDEX idx_heart_locks_match_check_new ON heart_locks(from_user_id, to_phone_hash_sha256, status) WHERE status = 'WAITING';
CREATE INDEX idx_heart_locks_match_check ON heart_locks(from_user_id, to_phone_hash, status)
    WHERE status = 'WAITING';
```

**说明：**

- `encrypted_content` 在状态为 REVOKED 时保留内容，在 DESTROYED 时设为 NULL。
- `to_phone_hash` 是 bcrypt 哈希版本。
- `to_phone_hash_sha256` 是 SHA-256 版本，用于匹配索引。
- `idx_heart_locks_from_to_unique` 保证同一用户对同一目标手机号只能有一条记录（RULE-010，基于 bcrypt hash）。
- `idx_heart_locks_match_check_new` 是匹配检测的性能关键索引（基于 SHA-256，性能更好）。
- `idx_heart_locks_match_check` 是匹配检测的性能关键索引（bcrypt 版本）。
- `idx_heart_locks_match_check_new` 是基于 SHA-256 的匹配检测索引（性能更好）。
- `matched_at` 要求两条匹配记录的该字段值相同（精确到毫秒）。

#### 4.3.3 push_tokens（推送 Token 表）

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | UUID | PK, DEFAULT gen_random_uuid() | 记录 ID |
| user_id | UUID | NOT NULL, FK -> users.id | 用户 ID |
| push_token | VARCHAR(512) | NOT NULL | 华为推送 Token |
| device_id | VARCHAR(128) | NOT NULL | 设备唯一标识 |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 创建时间 |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 更新时间 |

**索引：**

```sql
CREATE INDEX idx_push_tokens_user ON push_tokens(user_id);
CREATE UNIQUE INDEX idx_push_tokens_device ON push_tokens(user_id, device_id);
```


#### 4.3.4 operation_logs（操作日志表）

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | UUID | PK, DEFAULT gen_random_uuid() | 日志记录 ID |
| user_id | UUID | FK -> users.id, DEFAULT NULL | 操作用户 ID（未登录用户可为 NULL） |
| action | VARCHAR(64) | NOT NULL | 操作类型（如 user.register / lock.create / lock.revoke） |
| resource | VARCHAR(64) | DEFAULT NULL | 操作资源类型（如 user / heart_lock / account） |
| resource_id | UUID | DEFAULT NULL | 操作资源 ID |
| detail | JSONB | DEFAULT NULL | 操作详情（不包含敏感数据） |
| ip_address | INET | DEFAULT NULL | 请求来源 IP |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 日志记录时间 |

**索引：**

```sql
CREATE INDEX idx_operation_logs_user ON operation_logs(user_id);
CREATE INDEX idx_operation_logs_created ON operation_logs(created_at);
CREATE INDEX idx_operation_logs_action ON operation_logs(action);
```

**说明：**

- action 使用标准命名：`<资源>.<操作>`，如 `heart_lock.create`、`heart_lock.revoke`、`user.register`、`account.delete`
- detail 字段禁止存储密码、令牌、手机号明文等敏感数据
- 日志自动清理周期为 7 天（由定时任务触发）
- ip_address 记录来源 IP，用于安全审计和异常检测

### 4.4 加密方案

#### 4.4.1 心锁内容加密

```
加密流程:
1. 生成随机 AES-256 密钥 (32 bytes)
2. 生成随机 nonce (12 bytes for GCM)
3. AES-256-GCM 加密明文内容
4. 数据密钥使用主密钥加密后存储到密钥管理服务
5. ciphertext + nonce 存入 heart_locks 表

解密流程:
1. 从密钥管理服务解密数据密钥
2. 从 heart_locks 读取 ciphertext + nonce
3. AES-256-GCM 解密密文
```

#### 4.4.2 手机号哈希方案

```
哈希流程（双层哈希方案）:

第一层：bcrypt（不可逆，用于防暴力破解）
1. 生成随机 bcrypt salt (cost=12)
2. phone_hash = bcrypt(phone_number + salt, cost=12)
3. phone_hash + salt 存入 users 表

第二层：SHA-256（确定性哈希，用于匹配检测和查重）
1. phone_hash_sha256 = SHA-256(phone_number)
2. 存入 users.phone_hash_sha256

匹配检测（使用 SHA-256，性能优于 bcrypt 的逐行验证）:
1. 创建心锁时，计算 target_phone 的 SHA-256
2. 查找 heart_locks 中是否存在 WAITING 状态的心锁，满足：
   - to_phone_hash_sha256 = current_user.phone_hash_sha256
   - from_user.phone_hash_sha256 = target_user_phone_hash_sha256
3. 匹配成功后使用 bcrypt phone_hash 做二次验证（可选安全加固）

为什么需要两层哈希？
- bcrypt(cost=12)：约 250ms 计算，暴力破解成本极高
- SHA-256：纳秒级计算，适合精确匹配查询
- bcrypt 用于安全验证，SHA-256 用于匹配索引
```

### 4.5 数据清除策略

| 操作 | 行为 | 时间点 |
|---|---|---|
| 心锁撤回 | 加密内容保留，状态变更 | 立即 |
| 心锁永久删除 | encrypted_content = NULL，元数据保留 | 立即 |
| 心锁元数据清理 | 删除 REVOKED 超过 30 天的元数据 | 30天后定时任务 |
| 账户注销 | 删除 user、heart_locks、push_tokens 所有记录 | 立即 |
| 操作日志 | 保留操作日志 | 7天后定时清除 |


### 4.6 DDL 语句（建表脚本）

以下为完整的 PostgreSQL 16+ 建表脚本，可直接用于开发环境初始化和生产环境部署。

```sql
-- ============================================================
-- HeartLock Database Schema V1.0
-- PostgreSQL 16+
-- ============================================================

-- 1. users（用户表）
CREATE TABLE users (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    huawei_open_id  VARCHAR(128) NOT NULL,
    phone_hash      VARCHAR(255) NOT NULL,
    phone_hash_sha256 VARCHAR(64),
    phone_hash_salt VARCHAR(64)  NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ  DEFAULT NULL
);
CREATE UNIQUE INDEX idx_users_huawei_open_id ON users(huawei_open_id);
CREATE UNIQUE INDEX idx_users_phone_hash ON users(phone_hash);

-- 2. heart_locks（心锁表）
CREATE TABLE heart_locks (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id      UUID        NOT NULL REFERENCES users(id),
    to_phone_hash     VARCHAR(255) NOT NULL,
    to_phone_hash_sha256 VARCHAR(64),
    encrypted_content BYTEA,
    content_nonce     BYTEA,
    status            VARCHAR(20) NOT NULL DEFAULT 'WAITING'
                      CHECK (status IN ('WAITING','MATCHED','REVOKED','DESTROYED')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    matched_at        TIMESTAMPTZ DEFAULT NULL,
    revoked_at        TIMESTAMPTZ DEFAULT NULL,
    destroyed_at      TIMESTAMPTZ DEFAULT NULL
);
CREATE INDEX idx_heart_locks_from_user ON heart_locks(from_user_id);
CREATE INDEX idx_heart_locks_to_phone_hash ON heart_locks(to_phone_hash);
CREATE UNIQUE INDEX idx_heart_locks_from_to_unique ON heart_locks(from_user_id, to_phone_hash);
CREATE INDEX idx_heart_locks_match_check ON heart_locks(from_user_id, to_phone_hash, status) WHERE status = 'WAITING';
CREATE INDEX idx_heart_locks_to_phone_hash_sha256 ON heart_locks(to_phone_hash_sha256);
CREATE INDEX idx_heart_locks_match_check_new ON heart_locks(from_user_id, to_phone_hash_sha256, status) WHERE status = 'WAITING';

-- 3. push_tokens（推送 Token 表）
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

-- 4. operation_logs（操作日志表）
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
```

### 4.7 迁移策略

#### 4.7.1 技术选型

推荐使用 [golang-migrate](https://github.com/golang-migrate/migrate) 作为数据库迁移工具。

#### 4.7.2 迁移目录结构

```
server/
└── migrations/
    ├── 000001_create_users.up.sql
    ├── 000001_create_users.down.sql
    ├── 000002_create_heart_locks.up.sql
    ├── 000002_create_heart_locks.down.sql
    ├── 000003_create_push_tokens.up.sql
    ├── 000003_create_push_tokens.down.sql
    ├── 000004_create_operation_logs.up.sql
    ├── 000004_create_operation_logs.down.sql
    ├── 000005_add_phone_hash_sha256.up.sql
    ├── 000005_add_phone_hash_sha256.down.sql
    ├── 000006_add_to_phone_hash_sha256.up.sql
    └── 000006_add_to_phone_hash_sha256.down.sql
```

#### 4.7.3 常用迁移命令

```bash
# 安装迁移工具
brew install golang-migrate

# 创建新的迁移文件
migrate create -ext sql -dir server/migrations -seq create_users

# 执行全部迁移（up）
migrate -path server/migrations -database "postgres://user:pass@localhost:5432/heartlock?sslmode=disable" up

# 回滚最近一次迁移（down）
migrate -path server/migrations -database "postgres://user:pass@localhost:5432/heartlock?sslmode=disable" down 1

# 迁移到指定版本
migrate -path server/migrations -database "postgres://user:pass@localhost:5432/heartlock?sslmode=disable" goto 2

# 查看当前迁移版本
migrate -path server/migrations -database "postgres://user:pass@localhost:5432/heartlock?sslmode=disable" version
```

#### 4.7.4 迁移原则

- 每次数据库结构变更必须同时提供 up（向前）和 down（回滚）两个迁移文件
- 迁移文件在部署流水线中作为 CI/CD 的一步自动执行
- 禁止手动执行 DDL 操作修改生产数据库结构
- 数据迁移（如批量修改加密内容）应创建独立的迁移文件，与结构迁移分离

### 4.8 连接池配置

#### 4.8.1 推荐配置（Go + pgx）

```go
// Go 数据库连接池配置（database/sql 或 pgx）
db.SetMaxOpenConns(25)           // 最大打开连接数
db.SetMaxIdleConns(10)           // 最大空闲连接数
db.SetConnMaxLifetime(30 * time.Minute)  // 连接最大存活时间
db.SetConnMaxIdleTime(5 * time.Minute)   // 空闲连接超时
```

#### 4.8.2 配置说明

| 参数 | 推荐值 | 说明 |
|---|---|---|
| MaxOpenConns | 25 | 数据库最大并发连接数，超过此值的请求排队等待 |
| MaxIdleConns | 10 | 最大空闲连接数，保留部分连接避免频繁创建连接 |
| ConnMaxLifetime | 30m | 单个连接的最大存活时间，避免长时间连接不稳定 |
| ConnMaxIdleTime | 5m | 空闲连接保留时长，超时后关闭释放资源 |

#### 4.8.3 调整指南

- **高并发场景**（预计 100+ QPS）：MaxOpenConns 可提升至 50，同时调整 PostgreSQL `max_connections` 参数
- **低流量场景**（预计 < 10 QPS）：MaxOpenConns 可降低至 10，节省数据库连接资源
- 连接数设置不应超过 PostgreSQL `max_connections`（默认 100），建议保留 20% 冗余给管理连接
- 心锁创建操作（含匹配检测）需要 2-3 个数据库查询，建议为此接口预留专用连接池插槽

---

## 5. Acceptance Criteria（验收标准）

| 编号 | 验收标准 | 关联规则 |
|---|---|---|
| AC-DB-001 | 同一 (from_user_id, to_phone_hash) 组合只能有一条记录 | RULE-010 |
| AC-DB-002 | 同一用户 WAITING 状态的心锁数 <= 3 | RULE-011 |
| AC-DB-003 | 匹配检测查询响应时间 < 100ms | RULE-033 |
| AC-DB-004 | 加密内容在数据库中以 BYTEA 存储，不可读 | RULE-050 |
| AC-DB-005 | 明文手机号在任何数据库字段中均不可见 | RULE-052 |
| AC-DB-006 | 账户注销后，三张表对应的用户数据全部删除 | RULE-006 |
| AC-DB-007 | 数据库迁移可执行 up 和 down 双向操作，不丢失数据 | 4.6, 4.7 |

---

## 6. References（引用）

| 引用 | 说明 |
|---|---|
| [PRD.md](../product/PRD.md) | 产品需求文档 |
| [BusinessRules.md](../product/BusinessRules.md) | 业务规则 |
| [API.md](./API.md) | API 接口规范 |
| [Deployment.md](./Deployment.md) | 部署与运维规范 |
