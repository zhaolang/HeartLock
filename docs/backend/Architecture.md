# 文档信息

| 字段 | 内容 |
|---|---|
| 文档名称 | HeartLock（心锁）后端架构设计 |
| 文档编号 | ARCH-V1.0 |
| 状态 | 草稿 |
| 作者 | Codex |
| 创建日期 | 2026-07-07 |
| 最后更新 | 2026-07-07 |

---

## 1. Purpose（目的）

定义 HeartLock（心锁）后端 Go 服务的完整架构设计，包括项目结构、代码分层、中间件链、错误处理、配置加载和通信模式，为后端开发提供架构级参考。

---

## 2. Scope（范围）

涵盖 Go 项目目录结构、Handler → Service → Repository 三层架构、中间件注册顺序、错误类型体系、配置加载策略、华为 SDK 集成方案、Push 推送架构和测试策略。

---

## 3. Technology Stack（技术栈）

| 组件 | 选型 | 版本 | 说明 |
|---|---|---|---|
| 语言 | Go | 1.22+ | 编译快、部署简单、并发友好 |
| HTTP 框架 | chi 或标准库 net/http | latest | 轻量级，中间件链清晰；不选用 gin/echo 等重型框架 |
| 数据库驱动 | pgx | v5 | PostgreSQL 高性能驱动，支持连接池 |
| 数据库迁移 | golang-migrate | v4 | 文件式迁移，支持 up/down |
| JWT | golang-jwt | v5 | JWT 签发与验证 |
| 密码学 | 标准库 crypto/aes, crypto/rand | 标准库 | AES-256-GCM 加密 |
| 日志 | slog（Go 1.21+ 标准库） | 标准库 | 结构化 JSON 日志 |
| 配置 | envconfig / caarlos0/env | latest | 环境变量加载 |
| 测试 | testing + testify | latest | 标准测试 + 断言 |
| 容器化 | Docker + Docker Compose | — | 多阶段构建 |

---

## 4. Project Structure（项目目录结构）

```
server/
├── cmd/
│   └── server/
│       └── main.go                 # 应用入口：配置加载、依赖注入、启动服务
│
├── internal/
│   ├── config/
│   │   └── config.go               # 环境变量绑定（AppConfig 结构体）
│   │
│   ├── middleware/
│   │   ├── logging.go              # 请求日志（slog + 请求耗时）
│   │   ├── recovery.go             # panic 恢复
│   │   ├── cors.go                 # CORS 配置
│   │   ├── ratelimit.go            # 限流（令牌桶 / 滑动窗口）
│   │   ├── auth.go                 # JWT 鉴权 + Token 失效检测
│   │   └── requestid.go            # X-Request-ID 生成/透传
│   │
│   ├── handler/
│   │   ├── health.go               # GET /health
│   │   ├── auth.go                 # POST /auth/register, /auth/login, /auth/phone-authorize, DELETE /auth/account
│   │   ├── heartlock.go            # GET/POST /heart-locks, GET /heart-locks/:id, PATCH revoke, DELETE destroy
│   │   └── push.go                 # POST /push/token, DELETE /push/token
│   │
│   ├── service/
│   │   ├── auth_service.go         # 注册/登录/注销 业务逻辑
│   │   ├── lock_service.go         # 心锁 CRUD + 匹配检测引擎
│   │   └── push_service.go         # 华为 Push Kit 推送
│   │
│   ├── repository/
│   │   ├── user_repo.go            # 用户表 CRUD
│   │   ├── lock_repo.go            # 心锁表 CRUD + 匹配检测查询
│   │   └── push_repo.go            # Push Token 表 CRUD
│   │
│   ├── model/
│   │   ├── user.go                 # User 结构体 + 枚举
│   │   ├── lock.go                 # Lock 结构体 + 枚举（Status 类型）
│   │   └── errors.go               # 业务错误类型定义
│   │
│   ├── crypto/
│   │   ├── hash.go                 # bcrypt 加盐哈希（手机号指纹）
│   │   ├── encrypt.go              # AES-256-GCM 加解密 + 密钥管理
│   │   └── token.go                # JWT 签发与验证
│   │
│   └── dto/
│       ├── request.go              # 请求体结构体 + 验证标签
│       └── response.go             # 统一响应结构体 + 错误响应
│
├── migrations/
│   ├── 000001_create_users.up.sql
│   ├── 000001_create_users.down.sql
│   ├── 000002_create_heart_locks.up.sql
│   ├── 000002_create_heart_locks.down.sql
│   ├── 000003_create_push_tokens.up.sql
│   ├── 000003_create_push_tokens.down.sql
│   └── 000004_create_operation_logs.up.sql
│       └── 000004_create_operation_logs.down.sql
│
├── mocks/                          # mock 数据 / 测试桩
│   └── data.go
│
├── Dockerfile                      # 多阶段构建（参考 Deployment.md）
├── go.mod
├── go.sum
└── Makefile                        # 常用开发命令
```

---

## 5. Layered Architecture（三层架构）

### 5.1 架构分层

```
Handler（HTTP 层）
   │  请求解析、参数校验、响应写入
   │  不包含业务逻辑
   ▼
Service（业务层）
   │  业务规则编排、事务管理、匹配检测
   │  调用 Repository 获取数据
   │  调用 Crypto 处理加解密
   ▼
Repository（数据层）
   │  数据库 CRUD、参数化查询、事务
   │  不包含业务规则
   ▼
Database（PostgreSQL）
```

### 5.2 层间调用规则

| 规则 | 说明 |
|---|---|
| Handler → Service | Handler 调用 Service 处理业务，Service 返回结果或错误 |
| Service → Repository | Service 调用 Repository 存取数据 |
| Service → Service | 允许跨 Service 调用（如 LockService 调用 PushService 发通知） |
| Handler → Repository | ❌ 禁止直接调用，必须经过 Service 层 |
| Repository → Service | ❌ 禁止反向调用 |
| 同层互调 | ❌ 禁止同层循环依赖 |

### 5.3 依赖注入

所有依赖通过 `main.go` 中的依赖注入容器（手动 DI）初始化并传入：

```go
// main.go 伪代码
func main() {
    cfg := config.Load()
    db  := connectDB(cfg)
    kms := crypto.NewKMS(cfg.MasterKey)

    userRepo  := repository.NewUserRepo(db)
    lockRepo  := repository.NewLockRepo(db)
    pushRepo  := repository.NewPushRepo(db)

    authService     := service.NewAuthService(userRepo, kms)
    lockService     := service.NewLockService(lockRepo, userRepo, pushService, kms)
    pushService     := service.NewPushService(pushRepo)

    authHandler     := handler.NewAuthHandler(authService)
    lockHandler     := handler.NewLockHandler(lockService)
    healthHandler   := handler.NewHealthHandler(db)
    pushHandler     := handler.NewPushHandler(pushService)

    r := setupRouter(authHandler, lockHandler, healthHandler, pushHandler, cfg)
    server := &http.Server{Addr: ":" + cfg.Port, Handler: r}

    // 优雅关闭
    gracefulShutdown(server)
}
```

---

## 6. Middleware Chain（中间件链）

### 6.1 注册顺序

中间件按以下顺序注册，顺序不可随意改动：

```
1. RequestID      → 为每个请求生成/透传唯一 ID
2. Logging        → 记录请求路径、方法、耗时、状态码
3. Recovery       → panic 恢复，返回 500 而非崩溃
4. CORS           → 跨域设置
5. RateLimit      → 限流（全局 IP 限流）
6. Auth (可选)     → JWT 验证（部分路由跳过）
```

### 6.2 中间件实现要点

**RequestID：**

```go
func RequestID(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        id := r.Header.Get("X-Request-ID")
        if id == "" {
            id = uuid.New().String()
        }
        ctx := context.WithValue(r.Context(), CtxKeyRequestID, id)
        w.Header().Set("X-Request-ID", id)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

**Logging（结构化日志）：**

```go
func Logging(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        rw := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
        next.ServeHTTP(rw, r)
        slog.Info("request",
            "method", r.Method,
            "path", r.URL.Path,
            "status", rw.statusCode,
            "latency_ms", time.Since(start).Milliseconds(),
            "request_id", GetRequestID(r.Context()),
        )
    })
}
```

**RateLimit（令牌桶算法）：**

```go
// 使用 golang.org/x/time/rate 实现令牌桶限流
var limiter = rate.NewLimiter(rate.Every(time.Minute/60), 60) // 60 req/min

func RateLimit(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if !limiter.Allow() {
            writeJSON(w, http.StatusTooManyRequests, ErrorResponse{
                Code:    40001,
                Message: "请求过于频繁，请稍后重试",
                Data:    map[string]any{"retry_after": 30},
            })
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

---

## 7. Error Handling（错误处理）

### 7.1 错误类型体系

```go
// internal/model/errors.go

// AppError 是业务错误的基类
type AppError struct {
    Code    int    // 业务错误码（见 API.md 3.5）
    Message string // 用户可见的错误描述
    Err     error  // 内部错误（不返回给客户端）
}

func (e *AppError) Error() string {
    if e.Err != nil {
        return fmt.Sprintf("[%d] %s: %v", e.Code, e.Message, e.Err)
    }
    return fmt.Sprintf("[%d] %s", e.Code, e.Message)
}

func (e *AppError) Unwrap() error {
    return e.Err
}

// 预定义业务错误
var (
    ErrAuthFailed       = &AppError{Code: 40002, Message: "认证失败"}
    ErrPhoneRequired    = &AppError{Code: 40003, Message: "手机号未授权"}
    ErrNotFound         = &AppError{Code: 40004, Message: "资源不存在"}
    ErrLockLimit        = &AppError{Code: 40010, Message: "心锁已达上限（3/3），需要先撤回一个"}
    ErrDuplicateLock    = &AppError{Code: 40011, Message: "已经收藏过这份喜欢了"}
    ErrSelfLock         = &AppError{Code: 40012, Message: "不能向自己创建心锁"}
    ErrInvalidStatus    = &AppError{Code: 40013, Message: "心锁状态不允许此操作"}
    ErrAccountDeleted   = &AppError{Code: 40100, Message: "用户已注销"}
)
```

### 7.2 错误处理流程

```
Handler
  ↓ 请求验证失败 → 返回 40001 + field error
  ↓ Service 返回 AppError → 映射到 HTTP 状态码 + 业务错误码
  ↓ Service 返回未知错误 → 50001 + request_id（不暴露内部细节）
  ↓ panic → Recovery 中间件捕获 → 500

错误响应示例：
{
  "code": 40010,
  "message": "心锁已达上限（3/3），需要先撤回一个",
  "data": { "current_count": 3, "max_count": 3 },
  "request_id": "abc-123-def"
}
```

### 7.3 HTTP 状态码映射

| 业务场景 | HTTP 状态码 | 业务错误码 |
|---|---|---|
| 成功 | 200 / 201 | 0 |
| 请求参数错误 | 400 | 40001 |
| 认证失败（Token 无效/过期） | 401 | 40002 |
| 手机号未授权 | 403 | 40003 |
| 资源不存在 | 404 | 40004 |
| 业务规则冲突（已达上限等） | 409 | 40010-40013 |
| 限流 | 429 | 40001 (retry_after) |
| 用户已注销 | 410 | 40100 |
| 服务器内部错误 | 500 | 50001-50003 |

---

## 8. Huawei Account Kit Integration（华为账号集成）

### 8.1 服务端验证流程

```
App → 华为账号 SDK 登录 → 获取 auth code
App → POST /auth/register { huawei_credentials: auth_code, phone_number }
Server → 校验 auth code（调用华为 OAuth 2.0 Token Exchange API）
Server → 从华为获取 OpenID + 手机号
Server → 手机号加盐哈希
Server → 创建用户记录
Server → 签发 JWT
Server → 返回 token + 用户信息
```

### 8.2 华为 OAuth Token Exchange

```go
// 服务端调用华为 OAuth 2.0 API 验证 auth code 并获取用户信息
// 参考文档: https://developer.huawei.com/consumer/cn/doc/development/HMSCore-Guides/request-auth-code-0000001050168876

type HuaweiTokenResponse struct {
    AccessToken      string `json:"access_token"`
    ExpiresIn        int    `json:"expires_in"`
    IDToken          string `json:"id_token"`
    RefreshToken     string `json:"refresh_token"`
    Scope            string `json:"scope"`
    Error            string `json:"error"`
    ErrorDescription string `json:"error_description"`
}

type HuaweiUserInfo struct {
    OpenID      string `json:"openId"`
    UnionID     string `json:"unionId"`
    PhoneNumber string `json:"phoneNumber"`
    // 手机号需要 user.phone 权限才能获取
}

// 验证 auth code 并获取 OpenID
func VerifyHuaweiAuthCode(authCode string) (*HuaweiUserInfo, error) {
    // POST https://oauth-login.cloud.huawei.com/oauth2/v3/token
    // 参数: grant_type=authorization_code&code={authCode}&client_id={...}&client_secret={...}
    // 响应包含 id_token（JWT），解码后可获取 OpenID
    // 如需手机号，需在登录时申请 https://www.huawei.com/auth/account/user.phone 权限
}
```

### 8.3 华为账号 Server SDK

```
ohpm 包: @hw-hmscore/hms-account  /  REST API
推荐方式: 服务端使用 REST API 验证 token（避免引入 Android SDK）

流程:
1. 客户端通过华为 Account Kit 获取 auth code
2. 客户端将 auth code 发送给服务端
3. 服务端调用华为 OAuth 2.0 REST API 验证 auth code
4. 服务端从 id_token（JWT）中解析 OpenID 和手机号（如果授权）
5. 服务端使用 OpenID 作为用户唯一标识
```

---

## 9. Huawei Push Kit Integration（华为推送集成）

### 9.1 推送架构

```
服务端 → POST https://push-api.cloud.huawei.com/v1/{appId}/messages:send
  → 华为推送平台 → 推送通知到目标设备

推送达条件：
- 目标用户已登录
- 目标用户已注册 Push Token
- 仅匹配成功时发送
```

### 9.2 推送通知格式

```go
// 参考: https://developer.huawei.com/consumer/cn/doc/HMS-Plugin/push-kit-sending-messages-0000001827881173

type HuaweiPushRequest struct {
    ValidateOnly bool            `json:"validate_only"`
    Message      HuaweiMessage   `json:"message"`
}

type HuaweiMessage struct {
    Token        []string          `json:"token"`        // 目标设备 token 列表
    Data         string            `json:"data"`         // JSON 字符串，透传给 App
    Notification *HuaweiNotification `json:"notification,omitempty"`
    Android      *HuaweiAndroidConfig `json:"android,omitempty"`
}

type HuaweiNotification struct {
    Title string `json:"title"`
    Body  string `json:"body"`
}

// 匹配成功后的推送内容
func BuildMatchPushContent(partnerFirstLine string) HuaweiPushRequest {
    return HuaweiPushRequest{
        Message: HuaweiMessage{
            Notification: &HuaweiNotification{
                Title: "心锁已打开",
                Body:  truncateText(partnerFirstLine, 50), // 对方第一句话的前 50 字
            },
            Data: `{"type":"match","version":"1"}`,
        },
    }
}
```

### 9.3 Push Token 管理

| 操作 | 说明 |
|---|---|
| 注册 | 用户登录后，客户端获取华为 Push Token → POST /push/token |
| 更新 | Token 变更时重新注册 |
| 注销 | 用户注销时客户端 → DELETE /push/token → 服务端删除记录 |

### 9.4 Access Token 获取

华为 Push API 使用 OAuth 2.0 客户端凭证模式获取 Access Token：

```go
// 获取华为推送 Access Token
func GetHuaweiPushToken(clientId, clientSecret string) (string, error) {
    // POST https://oauth-login.cloud.huawei.com/oauth2/v3/token
    // 参数: grant_type=client_credentials&client_id={...}&client_secret={...}
    // 返回 access_token（有效期 3600 秒）
    // 注意: access_token 需要缓存并在过期前刷新
}
```

---

## 10. Match Detection Engine（匹配检测引擎）

### 10.1 检测时机

匹配检测在**每次创建心锁时**同步执行。创建心锁的 API 请求内部按以下步骤执行：

```go
func (s *LockService) CreateLock(ctx context.Context, userID uuid.UUID, req dto.CreateLockRequest) (*dto.CreateLockResponse, error) {
    // 1. 校验业务规则
    //    RULE-010: 同一用户对同一目标只能有一条记录
    //    RULE-011: WAITING 状态数 < 3
    //    RULE-012: 目标手机号不能是自己的
    //    RULE-013: 内容 1-500 字

    // 2. 加密内容
    encryptedContent, nonce := s.kms.Encrypt(req.Content)

    // 3. 计算目标手机号哈希
    targetHash := s.kms.HashPhone(req.TargetPhone)

    // 4. 创建心锁记录（状态 WAITING）
    lock, err := s.lockRepo.Create(ctx, userID, targetHash, encryptedContent, nonce)

    // 5. 匹配检测
    matchedLock, err := s.lockRepo.FindMatch(ctx, userID, targetHash)
    if matchedLock != nil {
        // 6. 双向匹配 → 同时更新两条记录为 MATCHED
        now := time.Now()
        err := s.lockRepo.MarkMatched(ctx, lock.ID, matchedLock.ID, now)

        // 7. 解密对方的内容
        theirContent := s.kms.Decrypt(matchedLock.EncryptedContent, matchedLock.ContentNonce)

        // 8. 异步推送双方通知
        go s.pushService.SendMatchNotification(ctx, userID, matchedLock.FromUserID)

        return &dto.CreateLockResponse{
            Status:      model.LockStatusMATCHED,
            Matched:     true,
            MatchedAt:   &now,
            TheirWords:  theirContent,
        }, nil
    }

    // 9. 未匹配 → 返回 WAITING
    return &dto.CreateLockResponse{
        Status:  model.LockStatusWAITING,
        Matched: false,
    }, nil
}
```

### 10.2 匹配检测 SQL

```sql
-- 查找是否存在一条 WAITING 心锁，满足：
-- 创建者 = 当前用户的手机号哈希对应的用户
-- 且 目标手机号指纹 = 当前用户的手机号指纹
SELECT hl.* FROM heart_locks hl
JOIN users u ON u.id = hl.from_user_id
WHERE hl.to_phone_hash = (SELECT phone_hash FROM users WHERE id = $1)   -- 目标 = 当前用户
  AND u.phone_hash = $2                                                  -- 创建者 = 当前用户的目标
  AND hl.status = 'WAITING'
LIMIT 1
```

---

## 11. Config Loading（配置加载）

### 11.1 环境变量绑定

使用 `caarlos0/env` 库将环境变量绑定到结构体：

```go
type AppConfig struct {
    // 应用
    Port     string `env:"APP_PORT"     envDefault:"8080"`
    Env      string `env:"APP_ENV"      envDefault:"development"`
    Version  string `env:"APP_VERSION"  envDefault:"1.0.0"`

    // 数据库
    DBHost     string `env:"DB_HOST"     envDefault:"localhost"`
    DBPort     string `env:"DB_PORT"     envDefault:"5432"`
    DBUser     string `env:"DB_USER"     envDefault:"heartlock"`
    DBPassword string `env:"DB_PASSWORD" envDefault:"heartlock_dev"`
    DBName     string `env:"DB_NAME"     envDefault:"heartlock"`
    DBSSLMode  string `env:"DB_SSLMODE"  envDefault:"disable"`

    // JWT
    JWTSecret     string `env:"JWT_SECRET"      envDefault:"dev-secret-change-in-production"`
    JWTExpiryHours int    `env:"JWT_EXPIRY_HOURS" envDefault:"720"`

    // 主密钥
    MasterKey string `env:"MASTER_KEY"`

    // 华为推送
    HuaweiPushAppID     string `env:"HUAWEI_PUSH_APP_ID"`
    HuaweiPushAppSecret string `env:"HUAWEI_PUSH_APP_SECRET"`
}
```

### 11.2 加载优先级

```
环境变量（最高）> .env 文件（开发环境）> 默认值（最低）
```

---

## 12. Testing Strategy（测试策略）

### 12.1 测试金字塔

```
    /\         E2E 测试（少量）
   /  \        覆盖核心用户场景
  /    \
 /──────\      集成测试（中等）
 │      │      覆盖 API + 数据库交互
 │      │
/────────\     单元测试（大量）
│        │     覆盖业务规则 + 加密 + 匹配检测
```

### 12.2 测试目录结构

```
internal/
├── crypto/
│   └── encrypt_test.go      # AES 加解密单元测试
│   └── hash_test.go         # bcrypt 哈希单元测试
│   └── token_test.go        # JWT 签发验证测试
├── service/
│   └── lock_service_test.go # 匹配检测引擎 + 业务规则测试
│   └── auth_service_test.go # 注册/登录/注销测试
└── handler/
    └── auth_test.go         # API 集成测试（HTTP + 数据库）
    └── heartlock_test.go    # 心锁 API 集成测试
```

### 12.3 测试数据库策略

```go
// 集成测试使用独立的测试数据库
// 测试开始前执行 migrate up
// 每个测试用例前后清理数据
// 使用 testify/suite 组织测试套件

func TestMain(m *testing.M) {
    // 1. 连接到测试数据库
    // 2. 执行迁移
    // 3. 运行测试
    // 4. 回滚迁移
    os.Exit(m.Run())
}
```

---

## 13. Graceful Shutdown（优雅关闭）

```go
func gracefulShutdown(server *http.Server) {
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    slog.Info("Shutting down server...")

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := server.Shutdown(ctx); err != nil {
        slog.Error("Server forced to shutdown", "error", err)
    }

    // 关闭数据库连接池
    db.Close()

    slog.Info("Server stopped")
}
```

---

## 14. API Route Table（路由表汇总）

```go
func setupRouter(
    authHandler *handler.AuthHandler,
    lockHandler *handler.LockHandler,
    healthHandler *handler.HealthHandler,
    pushHandler *handler.PushHandler,
    cfg *config.AppConfig,
) http.Handler {
    r := chi.NewRouter()

    // 全局中间件（按顺序）
    r.Use(middleware.RequestID)
    r.Use(middleware.Logging)
    r.Use(middleware.Recovery)
    r.Use(middleware.CORS)

    // 公开路由（无 JWT 鉴权）
    r.Group(func(r chi.Router) {
        r.Use(middleware.RateLimit)            // 全局限流
        r.Get("/health", healthHandler.Health)
    })

    // 认证路由（部分无需鉴权）
    r.Route("/v1", func(r chi.Router) {
        r.Group(func(r chi.Router) {
            // 无需登录
            r.Post("/auth/register", authHandler.Register)
            r.Post("/auth/login", authHandler.Login)
        })

        // 需 JWT 鉴权
        r.Group(func(r chi.Router) {
            r.Use(middleware.Auth)
            r.Post("/auth/phone-authorize", authHandler.AuthorizePhone)
            r.Delete("/auth/account", authHandler.DeleteAccount)

            r.Get("/heart-locks", lockHandler.List)
            r.Post("/heart-locks", lockHandler.Create)
            r.Get("/heart-locks/{id}", lockHandler.GetDetail)
            r.Patch("/heart-locks/{id}/revoke", lockHandler.Revoke)
            r.Delete("/heart-locks/{id}", lockHandler.Destroy)
            r.Post("/heart-locks/{id}/invitation-card", lockHandler.GenerateInvitationCard)

            r.Post("/push/token", pushHandler.RegisterToken)
            r.Delete("/push/token", pushHandler.DeleteToken)
        })
    })

    return r
}
```

---

## 15. Acceptance Criteria（验收标准）

| 编号 | 验收标准 | 关联章节 |
|---|---|---|
| AC-ARCH-001 | `go build ./cmd/server` 编译通过无错误 | 4 |
| AC-ARCH-002 | 中间件链按 RequestID → Logging → Recovery → CORS → RateLimit → Auth 顺序注册 | 6 |
| AC-ARCH-003 | 所有业务错误通过 AppError 类型返回，不泄漏内部错误信息 | 7 |
| AC-ARCH-004 | 创建心锁时同步执行匹配检测，匹配成功同时更新两条记录 | 10 |
| AC-ARCH-005 | 服务收到 SIGINT/SIGTERM 后 30 秒内完成优雅关闭 | 13 |
| AC-ARCH-006 | 路由表与 API.md 定义的端点完全一致 | 14 |

---

## 16. References（引用）

| 引用 | 说明 |
|---|---|
| [API.md](./API.md) | API 接口规范 |
| [Database.md](./Database.md) | 数据库设计 |
| [Security.md](./Security.md) | 安全架构 |
| [BusinessRules.md](../product/BusinessRules.md) | 业务规则 |
| [PRD.md](../product/PRD.md) | 产品需求文档 |
