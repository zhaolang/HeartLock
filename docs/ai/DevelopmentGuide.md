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
9. **Deployment.md** - 部署与运维

---

## 4. Development Rules（开发规则）

### 4.1 代码规范

- 后端使用 Go 1.22+
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

## 6. Local Development Environment Setup（本地开发环境搭建）

### 6.1 前置依赖

| 工具 | 版本 | 安装方式 |
|---|---|---|
| Go | 1.22+ | `brew install go` |
| PostgreSQL | 16+ | `brew install postgresql@16` |
| golang-migrate | 4.x | `brew install golang-migrate` |
| Docker | 24+ | Docker Desktop for Mac |
| Docker Compose | 2.x | 随 Docker Desktop 安装 |

### 6.2 数据库初始化

```bash
# 启动 PostgreSQL
brew services start postgresql@16

# 创建数据库和用户
psql postgres -c "CREATE USER heartlock WITH PASSWORD 'heartlock_dev';"
psql postgres -c "CREATE DATABASE heartlock OWNER heartlock;"

# 执行迁移
migrate -path server/migrations   -database "postgres://heartlock:heartlock_dev@localhost:5432/heartlock?sslmode=disable" up
```

### 6.3 环境变量配置

```bash
# 复制模板文件
cp .env.template .env.development

# 编辑 .env.development，填入开发环境配置
# 对于本地开发，以下配置可直接使用默认值：
# DB_HOST=localhost
# DB_PORT=5432
# DB_USER=heartlock
# DB_PASSWORD=heartlock_dev
# DB_NAME=heartlock
```

### 6.4 常用 Makefile 目标

推荐在项目根目录创建 Makefile：

```makefile
.PHONY: run test build migrate-up migrate-down db-create db-drop docker-up docker-down

# 开发
run:
	go run ./cmd/server

test:
	go test -v -race -count=1 ./...

build:
	go build -o bin/heartlock-server ./cmd/server

# 数据库
migrate-up:
	migrate -path server/migrations -database "postgres://heartlock:${DB_PASSWORD}@localhost:5432/heartlock?sslmode=disable" up

migrate-down:
	migrate -path server/migrations -database "postgres://heartlock:${DB_PASSWORD}@localhost:5432/heartlock?sslmode=disable" down 1

# Docker
docker-up:
	docker-compose --env-file .env.development up -d --build

docker-down:
	docker-compose down

# 代码检查
lint:
	golangci-lint run ./...
```

### 6.5 本地开发数据流

```mermaid
flowchart LR
    DEV[本地开发] -->|go run| APP[Go Server :8080]
    APP -->|localhost:5432| DB[(PostgreSQL)]
    DEV -->|SQL 迁移| MIG[migrate CLI]
    MIG --> DB
```


## 7. References（引用）

| 引用 | 说明 |
|---|---|
| [PRD.md](../product/PRD.md) | 产品需求 |
| [BusinessRules.md](../product/BusinessRules.md) | 业务规则 |
| [Database.md](../backend/Database.md) | 数据库 |
| [API.md](../backend/API.md) | 接口 |
| [UISpec.md](../frontend/UISpec.md) | UI 设计 |
