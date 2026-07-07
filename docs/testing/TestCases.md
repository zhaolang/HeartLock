# 文档信息

| 字段 | 内容 |
|---|---|
| 文档名称 | HeartLock（心锁）测试用例 |
| 文档编号 | TC-V1.0 |
| 状态 | 草稿 |
| 作者 | Codex |
| 创建日期 | 2026-07-07 |
| 最后更新 | 2026-07-07 |

---

## 1. Purpose（目的）

定义 HeartLock（心锁）的核心测试用例，覆盖所有业务规则、API 端点和 UI 交互的测试场景。

---

## 2. Scope（范围）

涵盖单元测试、集成测试、UI 测试和端到端测试。本文档为 V1.0 测试框架，后续逐步补充。

---

## 3. Test Categories（测试分类）

### 3.1 单元测试

| 测试编号 | 测试内容 | 关联规则 |
|---|---|---|
| TC-UNIT-001 | 手机号哈希：相同手机号+相同 salt → 相同 hash | RULE-052 |
| TC-UNIT-002 | 手机号哈希：不同手机号 → 不同 hash | RULE-052 |
| TC-UNIT-003 | AES-256-GCM 加密：加密后密文 ≠ 明文 | RULE-050 |
| TC-UNIT-004 | AES-256-GCM 解密：解密后 = 原始明文 | RULE-050 |
| TC-UNIT-005 | 匹配检测算法：正确检测双向 WAITING | RULE-030 ~ RULE-033 |
| TC-UNIT-006 | 匹配检测算法：正确跳过非 WAITING 记录 | RULE-031 |
| TC-UNIT-007 | 状态转换：仅 WAITING 可 REVOKE | RULE-020 |
| TC-UNIT-008 | 状态转换：仅 REVOKED 可 DESTROY | RULE-020 |

### 3.2 API 集成测试

| 测试编号 | 测试内容 | 预期 |
|---|---|---|
| TC-API-001 | POST /auth/register 正常注册 | 201 + JWT Token |
| TC-API-002 | POST /auth/register 重复注册 | 400 + 错误码 |
| TC-API-003 | POST /heart-locks 正常创建 | 201 + WAITING |
| TC-API-004 | POST /heart-locks 重复创建（同目标）| 400 + 40011 |
| TC-API-005 | POST /heart-locks 超过上限 | 400 + 40010 |
| TC-API-006 | PATCH /heart-locks/:id/revoke 正常撤回 | 200 + REVOKED |
| TC-API-007 | DELETE /heart-locks/:id 永久删除 | 200 + DESTROYED |
| TC-API-008 | 匹配检测集成：A→B + B→A 触发 MATCHED | 两条记录同时 MATCHED |
| TC-API-009 | DELETE /auth/account 注销后数据不可查 | 404 + 40100 |
| TC-API-010 | 未授权调用需认证 | 401 |

### 3.3 UI 测试

| 测试编号 | 测试内容 | 预期 |
|---|---|---|
| TC-UI-001 | 启动页 Slogan 展示 2 秒后跳转 | 自动跳转登录页 |
| TC-UI-002 | 华为账号登录流程完整 | 登录成功进入首页 |
| TC-UI-003 | 首页空状态展示 | 显示正确文案和图标 |
| TC-UI-004 | 创建心锁输入校验 | 手机号 11 位/内容 1-500 字 |
| TC-UI-005 | 匹配成功后解锁仪式动画 | 3 秒动画完整播放 |
| TC-UI-006 | 邀请卡片生成不包含身份信息 | 卡片无昵称/头像/内容 |
| TC-UI-007 | 注销二次确认 | 两次弹窗后成功注销 |
| TC-UI-008 | App 内无禁用词 | 全文搜索未命中禁用词汇 |

### 3.4 安全测试

| 测试编号 | 测试内容 | 预期 |
|---|---|---|
| TC-SEC-001 | API 响应中无明文手机号 | 搜索响应 JSON 无 phone 字段 |
| TC-SEC-002 | 数据库密文不可读 | 查询 encrypted_content 为乱码 |
| TC-SEC-003 | 注销后数据无法恢复 | 数据库直接查询用户表为空 |
| TC-SEC-004 | Token 伪造失败 | 返回 40002 |

---

## 4. Acceptance（验收清单）

所有验收标准来源于 [PRD.md](../product/PRD.md) 和 [BusinessRules.md](../product/BusinessRules.md)。

| 验收项 | 测试覆盖 |
|---|---|
| AC-001 ~ AC-007 | TC-API-001 ~ TC-API-010 |
| AC-BR-001 ~ AC-BR-008 | TC-UNIT-001 ~ TC-UNIT-008, TC-API-003 ~ TC-API-008 |
| AC-UI-001 ~ AC-UI-010 | TC-UI-001 ~ TC-UI-008 |
| AC-DB-001 ~ AC-DB-006 | TC-UNIT 系列 |

---

## 6. References（引用）

| 引用 | 说明 |
|---|---|
| [PRD.md](../product/PRD.md) | 产品需求文档 |
| [BusinessRules.md](../product/BusinessRules.md) | 业务规则 |
| [API.md](../backend/API.md) | API 接口规范 |
