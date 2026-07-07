# 文档信息

| 字段 | 内容 |
|---|---|
| 文档名称 | HeartLock（心锁）AI 开发指南 |
| 文档编号 | AI-V1.0 |
| 状态 | 草稿 |
| 作者 | Codex |
| 创建日期 | 2026-07-07 |
| 最后更新 | 2026-07-07 |

---

## 1. Purpose（目的）

定义 AI 辅助开发 HeartLock（心锁）时的开发规范、文档引用规则和开发流程，确保 AI 开发者能快速理解项目上下文并高效产出。

---

## 2. Scope（范围）

适用于使用 Codex、Claude Code、Cursor 等 AI 编程工具参与 HeartLock 开发的场景。

---

## 3. Document Reading Order（文档阅读顺序）

AI 开发者接手项目时，请按以下顺序阅读文档：

1. **README.md** - 项目概览
2. **Product_Constitution.md** - 品牌价值观和产品原则（不能违背）
3. **PRD.md** - 产品需求（功能范围）
4. **BusinessRules.md** - 业务规则（硬性约束，含 RULE ID）
5. **UserFlow.md** - 用户流程
6. **Database.md** - 数据表结构
7. **API.md** - API 契约
8. **UISpec.md** - UI 设计

---

## 4. Development Rules（开发规则）

### 4.1 代码规范

- 后端优先使用 TypeScript / Go
- HarmonyOS 客户端使用 ArkTS（严格模式）
- 所有枚举值使用业务规则中的英文命名（WAITING / MATCHED 等）
- Comment 注释使用中文

### 4.2 文档引用规范

- 代码中涉及业务判断的位置，注释标注 RULE 编号
- 例如：`// RULE-010: 同一用户对同一目标只能有一条心锁记录`
- API 接口注释标注对应 API 端点和 REQ 编号

### 4.3 分支策略

| 分支 | 用途 |
|---|---|
| main | 生产就绪代码 |
| dev | 开发分支 |
| feature/* | 功能分支 |
| fix/* | 修复分支 |

### 4.4 提交规范

```
<type>(<scope>): <subject>

type: feat|fix|docs|refactor|test|chore
scope: server|harmony|docs
```

---

## 5. Development Phases（开发阶段）

### Phase 1：基础架构
- 1.1 后端项目脚手架
- 1.2 数据库建表脚本
- 1.3 用户认证模块（华为账号登录 + JWT）
- 1.4 HarmonyOS 项目脚手架

### Phase 2：核心业务
- 2.1 心锁 CRUD API
- 2.2 匹配检测引擎
- 2.3 Push 通知集成
- 2.4 HarmonyOS 核心页面

### Phase 3：体验打磨
- 3.1 解锁仪式动画
- 3.2 邀请卡片生成与分享
- 3.3 空状态 / 错误处理
- 3.4 账户注销流程

### Phase 4：测试与发布
- 4.1 单元测试
- 4.2 集成测试
- 4.3 安全审查
- 4.4 应用市场上架

---

## 6. References（引用）

| 引用 | 说明 |
|---|---|
| [PRD.md](../product/PRD.md) | 产品需求 |
| [BusinessRules.md](../product/BusinessRules.md) | 业务规则 |
| [Database.md](../backend/Database.md) | 数据库 |
| [API.md](../backend/API.md) | 接口 |
| [UISpec.md](../frontend/UISpec.md) | UI 设计 |
