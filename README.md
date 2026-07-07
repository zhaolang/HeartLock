# HeartLock（心锁）

> **秘密属于一个人，答案属于两个人。**

HeartLock 不是匿名表白工具，而是一款保护每一份喜欢尊严的情感连接产品。

---

## 产品理念

**所有单向的喜欢，都会永远保密。**
**只有双向的喜欢，才值得被世界知道。**

- 你不会在 App 里收到"有人喜欢你"的提示
- 你不会在某个角落看到"暗恋你的人"
- 你只会在一刻被通知——当你们互相喜欢的时候

那一刻，心锁打开。

---

## 核心规则

| 规则 | 说明 |
|---|---|
| 一生一次 | 一个人一生只能向同一个手机号创建一次心锁 |
| 最多三个 | 一个人最多同时拥有 3 个等待中的心锁 |
| 双向解锁 | 只有双方互相心锁，才能解锁看到对方的话 |
| 绝对沉默 | 系统永不发送任何暗示性通知 |
| 来时无痕 | 注销账户即彻底删除所有数据 |

---

## 项目结构

```
HeartLock/
├── docs/                   # 工程规范文档
│   ├── product/            # 产品文档（PRD、业务规则、用户流程）
│   ├── backend/            # 后端文档（数据库、API、安全）
│   ├── frontend/           # 前端文档（UI规范、交互规范）
│   ├── testing/            # 测试用例
│   └── ai/                 # AI 开发指南
├── server/                 # 后端服务
├── harmony/                # HarmonyOS NEXT 客户端
├── scripts/                # 脚本工具
├── prototype/              # 原型设计
└── README.md
```

---

## 核心文档

| 文档 | 说明 |
|---|---|
| [PRD](./docs/product/PRD.md) | 产品需求文档 |
| [产品宪法](./docs/product/Product_Constitution.md) | 品牌核心价值观 |
| [业务规则](./docs/product/BusinessRules.md) | 完整业务规则清单 |
| [用户流程](./docs/product/UserFlow.md) | 用户流程图和时序图 |
| [数据库设计](./docs/backend/Database.md) | 表结构和加密方案 |
| [API 规范](./docs/backend/API.md) | API 接口定义 |
| [安全架构](./docs/backend/Security.md) | 安全方案和密钥管理 |
| [UI 规范](./docs/frontend/UISpec.md) | 视觉规范和页面设计 |
| [交互规范](./docs/frontend/Interaction.md) | 动效和手势操作 |

---

## 技术栈

- **客户端**：HarmonyOS NEXT (API 12+)
- **后端**：待定
- **数据库**：PostgreSQL 16+
- **认证**：华为账号登录
- **加密**：AES-256-GCM / bcrypt / TLS 1.3

---

## 品牌词汇

| 使用 | 不使用 |
|---|---|
| 放进心锁 | ❌ 匿名 / 表白 / 发送 |
| 收藏喜欢 | ❌ 暗恋 / 告白 |
| 解锁 | ❌ 匹配 / 配对 |
| 打开心锁 | ❌ 告白 |

---

## License

MIT
