# 文档信息

| 字段 | 内容 |
|---|---|
| 文档名称 | HeartLock（心锁）API 接口规范 |
| 文档编号 | API-V1.1 |
| 状态 | 草稿 |
| 作者 | Codex |
| 创建日期 | 2026-07-07 |
| 最后更新 | 2026-07-07（第二版） |

---

## 1. Purpose（目的）

定义 HeartLock（心锁）后端 API 的完整接口规范，包括请求格式、响应格式、认证方式和所有端点定义，为前后端开发提供精确的契约。

---

## 2. Scope（范围）

涵盖认证模块、心锁管理模块、匹配模块、用户管理模块的所有 RESTful API 端点，以及健康检查、CORS、限流、分页等通用约定。

---

## 3. General Conventions（通用约定）

### 3.1 基础 URL

```
生产环境: https://api.heartlock.app/v1
开发环境: https://dev-api.heartlock.app/v1
```

### 3.2 认证方式

```
Authorization: Bearer <jwt_token>
```

- 所有 API（除 /auth 相关外）均需携带 JWT Token
- JWT 有效期：30 天
- Token 在用户注销时立即失效

### 3.3 请求头

```
Content-Type: application/json
Accept: application/json
X-Request-ID: <uuid>  // 用于链路追踪
```

### 3.4 响应格式

**成功响应：**

```json
{
  "code": 0,
  "message": "success",
  "data": { ... },
  "request_id": "uuid"
}
```

**错误响应：**

```json
{
  "code": 40001,
  "message": "具体错误信息",
  "data": null,
  "request_id": "uuid"
}
```

### 3.5 错误码

| 错误码 | 含义 |
|---|---|
| 0 | 成功 |
| 40001 | 请求参数错误 |
| 40002 | 认证失败（Token 无效/过期） |
| 40003 | 手机号未授权 |
| 40004 | 资源不存在 |
| 40010 | 心锁已达上限（超过 3 个） |
| 40011 | 已向该用户创建过心锁 |
| 40012 | 不能向自己创建心锁 |
| 40013 | 心锁状态不允许此操作 |
| 40020 | 匹配检测异常 |
| 40030 | 邀请卡片已存在（每个心锁仅可生成一张） |
| 40100 | 用户已注销 |
| 50001 | 服务器内部错误 |
| 50002 | 数据库操作异常 |
| 50003 | 加密/解密失败 |


### 3.6 CORS 配置

#### 3.6.1 允许的来源

```
Access-Control-Allow-Origin: https://heartlock.app
Access-Control-Allow-Origin: https://api.heartlock.app
```

- 生产环境仅允许上述两个来源
- 开发环境允许 `*`，但仅限本地开发
- 禁止在生产环境使用通配符来源

#### 3.6.2 允许的方法

```
Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS
```

#### 3.6.3 允许的请求头

```
Access-Control-Allow-Headers: Content-Type, Authorization, X-Request-ID
```

#### 3.6.4 预检请求（OPTIONS）

- 所有 CORS 预检请求统一返回 204 No Content
- 预检缓存时间：`Access-Control-Max-Age: 86400`（24 小时）

### 3.7 请求验证中间件规范

所有 API 请求必须经过统一的请求验证中间件。验证规则如下：

#### 3.7.1 输入验证规则

| 字段类型 | 验证规则 | 错误码 |
|---|---|---|
| 手机号 | 必填，11 位数字，仅以 1 开头 | 40001 |
| 心锁内容 | 1-500 字符，禁止纯空格 | 40001 |
| 心锁状态 | 仅允许 WAITING / MATCHED / REVOKED / DESTROYED | 40001 |
| 页码 | >= 1 的整数 | 40001 |
| 每页数量 | 1-50 的整数 | 40001 |

#### 3.7.2 安全过滤

- 所有字符串输入进行 HTML 转义（防 XSS）
- 禁止 SQL 关键字注入（防 SQL 注入，但最终防护依赖参数化查询）
- 输入长度超过限制时直接拒绝，不截断

#### 3.7.3 统一错误响应

```json
{
  "code": 40001,
  "message": "target_phone: 手机号格式不正确，需为 11 位数字",
  "data": {
    "field": "target_phone",
    "reason": "invalid_format"
  },
  "request_id": "uuid"
}
```

### 3.8 分页规范

#### 3.8.1 标准分页（默认方式）

使用 page / page_size 参数，适用于大多数列表查询。

| 参数 | 类型 | 默认值 | 最大值 | 说明 |
|---|---|---|---|---|
| page | int | 1 | -- | 页码，从 1 开始 |
| page_size | int | 20 | 50 | 每页记录数 |

**响应格式：**

```json
{
  "code": 0,
  "data": {
    "items": [ ... ],
    "total": 42,
    "page": 1,
    "page_size": 20,
    "total_pages": 3
  }
}
```

#### 3.8.2 游标分页（可选，用于大数据集）

| 参数 | 类型 | 说明 |
|---|---|---|
| cursor | string | 上一页最后一条记录的 ID 或排序字段值 |
| limit | int | 每页数量，默认 20，最大 50 |

**响应格式：**

```json
{
  "code": 0,
  "data": {
    "items": [ ... ],
    "next_cursor": "uuid_of_last_item",
    "has_more": true
  }
}
```

**建议：** 心锁列表默认使用标准分页（用户数据量小），操作日志查询使用游标分页（数据量大）。

### 3.9 限流策略

| 层级 | 粒度 | 限制 | 说明 |
|---|---|---|---|
| 全局 IP | 每 IP | 60 次/分钟 | 防止单个 IP 的恶意请求 |
| 创建心锁 | 每用户 | 10 次/小时 | 防止批量创建心锁（RULE-011 已限制 3 个，此限流是额外防护） |
| 登录/注册 | 每 IP | 20 次/小时 | 防止暴力登录尝试 |
| 手机号验证 | 每 IP | 5 次/分钟 | 防止手机号枚举攻击 |

**限流响应：**

```json
{
  "code": 40001,
  "message": "请求过于频繁，请稍后重试",
  "data": {
    "retry_after": 30
  },
  "request_id": "uuid"
}
```

**HTTP 响应头：**

```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1625678900
```


### 3.10 API 版本策略

| 策略 | 说明 |
|---|---|
| URL 路径版本 | `/v1/` 作为版本前缀 |
| 当前版本 | v1（第一个正式版本） |
| 兼容性 | 同一版本内不引入 breaking change |
| 废弃通知 | API 废弃后保留 6 个月，响应头添加 `Sunset: <date>` |
| 版本生命周期 | v1 至少支持到 2027-12-31 |

**版本标识响应头：**

```
API-Version: 1.0.0
Sunset: Sat, 31 Dec 2027 23:59:59 GMT
```

### 3.11 请求 ID 传播规范

| 场景 | 行为 |
|---|---|
| 客户端请求 | 可选在 Header 中传入 X-Request-ID |
| 服务端缺失 | 自动生成 UUID v4 |
| 日志关联 | 所有日志条目包含 request_id 字段 |
| 错误响应 | 错误响应中返回 request_id 用于排查 |
| 下游调用 | 调用华为 REST API 时透传 request_id |

### 3.12 错误码补充

以下为 v1.1 新增的补充错误码：

| 错误码 | 含义 | 触发场景 |
|---|---|---|
| 40005 | 华为账号验证失败 | auth code 无效或过期 |
| 40006 | 华为推送 Token 无效 | push_token 格式不正确或已过期 |
| 40101 | 用户已注销（手机号可再检测） | 匹配检测时发现对方用户已注销 |
| 50004 | 华为 API 调用失败 | 调用华为 OAuth/Push API 返回错误 |
| 50005 | 密钥管理服务不可用 | 主密钥无法访问 |



---

## 4. API Endpoints（接口定义）

### 4.1 认证模块


#### GET /health

健康检查端点。用于 Docker 容器存活探针（liveness）和就绪探针（readiness）。

**响应：**

```json
{
  "code": 0,
  "data": {
    "status": "healthy",
    "version": "1.0.0",
    "db_connected": true,
    "uptime_seconds": 3600,
    "timestamp": "2026-07-07T10:00:00Z"
  }
}
```

**校验规则：**
- `status` 为 "healthy" 时表示服务正常
- `db_connected` 为 true 时表示数据库连接正常，否则触发告警
- 服务启动后 **前 5 秒** 允许 `db_connected = false`（启动阶段）
- Docker Compose 配置中：liveness 探针间隔 30s，initialDelaySeconds=10

---


#### POST /auth/register

用户注册（首次华为账号登录 + 手机号授权后调用）。

**请求体：**

```json
{
  "huawei_credentials": "华为账号授权凭证",
  "phone_number": "13800138000"
}
```

**响应：**

```json
{
  "code": 0,
  "data": {
    "token": "jwt_token_string",
    "user": {
      "id": "uuid",
      "heart_lock_count": 0,
      "created_at": "2026-07-07T10:00:00Z"
    }
  }
}
```

**关联业务规则：** RULE-001, RULE-002, RULE-003

---

#### POST /auth/login

用户登录（非首次，已有账户）。

**请求体：**

```json
{
  "huawei_credentials": "华为账号授权凭证"
}
```

**响应：**

```json
{
  "code": 0,
  "data": {
    "token": "jwt_token_string",
    "user": {
      "id": "uuid",
      "phone_authorized": true,
      "heart_lock_count": 1,
      "max_heart_lock": 3
    }
  }
}
```

**说明：** login 不会重新请求手机号授权。

---

#### POST /auth/phone-authorize

额外请求手机号授权（注册时未授权的补充接口）。

**请求体：**

```json
{
  "phone_number": "13800138000"
}
```

---

#### DELETE /auth/account

注销账户。

**请求头：** Authorization: Bearer \<token\>

**响应：**

```json
{
  "code": 0,
  "message": "账户已注销，所有数据已删除"
}
```

**关联业务规则：** RULE-004, RULE-005, RULE-006

---

### 4.2 心锁管理模块

#### GET /heart-locks

获取当前用户的心锁列表。

**查询参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| status | string | 否 | 筛选状态：WAITING/MATCHED/REVOKED |
| page | int | 否 | 页码，默认 1 |
| page_size | int | 否 | 每页数量，默认 20，最大 50 |

**响应：**

```json
{
  "code": 0,
  "data": {
    "locks": [
      {
        "id": "uuid",
        "status": "WAITING",
        "to_phone_prefix": "138****8000",
        "content_preview": null,
        "created_at": "2026-07-07T10:00:00Z",
        "waiting_days": 3
      }
    ],
    "total": 1,
    "page": 1,
    "page_size": 20,
    "current_count": 1,
    "max_count": 3
  }
}
```

**说明：**
- MATCHED 状态的心锁才返回 content_preview（对方第一句话前 50 字）
- WAITING/REVOKED 状态的心锁 content_preview = null
- to_phone_prefix 展示手机号前三位 + **** + 后四位

---

#### POST /heart-locks

创建心锁。

**请求体：**

```json
{
  "target_phone": "13800138001",
  "content": "我喜欢你三年了。"
}
```

**校验规则（服务端）：**
1. target_phone 不能为空（RULE-012）
2. target_phone 不能等于当前用户手机号（RULE-012b）
3. content 长度 1-500 字（RULE-013）
4. 未向该 target_phone 创建过心锁（RULE-010）
5. 当前 WAITING 心锁数 < 3（RULE-011）

**响应（未匹配）：**

```json
{
  "code": 0,
  "data": {
    "id": "uuid",
    "status": "WAITING",
    "matched": false,
    "current_count": 2,
    "max_count": 3
  }
}
```

**响应（匹配成功）：**

```json
{
  "code": 0,
  "data": {
    "id": "uuid",
    "status": "MATCHED",
    "matched": true,
    "matched_at": "2026-07-07T10:00:00.123Z",
    "their_words": "我也喜欢你很久了。",
    "current_count": 1,
    "max_count": 3
  }
}
```

**关联业务规则：** RULE-010 ~ RULE-014, RULE-030 ~ RULE-033

---

#### GET /heart-locks/:id

获取心锁详情。

**响应（WAITING）：**

```json
{
  "code": 0,
  "data": {
    "id": "uuid",
    "status": "WAITING",
    "to_phone_prefix": "138****8000",
    "created_at": "2026-07-07T10:00:00Z",
    "waiting_days": 3,
    "can_revoke": true,
    "can_destroy": false,
    "has_invitation_card": false
  }
}
```

**响应（MATCHED）：**

```json
{
  "code": 0,
  "data": {
    "id": "uuid",
    "status": "MATCHED",
    "to_phone_prefix": "138****8000",
    "created_at": "2026-07-07T10:00:00Z",
    "matched_at": "2026-07-07T10:00:00.123Z",
    "their_words": "对方写给自己的完整内容（解密后）",
    "my_words": "自己当初写的内容（解密后）",
    "can_revoke": false,
    "can_destroy": false
  }
}
```

---

#### PATCH /heart-locks/:id/revoke

撤回心锁（WAITING → REVOKED）。

**响应：**

```json
{
  "code": 0,
  "data": {
    "id": "uuid",
    "status": "REVOKED",
    "revoked_at": "2026-07-07T10:00:00Z"
  }
}
```

**关联业务规则：** RULE-020, RULE-023

---

#### DELETE /heart-locks/:id

永久删除心锁（REVOKED → DESTROYED）。

**响应：**

```json
{
  "code": 0,
  "data": {
    "id": "uuid",
    "status": "DESTROYED"
  }
}
```

**关联业务规则：** RULE-020, RULE-024

---

### 4.3 邀请卡片模块

#### POST /heart-locks/:id/invitation-card

生成心锁的邀请卡片。每个心锁仅可生成一张（RULE-063）。

**响应：**

```json
{
  "code": 0,
  "data": {
    "card_id": "uuid",
    "card_url": "https://api.heartlock.app/v1/cards/uuid",
    "created_at": "2026-07-07T10:00:00Z"
  }
}
```

---

### 4.4 Push Token 模块

#### POST /push/token

注册设备 Push Token。

**请求体：**

```json
{
  "push_token": "huawei_push_token_string",
  "device_id": "device_uuid"
}
```

---

#### DELETE /push/token

注销设备 Push Token。

**请求体：**

```json
{
  "device_id": "device_uuid"
}
```

---

### 4.5 推送通知回调（补充）

#### POST /push/callback

华为推送状态回调端点（由华为推送平台调用）。用于追踪推送送达状态。此端点为可选实现，初期可跳过。

**请求体：** 华为 Push Kit 标准回调格式。

**响应：**

```json
{
  "code": 0
}
```

**配置方式：**
1. 登录华为 AppGallery Connect
2. 进入推送服务 → 回调地址配置
3. 填入 `https://api.heartlock.app/v1/push/callback`
4. 选择需要回调的事件类型（送达、点击、清除）

**说明：**
- 此端点仅在需要追踪推送统计数据时实现
- 不影响核心业务逻辑（匹配检测、解锁仪式等）
- 回调验证：需校验请求来源是否为华为官方 IP 范围


## 5. Acceptance Criteria（验收标准）

| 编号 | 验收标准 | 关联端点 |
|---|---|---|
| AC-API-001 | POST /heart-locks 在目标已有人对你 WAITING 时，立即返回 matched=true | POST /heart-locks |
| AC-API-002 | 同一用户重复创建心锁返回 40011 错误 | POST /heart-locks |
| AC-API-003 | WAITING 满 3 个时再次创建返回 40010 错误 | POST /heart-locks |
| AC-API-004 | PATCH revoke 仅在 WAITING 状态可用 | PATCH /heart-locks/:id/revoke |
| AC-API-005 | DELETE destroy 仅在 REVOKED 状态可用 | DELETE /heart-locks/:id |
| AC-API-006 | GET /heart-locks 始终不返回明文手机号 | GET /heart-locks |
| AC-API-007 | DELETE /auth/account 删除所有用户数据 | DELETE /auth/account |
| AC-API-008 | GET /health 返回 healthy 状态且 db_connected = true | GET /health |
| AC-API-009 | 请求参数校验失败返回 40001 及 field/reason 信息 | 全部端点 |
| AC-API-010 | 创建心锁频率超过 10 次/小时返回限流响应 | POST /heart-locks |

---

## 6. References（引用）

| 引用 | 说明 |
|---|---|
| [BusinessRules.md](../product/BusinessRules.md) | 业务规则 |
| [Database.md](./Database.md) | 数据库设计 |
| [PRD.md](../product/PRD.md) | 产品需求文档 |
| [Deployment.md](./Deployment.md) | 部署与运维规范 |
