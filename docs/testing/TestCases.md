# 文档信息

| 字段 | 内容 |
|---|---|
| 文档名称 | HeartLock（心锁）测试用例 |
| 文档编号 | TC-V1.1 |
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


### 3.5 E2E 端到端测试

| 测试编号 | 测试内容 | 前置条件 | 验证步骤 | 预期结果 |
|---|---|---|---|---|
| TC-E2E-001 | 完整匹配流程 | 用户 A 和用户 B 均未注册 | ① 用户 A 注册 → ② 用户 A 创建心锁（target=B 手机号）→ ③ 用户 B 注册 → ④ 用户 B 创建心锁（target=A 手机号） | 步骤 ④ 触发匹配，两条记录同时 MATCHED，双方收到 Push |
| TC-E2E-002 | 邀请卡片裂变 → 匹配 | 用户 A 已注册并创建心锁（WAITING） | ① 用户 A 生成邀请卡片 → ② 用户 B 通过卡片下载 App → ③ 用户 B 注册 → ④ 用户 B 输入 A 手机号创建心锁 | 匹配成功，两条记录 MATCHED |
| TC-E2E-003 | 撤回 → 重新登录 → 不重复 | 用户 A 已创建心锁 | ① 用户 A 撤回心锁 → ② 用户 A 退出登录 → ③ 用户 A 重新登录 → ④ 用户 A 尝试向同一手机号创建心锁被拒绝 | 返回 40011 |
| TC-E2E-004 | 注销 → 重新注册拒绝 | 用户 A 已注册 | ① 用户 A 注销账户 → ② 同一手机号尝试重新注册 | 注册被拒绝 |

---

### 3.6 负载测试

**推荐工具：** [k6](https://k6.io/)

#### 3.6.1 核心场景 - 心锁创建并发测试

```javascript
// k6 负载测试脚本（示例）
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 20 },
    { duration: '1m', target: 50 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const payload = JSON.stringify({
    target_phone: `1380013${String(Math.floor(Math.random() * 9000) + 1000)}`,
    content: '负载测试内容 - 自动生成，请忽略',
  });

  const res = http.post(
    'https://api.heartlock.app/v1/heart-locks',
    payload,
    { headers: { 'Content-Type': 'application/json' } },
  );

  check(res, {
    'status is 200 or 400': (r) => r.status === 200 || r.status === 400,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1);
}
```

#### 3.6.2 性能目标

| 场景 | 并发用户 | 目标 P95 响应时间 | 目标失败率 |
|---|---|---|---|
| 创建心锁 | 50 concurrent | < 500ms | < 1% |
| 匹配检测 | 50 concurrent | < 2s | < 0.1% |
| 心锁列表查询 | 100 concurrent | < 200ms | < 0.5% |

#### 3.6.3 负载测试前置条件

- 预置 1000 条用户数据
- 预置 3000 条心锁记录（含 WAITING / MATCHED / REVOKED）
- 数据库迁移已执行完成
- 服务日志级别设为 warn（减少日志 I/O 对性能的影响）

---

### 3.7 安全渗透测试清单

#### OWASP Top 10 检查项

| 检查项 | HeartLock 防护措施 | 状态 |
|---|---|---|
| A01: 访问控制失效 | JWT 鉴权 + 手机号指纹匹配检测 | 待测试 |
| A02: 加密机制失效 | AES-256-GCM + bcrypt + TLS 1.3 | 待测试 |
| A03: 注入攻击 | 参数化 SQL 查询 + 输入验证中间件 | 待测试 |
| A04: 不安全设计 | 保密期过后的元数据自动清理 | 待测试 |
| A05: 安全配置错误 | 仅开放 22/80/443 端口，Nginx 安全头 | 待测试 |
| A06: 脆弱和过时的组件 | Trivy 依赖扫描阻断高危漏洞 | 待测试 |
| A07: 身份认证失效 | JWT 签名验证 + Token 失效机制 | 待测试 |
| A08: 软件和数据完整性 | ghcr.io 镜像签名验证 | 待测试 |
| A09: 安全日志和监控 | 审计日志 + 结构化日志 + 告警 | 待测试 |
| A10: SSRF 服务端请求伪造 | Nginx 反向代理 + 内部网络隔离 | 待测试 |

---

## 4. Acceptance（验收清单）

所有验收标准来源于 [PRD.md](../product/PRD.md) 和 [BusinessRules.md](../product/BusinessRules.md)。

| 验收项 | 测试覆盖 |
|---|---|
| AC-001 ~ AC-007 | TC-API-001 ~ TC-API-010 |
| AC-BR-001 ~ AC-BR-008 | TC-UNIT-001 ~ TC-UNIT-008, TC-API-003 ~ TC-API-008 |
| AC-UI-001 ~ AC-UI-010 | TC-UI-001 ~ TC-UI-008 |
| AC-DB-001 ~ AC-DB-007 | TC-UNIT 系列 |
| AC-API-008 ~ AC-API-010 | TC-API-011 ~ TC-API-013 |
| 完整匹配流程 | TC-E2E-001 ~ TC-E2E-004 |
| 性能目标 | TC-LOAD-001 ~ TC-LOAD-003 |

---

## 6. References（引用）

| 引用 | 说明 |
|---|---|
| [PRD.md](../product/PRD.md) | 产品需求文档 |
| [BusinessRules.md](../product/BusinessRules.md) | 业务规则 |
| [API.md](../backend/API.md) | API 接口规范 |
| [Database.md](../backend/Database.md) | 数据库设计 |
| [Deployment.md](../backend/Deployment.md) | 部署与运维规范 |
