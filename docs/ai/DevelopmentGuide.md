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



### 6.6 HarmonyOS 开发环境配置

| 工具 | 版本 | 说明 |
|---|---|---|
| DevEco Studio | 5.0+ | 官方 IDE，基于 IntelliJ |
| HarmonyOS SDK | API 12+ | 通过 DevEco Studio SDK Manager 安装 |
| ohpm | 随 DevEco Studio 安装 | 鸿蒙包管理器 |
| 本地模拟器 | API 12+ | DevEco Studio 内置 Local Emulator |
| 华为真机 | HarmonyOS NEXT 5.0+ | 推荐 Mate 60 / Pura 70 系列 |

#### 6.6.1 DevEco Studio 安装步骤

```
1. 下载 DevEco Studio: https://developer.huawei.com/consumer/cn/download/
2. 安装后启动 → SDK Manager → 安装 HarmonyOS SDK API 12+
3. 打开项目: File → Open → 选择 heartlock/harmony/
4. 等待 ohpm install 自动执行依赖安装
5. 如需手动安装: cd harmony && ohpm install
```

#### 6.6.2 使用本地模拟器

```
1. DevEco Studio → Tools → Device Manager
2. 选择 Local Emulator → 创建 API 12+ 模拟器
3. 启动模拟器后，点击 Run 运行项目
4. 模拟器具备完整 HarmonyOS NEXT 环境
```

#### 6.6.3 项目配置

项目已配置好 IBest-UI 组件库依赖和所有页面路由：

| 配置文件 | 路径 | 说明 |
|---|---|---|
| 应用配置 | harmony/AppScope/app.json5 | bundleName、版本号、图标 |
| 模块配置 | harmony/entry/src/main/module.json5 | 权限声明、Ability 配置 |
| 页面路由 | harmony/entry/src/main/resources/base/profile/main_pages.json | 8 个页面路由注册 |
| 构建配置 | harmony/build-profile.json5 | API 版本、编译选项 |

#### 6.6.4 页面路由表

| 页面文件 | 路由路径 | 说明 |
|---|---|---|
| SplashPage.ets | pages/SplashPage | 启动页（品牌 Slogan 2s 后跳转） |
| LoginPage.ets | pages/LoginPage | 登录页（华为账号登录引导） |
| HomePage.ets | pages/HomePage | 首页（心锁列表，空状态引导） |
| CreateLockPage.ets | pages/CreateLockPage | 创建心锁表单 |
| LockDetailPage.ets | pages/LockDetailPage | 心锁详情（WAITING/MATCHED 状态） |
| UnlockCeremonyPage.ets | pages/UnlockCeremonyPage | 匹配解锁仪式动画 |
| InvitationCardPage.ets | pages/InvitationCardPage | 邀请卡片生成与预览 |
| ProfilePage.ets | pages/ProfilePage | 个人中心与账户注销 |

### 6.7 Mock API vs 真实 API 切换策略

V1 阶段 HarmonyOS 客户端使用 Mock 数据进行开发，无需后端服务也可运行。

**Mock 机制：**

```
AuthService.ts:
  try {
    return await httpClient.post(...)   ← 先尝试真实 API
  } catch {
    return this.mockLogin();            ← 失败后降级到 Mock
  }

LockService.ts:
  try {
    return await httpClient.get(...)
  } catch {
    return this.getMockLocks(status);   ← Mock 数据
  }
```

**切换方式：**

| 场景 | 操作 | 说明 |
|---|---|---|
| 纯 Mock 模式 | 无需任何配置 | 后端未部署时自动使用 Mock |
| 开发调试 | 确保后端服务运行在 `httpClient.baseUrl` 配置的地址 | 客户端自动切换到真实 API |
| 混合模式 | 修改 HttpClient.ts 中的 baseUrl | 指向本地开发的 Go Server |
| 生产模式 | baseUrl = `https://api.heartlock.app/v1` | JWT 鉴权 + 生产加密 |

**本地开发时修改 HttpClient：**

```typescript
// harmony/entry/src/main/ets/service/HttpClient.ts
class HttpClient {
  // 本地开发时改为 localhost
  private baseUrl: string = 'http://10.0.2.2:8080/v1';
  // 10.0.2.2 = Android 模拟器访问宿主机 localhost 的地址
  // HarmonyOS Local Emulator 同理
}
```

### 6.8 华为开发者账号配置

开发 HeartLock 需要注册华为开发者账号并开通相关服务：

| 服务 | 开通方式 | 用途 |
|---|---|---|
| 华为账号服务（Account Kit） | AppGallery Connect → 认证服务 | 快捷登录 |
| 推送服务（Push Kit） | AppGallery Connect → 推送服务 | 匹配成功通知 |
| 华为云 | 控制台 → 弹性云服务器 | 后端部署 |

**开通步骤：**

```
1. 注册华为开发者账号: https://developer.huawei.com/consumer/cn/
2. 创建 AppGallery Connect 应用:
   - 登录 AppGallery Connect
   - 新建应用 → 包名: com.heartlock.app
   - 开通"认证服务"（Account Kit）
   - 开通"推送服务"（Push Kit）
3. 配置 SHA256 证书指纹:
   - 在 DevEco Studio 中构建 → 生成签名证书
   - 在 AppGallery Connect 配置 SHA256 指纹
4. 获取推送密钥:
   - 推送服务 → 配置 → 应用 ID 和 Secret
   - 填入服务端 .env.production 的 HUAWEI_PUSH_APP_ID 和 SECRET
```
## 7. References（引用）

| 引用 | 说明 |
|---|---|
| [PRD.md](../product/PRD.md) | 产品需求 |
| [BusinessRules.md](../product/BusinessRules.md) | 业务规则 |
| [Database.md](../backend/Database.md) | 数据库 |
| [API.md](../backend/API.md) | 接口 |
| [UISpec.md](../frontend/UISpec.md) | UI 设计 |
