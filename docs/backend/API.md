# 文档信息

| 字段 | 内容 |
|---|---|
| 文档名称 | HeartLock（心锁）API 接口规范 |
| 文档编号 | API-V1.0 |
| 状态 | 草稿 |
| 作者 | Codex |
| 创建日期 | 2026-07-07 |
| 最后更新 | 2026-07-07 |

---

## 1. Purpose（目的）

定义 HeartLock（心锁）后端 API 的完整接口规范，包括请求格式、响应格式、认证方式和所有端点定义，为前后端开发提供精确的契约。

---

## 2. Scope（范围）

涵盖认证模块、心锁管理模块、匹配模块、用户管理模块的所有 RESTful API 端点。

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
| 40100 | 用户已注销 |

---

## 4. API Endpoints（接口定义）

### 4.1 认证模块

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

---

## 6. References（引用）

| 引用 | 说明 |
|---|---|
| [BusinessRules.md](../product/BusinessRules.md) | 业务规则 |
| [Database.md](./Database.md) | 数据库设计 |
| [PRD.md](../product/PRD.md) | 产品需求文档 |
