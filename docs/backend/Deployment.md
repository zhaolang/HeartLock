# 文档信息

| 字段 | 内容 |
|---|---|
| 文档名称 | HeartLock（心锁）部署与运维规范 |
| 文档编号 | DEPLOY-V1.0 |
| 状态 | 草稿 |
| 作者 | Codex |
| 创建日期 | 2026-07-07 |
| 最后更新 | 2026-07-07 |

---

## 1. Purpose（目的）

定义 HeartLock（心锁）的完整部署架构、容器化方案、CI/CD 管道、环境管理、数据库运维、监控告警和回滚策略，确保项目从开发环境到生产环境的可重复、可审计、可回滚部署流程。

---

## 2. Scope（范围）

涵盖部署架构设计、Docker 容器化、GitHub Actions CI/CD、环境变量管理、数据库迁移与备份、SSL 证书管理、监控与日志和服务器配置建议。

---

## 3. Definitions（术语）

| 术语 | 定义 |
|---|---|
| CI | 持续集成（Continuous Integration），每次代码提交自动运行测试和构建 |
| CD | 持续部署（Continuous Deployment），通过 CI 后自动发布到生产环境 |
| 存活探针 | Liveness Probe，Docker 用于检测容器是否正常运行 |
| 就绪探针 | Readiness Probe，Docker 用于检测容器是否已准备好接收流量 |
| ghcr.io | GitHub Container Registry，GitHub 的容器镜像仓库 |
| golang-migrate | Go 语言的数据库迁移工具 |

---

## 4. Deployment Architecture（部署架构）

### 4.1 架构图

```mermaid
flowchart TD
    subgraph 外部
        USER[用户]
        DNS[DNS: heartlock.app]
        CDN[CDN / 静态资源]
    end

    subgraph 云服务器
        subgraph Nginx
            NGX[反向代理 / SSL 终止]
        end

        subgraph Docker Compose
            APP[Go Server :8080]
            DB[(PostgreSQL 16 :5432)]
        end

        subgraph 运维组件
            CERT[certbot / Let's Encrypt]
            CRON[定时任务]
        end
    end

    USER -->|HTTPS :443| DNS
    DNS --> NGX
    NGX -->|:8080| APP
    APP -->|:5432| DB
    CRON -->|每日备份| DB
    NGX -->|静态资源| CDN
    NGX -->|SSL 证书| CERT
```

### 4.2 组件说明

| 组件 | 技术选型 | 说明 |
|---|---|---|
| 反向代理 / SSL | Nginx 1.26+ | TLS 1.3 终止、静态资源缓存、请求转发 |
| 应用服务 | Go 1.22+ | HeartLock 后端 API 服务，监听 8080 端口 |
| 数据库 | PostgreSQL 16 | 数据持久化存储 |
| SSL 证书 | Let's Encrypt + certbot | 免费自动续期，有效期 90 天 |
| 容器编排 | Docker Compose | 单机多容器管理，适合 V1 阶段 |
| 镜像仓库 | ghcr.io | GitHub Container Registry |

### 4.3 网络拓扑

```
用户 → 443 (HTTPS) → Nginx :443 → Go App :8080 → PostgreSQL :5432
              ↓
        Let's Encrypt（证书自动续期）
```

- 所有外部流量经过 Nginx 反向代理，禁止直接暴露 Go 应用端口
- 数据库端口（5432）仅在 Docker 内部网络可访问，不对外暴露
- Go 应用监听 localhost:8080，仅 Nginx 可访问

---

## 5. Docker Containerization（Docker 容器化）

### 5.1 Dockerfile（多阶段构建）

```dockerfile
# ============================================
# Stage 1: Build
# ============================================
FROM golang:1.22-alpine AS builder

WORKDIR /app

# 依赖缓存层（利用 Docker 构建缓存）
COPY go.mod go.sum ./
RUN go mod download

# 源码编译
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server ./cmd/server

# ============================================
# Stage 2: Run
# ============================================
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app
COPY --from=builder /app/server .

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

EXPOSE 8080

ENTRYPOINT ["/app/server"]
```

### 5.2 docker-compose.yml

```yaml
version: "3.9"

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    image: ghcr.io/zhaolang/heartlock:${VERSION:-latest}
    container_name: heartlock-app
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
    env_file:
      - .env.production
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  db:
    image: postgres:16-alpine
    container_name: heartlock-db
    restart: unless-stopped
    env_file:
      - .env.production
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/backup:/backup
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-heartlock} -d ${DB_NAME:-heartlock}"]
      interval: 10s
      timeout: 5s
      retries: 5
    ports:
      - "127.0.0.1:5432:5432"

volumes:
  postgres_data:
    driver: local
```

### 5.3 环境变量模板 (.env.production)

```bash
# ============================================
# HeartLock 生产环境配置
# ============================================

# 应用配置
APP_ENV=production
APP_PORT=8080
APP_VERSION=1.0.0

# JWT 配置
JWT_SECRET=<生成一个 32 字节的随机字符串>
JWT_EXPIRY_HOURS=720

# 数据库配置
DB_HOST=db
DB_PORT=5432
DB_USER=heartlock
DB_PASSWORD=<生成一个强随机密码>
DB_NAME=heartlock
DB_SSLMODE=disable
DB_MAX_OPEN_CONNS=25
DB_MAX_IDLE_CONNS=10
DB_CONN_MAX_LIFETIME=30m

# 主密钥（用于加密数据密钥）
MASTER_KEY=<生成一个 32 字节的随机 HEX 字符串>

# 华为推送配置
HUAWEI_PUSH_APP_ID=<华为应用 ID>
HUAWEI_PUSH_APP_SECRET=<华为推送密钥>

# 日志配置
LOG_LEVEL=info
LOG_FORMAT=json
```

### 5.4 启动与停止

```bash
# 构建并启动所有服务
docker-compose --env-file .env.production up -d --build

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f app

# 停止服务
docker-compose down

# 停止并删除数据卷（危险！仅用于完全重置）
docker-compose down -v
```

---

## 6. CI/CD Pipeline（CI/CD 流水线）

### 6.1 GitHub Actions CI（每次 PR 触发）

```yaml
name: CI

on:
  pull_request:
    branches: [main, dev]

jobs:
  ci:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: heartlock
          POSTGRES_PASSWORD: test
          POSTGRES_DB: heartlock_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: "1.22"

      - name: Lint
        uses: golangci/golangci-lint-action@v4

      - name: Run tests
        env:
          DB_HOST: localhost
          DB_PORT: 5432
          DB_USER: heartlock
          DB_PASSWORD: test
          DB_NAME: heartlock_test
        run: go test -v -race -coverprofile=coverage.out ./...

      - name: Build
        run: go build -o heartlock-server ./cmd/server

      - name: Security scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
```

### 6.2 GitHub Actions CD（main 分支推送触发）

```yaml
name: CD

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: "1.22"

      - name: Run tests
        run: go test -v -race ./...

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:latest
            ghcr.io/${{ github.repository }}:${{ github.sha }}
          secrets: |
            GIT_AUTH_TOKEN=${{ secrets.GITHUB_TOKEN }}

      - name: Deploy to server
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.DEPLOY_HOST }}
          username: ${{ secrets.DEPLOY_USER }}
          key: ${{ secrets.DEPLOY_SSH_KEY }}
          script: |
            cd /opt/heartlock
            docker-compose pull app
            docker-compose up -d --no-deps app
            echo "Deployment completed"
```

### 6.3 部署前检查清单

| 检查项 | 命令/操作 | 通过条件 |
|---|---|---|
| 代码审查 | PR 已审批 | >= 1 人审批 |
| CI 通过 | 全部测试通过 | 单元测试 + lint + 构建 |
| 安全扫描 | Trivy 无 CRITICAL 漏洞 | 无阻断级漏洞 |
| 数据库迁移 | 迁移测试 | 迁移可回滚 |
| 镜像构建 | Docker build | 构建成功 |
| 配置检查 | .env.production | 密钥已更新，非默认值 |

---

## 7. Environment Management（环境管理）

### 7.1 环境划分

| 环境 | 用途 | 数据库 | 配置 |
|---|---|---|---|
| development | 本地开发 | 开发者本地 PostgreSQL | .env.development |
| staging | 预发布验证 | 独立 PostgreSQL 实例 | .env.staging |
| production | 正式上线 | 生产 PostgreSQL | .env.production |

### 7.2 密钥管理

| 密钥 | 生成方式 | 存储位置 |
|---|---|---|
| JWT_SECRET | `openssl rand -base64 32` | GitHub Actions Secrets / .env |
| DB_PASSWORD | `openssl rand -base64 24` | GitHub Actions Secrets / .env |
| MASTER_KEY | `openssl rand -hex 32` | 手动设置，线下备份 |
| HUAWEI_PUSH_APP_SECRET | 华为开发者平台获取 | GitHub Actions Secrets / .env |

### 7.3 .gitignore 要求

```
# 不要提交 .env 文件
.env
.env.*
!.env.template
```

---

## 8. Database Management（数据库运维）

### 8.1 迁移命令

```bash
# 开发环境 - 执行全部迁移
migrate -path server/migrations \
  -database "postgres://heartlock:password@localhost:5432/heartlock?sslmode=disable" up

# 开发环境 - 回滚一次
migrate -path server/migrations \
  -database "postgres://heartlock:password@localhost:5432/heartlock?sslmode=disable" down 1

# 生产环境（通过 docker-compose exec）
docker-compose exec app migrate -path /app/migrations \
  -database "postgres://heartlock:${DB_PASSWORD}@db:5432/heartlock?sslmode=disable" up
```

### 8.2 备份与恢复 SOP

**每日自动备份（通过 crontab）：**

```bash
#!/bin/bash
# /opt/heartlock/scripts/backup.sh
# 每日凌晨 3:00 执行

BACKUP_DIR=/opt/heartlock/backups
DB_NAME=heartlock
DB_USER=heartlock
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# 创建备份目录
mkdir -p $BACKUP_DIR

# 执行备份（通过 docker exec）
docker exec heartlock-db pg_dump -U $DB_USER $DB_NAME \
  | gzip > $BACKUP_DIR/${DB_NAME}_${DATE}.sql.gz

# 加密备份文件（可选）
# gpg --encrypt --recipient backup@heartlock.app $BACKUP_DIR/${DB_NAME}_${DATE}.sql.gz

# 保留最近 7 天的备份
find $BACKUP_DIR -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

# 日志记录
echo "[$(date)] Backup completed: ${DB_NAME}_${DATE}.sql.gz" >> $BACKUP_DIR/backup.log
```

**crontab 配置：**

```cron
0 3 * * * /opt/heartlock/scripts/backup.sh
```

**手动恢复流程：**

```bash
# 1. 停止应用服务（避免数据写入冲突）
docker-compose stop app

# 2. 恢复数据库
gunzip -c /opt/heartlock/backups/heartlock_20260707_030000.sql.gz \
  | docker exec -i heartlock-db psql -U heartlock heartlock

# 3. 启动应用
docker-compose start app

# 4. 验证数据完整性
curl http://localhost:8080/health
```

---

## 9. Monitoring & Logging（监控与日志）

### 9.1 健康检查端点

应用在 `GET /health` 提供健康检查信息（见 [API.md](./API.md)）。Docker Compose 配置中已集成存活探针和就绪探针。

### 9.2 结构化日志

应用输出 JSON 格式的结构化日志，每行一条：

```json
{"level":"info","time":"2026-07-07T10:00:00Z","action":"heart_lock.create","user_id":"uuid","latency_ms":45,"request_id":"abc123"}
{"level":"error","time":"2026-07-07T10:00:01Z","action":"heart_lock.create","error":"database connection failed","latency_ms":5000,"request_id":"abc124"}
```

### 9.3 日志查看与采集

```bash
# 实时查看应用日志
docker-compose logs -f app

# 查询错误日志
docker-compose logs app | grep '"level":"error"'

# 导出日志到文件
docker-compose logs --no-color app > app_logs_$(date +%Y%m%d).json
```

### 9.4 监控建议（V2 阶段）

| 工具 | 用途 | 阶段 |
|---|---|---|
| Prometheus + Grafana | 应用指标监控、请求延迟、错误率可视化 | V2 |
| Sentry | 应用错误追踪和性能监控 | V2 |
| uptimerobot.com | 外部可用性监控（每 5 分钟检查 /health） | V1 |

---

## 10. Deployment Checklist（部署清单）

### 10.1 首次部署

- [ ] 购买云服务器（最低配置：2 核 CPU / 4GB 内存 / 40GB SSD）
- [ ] 注册域名并配置 DNS A 记录指向服务器 IP
- [ ] 安装 Docker 和 Docker Compose
- [ ] 配置 iptables / ufw 防火墙（仅开放 22, 80, 443 端口）
- [ ] 申请 Let's Encrypt SSL 证书并配置自动续期
- [ ] 配置 GitHub Secrets（DEPLOY_HOST, DEPLOY_USER, DEPLOY_SSH_KEY）
- [ ] 在服务器创建 /opt/heartlock 目录并初始化
- [ ] 首次部署时手动执行数据库迁移
- [ ] 验证 /health 端点返回正确状态
- [ ] 配置 crontab 每日数据库备份

### 10.2 日常部署

```
1. 开发者提交 PR → CI 自动触发
   ↓
2. PR 审查通过后合并到 main → CD 触发
   ↓
3. GitHub Actions 构建 Docker 镜像并推送到 ghcr.io
   ↓
4. GitHub Actions 通过 SSH 登录服务器
   ↓
5. docker-compose pull 拉取新镜像
   ↓
6. docker-compose up -d --no-deps app 重新创建容器
   ↓
7. 验证新版本 /health 返回正常
   ↓
8. 清理旧镜像：docker image prune -af
```

### 10.3 回滚策略

```bash
# 回滚到上一个版本（回退 docker-compose 服务）
# 方法 1：使用上一个镜像标签
docker-compose stop app
sed -i 's/:latest/:<上一版本 commit SHA>/' docker-compose.yml
docker-compose up -d app

# 方法 2：从 GitHub Actions 重新执行上一个成功的部署
# 在 GitHub Actions 页面找到上一次成功的 CD run → Re-run

# 方法 3：数据库回滚（如新迁移有问题）
docker-compose exec app migrate -path /app/migrations \
  -database "postgres://heartlock:${DB_PASSWORD}@db:5432/heartlock?sslmode=disable" down 1
```

---

## 11. Server Requirements（服务器配置）

### 11.1 最低配置（V1 阶段）

| 资源 | 最低要求 | 推荐配置 |
|---|---|---|
| CPU | 2 核 | 4 核 |
| 内存 | 4 GB | 8 GB |
| 磁盘 | 40 GB SSD | 80 GB SSD |
| 带宽 | 5 Mbps | 10 Mbps |
| 操作系统 | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |
| Docker | 24+ | 26+ |

### 11.2 预估容量

| 指标 | 预估值 | 说明 |
|---|---|---|
| 注册用户 | 10,000 DAU 以下 | V1 阶段 |
| 心锁创建 | 100-500 次/天 | 低频操作 |
| API 请求 | 5-20 QPS | 峰值时段 |
| 数据库存储 | ~10 GB（含备份） | 一年数据量 |

---

## 12. SSL Certificate Management（SSL 证书管理）

### 12.1 Nginx 配置

```nginx
server {
    listen 80;
    server_name heartlock.app api.heartlock.app;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.heartlock.app;

    ssl_certificate     /etc/letsencrypt/live/api.heartlock.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.heartlock.app/privkey.pem;
    ssl_protocols       TLSv1.3;
    ssl_ciphers         TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256;

    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 12.2 证书自动续期

```bash
# 安装 certbot
sudo apt install certbot python3-certbot-nginx

# 首次申请证书
sudo certbot --nginx -d heartlock.app -d api.heartlock.app

# 自动续期（certbot 默认在 /etc/cron.d/certbot 添加了定时任务）
# 验证续期
sudo certbot renew --dry-run
```

---

## 13. Acceptance Criteria（验收标准）

| 编号 | 验收标准 | 关联章节 |
|---|---|---|
| AC-DEPLOY-001 | Docker Compose 一键启动后，三分钟内所有服务健康 | 5.4 |
| AC-DEPLOY-002 | CI 流程在 PR 提交后 5 分钟内完成测试和构建 | 6.1 |
| AC-DEPLOY-003 | CD 流程在 main 推送后 10 分钟内完成部署 | 6.2 |
| AC-DEPLOY-004 | 每日数据库备份在凌晨 3:00 自动执行，保留 7 天 | 8.2 |
| AC-DEPLOY-005 | 回滚操作在 2 分钟内完成，不丢失数据 | 10.3 |
| AC-DEPLOY-006 | SSL 证书在到期前 30 天自动续期 | 12.2 |
| AC-DEPLOY-007 | 生产环境只开放 22、80、443 端口 | 4.3 |

---

## 14. References（引用）

| 引用 | 说明 |
|---|---|
| [API.md](./API.md) | API 接口规范（健康检查端点） |
| [Database.md](./Database.md) | 数据库设计（迁移策略） |
| [Security.md](./Security.md) | 安全架构（TLS、审计日志） |
| [BusinessRules.md](../product/BusinessRules.md) | 业务规则 |
