# 文档信息

| 字段 | 内容 |
|---|---|
| 文档名称 | HeartLock（心锁）用户流程 |
| 文档编号 | UF-V1.0 |
| 状态 | 草稿 |
| 作者 | Codex |
| 创建日期 | 2026-07-07 |
| 最后更新 | 2026-07-07 |

---

## 1. Purpose（目的）

本文档定义 HeartLock（心锁）所有核心用户操作的完整流程，包括页面流转、状态变化和分支条件，为设计和开发提供统一的流程参考。

---

## 2. Scope（范围）

涵盖首次使用流程、心锁创建流程、匹配解锁流程、邀请裂变流程和账户注销流程。

---

## 3. Sequence Diagrams（时序图）

### 3.1 首次使用 & 登录流程

```mermaid
sequenceDiagram
    actor User
    participant App as HeartLock App
    participant Huawei as 华为账号SDK
    participant Server as HeartLock Backend

    User->>App: 打开App（首次启动）
    App->>App: 显示启动页 + 品牌Slogan
    App->>User: 展示登录页面
    User->>App: 点击"华为账号登录"
    App->>Huawei: 拉起华为账号登录
    Huawei->>User: 登录授权
    User->>Huawei: 确认授权
    Huawei->>App: 返回身份凭证
    App->>Huawei: 请求手机号授权
    Huawei->>User: 手机号授权弹窗
    User->>Huawei: 确认授权
    Huawei->>App: 返回手机号
    App->>Server: POST /auth/register {phone, credentials}
    Server->>Server: 验证、加盐哈希
    Server->>Server: 写入用户表
    Server->>App: 返回 token + 用户信息
    App->>User: 进入首页（空状态）
```

### 3.2 创建心锁流程

```mermaid
sequenceDiagram
    actor User
    participant App
    participant Server

    User->>App: 点击"放进心锁"按钮
    App->>App: 检查当前心锁数量 < 3
    App->>User: 显示创建表单
    User->>App: 输入对方手机号
    User->>App: 输入文字内容（1-500字）
    User->>App: 点击"放进心锁"
    App->>Server: POST /heart-locks {target_hash, content_encrypted}
    Server->>Server: 验证RULE-010（唯一性）
    Server->>Server: 验证RULE-011（数量上限）
    Server->>Server: 验证RULE-012（非自己）
    Server->>Server: 加密存储
    Server->>Server: 匹配检测（RULE-030）
    alt 匹配成功
        Server->>Server: 更新两条心锁为MATCHED
        Server->>App: 返回 {status: "matched", lock_id}
        Server->>Server: 推送Push通知
    else 未匹配
        Server->>App: 返回 {status: "waiting", lock_id}
    end
    App->>User: 显示结果
    alt 匹配成功
        App->>User: 播放解锁仪式
        App->>User: 显示对方写给自己的第一句话
    else 等待中
        App->>User: 显示"已放进心锁"
        App->>User: 显示邀请卡片引导
    end
```

### 3.3 匹配解锁仪式

```mermaid
sequenceDiagram
    actor UserA
    actor UserB
    participant AppA
    participant AppB
    participant Server

    Note over UserA,Server: UserA已创建心锁 -> WAITING

    UserB->>AppB: 创建心锁（目标=UserA手机号）
    AppB->>Server: POST /heart-locks
    Server->>Server: 匹配检测触发
    Server->>Server: 检测到双向匹配
    Server->>Server: 同时更新两条记录为MATCHED
    Server->>AppA: Push通知 + 匹配数据
    Server->>AppB: Push通知 + 匹配数据
    par 同时执行
        AppA->>UserA: 解锁仪式
        AppA->>AppA: 震动
        AppA->>AppA: 屏幕渐黑
        AppA->>AppA: 锁动画（缓慢打开）
        AppA->>UserA: 显示"心锁已打开"
        AppA->>UserA: 显示 "because 你们互相喜欢"
        AppA->>UserA: 显示UserB写给UserA的第一句话
    and
        AppB->>UserB: 解锁仪式
        AppB->>AppB: 震动
        AppB->>AppB: 屏幕渐黑
        AppB->>AppB: 锁动画（缓慢打开）
        AppB->>UserB: 显示"心锁已打开"
        AppB->>UserB: 显示 "because 你们互相喜欢"
        AppB->>UserB: 显示UserA写给UserB的第一句话
    end
```

### 3.4 邀请裂变流程

```mermaid
sequenceDiagram
    actor UserA
    actor UserB
    participant AppA
    participant AppB
    participant Server

    Note over UserA,Server: UserA已创建心锁（WAITING）

    UserA->>AppA: 进入心锁详情
    AppA->>UserA: 显示"生成邀请卡片"按钮
    UserA->>AppA: 点击生成
    AppA->>AppA: 生成海报（不含身份信息）
    AppA->>UserA: 预览海报
    UserA->>AppA: 保存/分享海报
    UserA->>UserB: 分享海报到微信等渠道
    UserB->>AppB: 扫描海报/点击"打开心锁"
    AppB->>AppB: 下载并安装HeartLock
    AppB->>UserB: 显示登录页
    UserB->>AppB: 华为账号登录 + 手机号授权
    UserB->>AppB: 进入首页
    AppB->>UserB: 显示创建心锁引导
    UserB->>AppB: 输入UserA的手机号
    UserB->>AppB: 创建心锁
    AppB->>Server: POST /heart-locks
    Server->>Server: 匹配检测 -> 成功
    Server->>AppA: Push通知
    Server->>AppB: 返回匹配成功
    Note over UserA,UserB: 双向匹配完成
```

### 3.5 心锁管理流程

```mermaid
stateDiagram-v2
    [*] --> WAITING: 创建心锁
    WAITING --> MATCHED: 对方也创建心锁（自动检测）
    WAITING --> REVOKED: 用户点击"撤回"
    REVOKED --> DESTROYED: 用户点击"永久删除"
    MATCHED --> [*]: 永久保留
    DESTROYED --> [*]: 彻底销毁

    note right of WAITING
        用户最多同时拥有3个
        同一目标手机号只能有1个
    end note

    note right of REVOKED
        元数据保留30天
        用于防重复检测
        30天后清除元数据
    end note
```

### 3.6 账户注销流程

```mermaid
sequenceDiagram
    actor User
    participant App
    participant Server

    User->>App: 进入个人中心
    User->>App: 点击"注销账户"
    App->>User: 确认弹窗 "确定注销？所有数据将永久删除"
    User->>App: 点击"确认注销"
    App->>User: 二次确认 "再次确认？此操作不可撤销"
    User->>App: 点击"确认注销"
    App->>Server: DELETE /auth/account
    Server->>Server: 删除用户表记录
    Server->>Server: 删除所有心锁记录（含加密内容）
    Server->>Server: 删除Push Token
    Server->>Server: 记录操作日志
    Server->>App: 返回成功
    App->>User: 回到登录页
```

---

## 4. Screen Flow（页面流程图）

```mermaid
flowchart TD
    S[启动页 Slogan] --> L[登录页]
    L --> H[首页]

    H --> C[创建心锁]
    C -->|成功 匹配| UM[解锁仪式]
    CM -->|已匹配| UMD[解锁详情]
    C -->|成功 未匹配| CW[等待中详情]
    CW -->|生成| IC[邀请卡片]
    
    H --> P[个人中心]
    P -->|注销| DC[注销确认]
    DC -->|最终确认| L
    
    IC -->|分享| SHARE[分享到社交渠道]
    SHARE -->|新用户下载| L
    
    subgraph 底部导航
        H
        CM
        P
    end
```

---

## 5. References（引用）

| 引用 | 说明 |
|---|---|
| [PRD.md](./PRD.md) | 产品需求文档 |
| [BusinessRules.md](./BusinessRules.md) | 业务规则 |
| [API.md](../backend/API.md) | API 接口 |
