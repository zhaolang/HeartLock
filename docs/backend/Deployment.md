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


### 9.5 V1 阶段实用监控搭建（无需 Prometheus）

V1 阶段用户量较小（预估 DAU < 10,000），无需引入 Prometheus + Grafana 重型监控栈。以下为轻量级但有效的监控方案：

**方案一：基于健康检查的外部监控（推荐 V1 首选）**

| 工具 | 用途 | 配置方式 |
|---|---|---|
| uptimerobot.com（免费版） | 每 5 分钟检查 /health 端点 | 创建 HTTP(s) 监控，监控 https://api.heartlock.app/health |
| cron + curl | 内部端到端可用性检查 | 每 10 分钟执行 curl + 失败时写入日志 |

```bash
#!/bin/bash
# /opt/heartlock/scripts/health_check.sh
# 添加 crontab: */10 * * * * /opt/heartlock/scripts/health_check.sh

URL="https://api.heartlock.app/health"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")

if [ "$RESPONSE" != "200" ]; then
  echo "[$(date)] ERROR: Health check failed with status $RESPONSE" >> /var/log/heartlock/health.log
  # 可选：发送告警（mail / 飞书 / Slack Webhook）
fi
```

**方案二：应用内健康指标（内置在 /health 响应中）**

| 指标 | 来源 | 告警阈值 |
|---|---|---|
| db_connected | /health 响应 | false 持续 30 秒 → 告警 |
| uptime_seconds | /health 响应 | < 60（刚重启）→ 关注 |
| 最近 100 次请求错误率 | 日志分析 | > 5% → 告警 |

**方案三：日志告警（cron + grep）**

```bash
# 每 15 分钟检查最近 5 分钟的 ERROR 日志数量
ERROR_COUNT=$(docker-compose logs --since=5m app | grep -c level:error)
if [ "$ERROR_COUNT" -gt 10 ]; then
  echo "[$(date)] WARN: $ERROR_COUNT errors in last 5 minutes" >> /var/log/heartlock/alerts.log
fi
```

### 9.6 日志聚合方案

V1 阶段，日志管理可维持在 Docker Compose 级别，不需引入 ELK/Loki：

```bash
# 日志轮转（Docker 默认配置）
docker-compose logs --tail=1000 app > /var/log/heartlock/app_$(date +%Y%m%d).log

# 保留最近 30 天日志
find /var/log/heartlock -name "*.log" -mtime +30 -delete
```

**V2 升级方向：**

| 工具 | 用途 | 预计引入时间 |
|---|---|---|
| Loki + Promtail | 日志集中存储和查询 | DAU > 10,000 |
| Grafana | 日志可视化面板 | DAU > 10,000 |
| Sentry | 错误追踪 | V2 期 |

## 10. Deployment Checklist（部署清单）

### 10.1 首次部署

- [ ] 购买云服务器（最低配置：2 核 CPU / 4GB 内存 / 40GB SSD）
- [ ] 注册域名并配置 DNS A 记录指向服务器 IP
- [ ] 安装 Docker 和 Docker Compose
- [ ] 配置 iptables / ufw 防火墙（仅开放 22, 80, 443 端口）
- [ ] 申请 Let's Encrypt SSL 证书并配置自动续期
- [ ] 配置 GitHub Secrets（DEPLOY_HOST, DEPLOY_USER, DEPLOY_SSH_KEY）
- [ ] 在服务器创建 /opt/heartlock 目录并初始化
- [ ] 创建备份目录并设置权限: mkdir -p /opt/heartlock/backups && chmod 700 /opt/heartlock/backups
- [ ] 复制 docker-compose.yml 和 .env.production 到 /opt/heartlock
- [ ] 首次启动: docker-compose -f /opt/heartlock/docker-compose.yml --env-file /opt/heartlock/.env.production up -d
- [ ] 执行数据库迁移: docker-compose exec app migrate -path /app/migrations -database "postgres://heartlock:${DB_PASSWORD}@db:5432/heartlock?sslmode=disable" up
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
### 11.3 成本估算（月度）

以下为 V1 阶段生产环境月度运行成本估算（人民币）：

| 项目 | 规格 | 月费（估算） | 说明 |
|---|---|---|---|
| 云服务器 | 2 核 4GB 40GB SSD（如 华为云/阿里云 轻量服务器） | ¥68 - ¥128 | 腾讯云轻量 2C4G 约 ¥68/月 |
| 域名 | heartlock.app + api.heartlock.app | ¥0（首年） / ~¥60/年 | .app 域名年费 |
| SSL 证书 | Let's Encrypt | ¥0 | 免费自动续期 |
| 华为推送 | 华为 Push Kit | ¥0 | 免费额度内 |
| 华为账号 | 华为 Account Kit | ¥0 | 免费 |
| 监控 (uptimerobot) | 免费版 50 个监控器 | ¥0 | 足够 V1 使用 |
| CDN（可选） | 静态资源加速 | ¥0 - ¥30/月 | 可按需启用 |
| **合计** | | **¥68 - ¥218/月** | |

**年度总成本：约 ¥816 - ¥2,616/年**

**上线初期成本优化建议：**
- 使用 腾讯云轻量应用服务器（2C4G ¥68/月）作为起步
- 应用服务和数据库部署在同一台服务器（Docker Compose）
- 待 DAU 超过 5,000 后再考虑数据库独立部署
- CDN 仅在静态资源（邀请卡片图片）量增大后启用

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

## 14. Makefile 常用命令速查

项目根目录下的 `server/Makefile` 提供以下命令，方便开发与部署：

| 命令 | 用途 |
|---|---|
| `make run` | 本地开发启动 |
| `make test` | 运行所有测试 |
| `make build` | 编译二进制 |
| `make lint` | 代码检查 |
| `make migrate-up` | 执行数据库迁移 |
| `make migrate-down` | 回滚迁移 |
| `make migrate-create` | 创建新迁移文件 |
| `make docker-up` | 构建并启动 Docker 容器 |
| `make docker-down` | 停止容器 |
| `make docker-logs` | 查看应用日志 |

---

## 16. References（引用）

| 引用 | 说明 |
|---|---|
| [API.md](./API.md) | API 接口规范（健康检查端点） |
| [Database.md](./Database.md) | 数据库设计（迁移策略） |
| [Security.md](./Security.md) | 安全架构（TLS、审计日志） |
| [BusinessRules.md](../product/BusinessRules.md) | 业务规则 |

## 17. 灾备方案（Disaster Recovery）

### 15.1 故障等级定义

| 等级 | 定义 | 恢复目标 | 示例 |
|---|---|---|---|
| P0 | 服务完全不可用 | RTO < 30min, RPO < 5min | 服务器宕机、数据库损坏 |
| P1 | 核心功能不可用 | RTO < 2h, RPO < 15min | 创建心锁失败、匹配检测异常 |
| P2 | 非核心功能异常 | 下个迭代修复 | 邀请卡片生成失败、推送延迟 |

### 15.2 服务器宕机恢复流程

```bash
# P0 故障：服务器宕机恢复步骤

# 1. 确认故障
ssh -i ~/.ssh/heartlock user@<服务器IP>
docker-compose ps                    # 检查容器状态
docker-compose logs --tail=50 app    # 检查应用日志
curl http://localhost:8080/health    # 检查健康状态

# 2a. 如果只是容器崩溃
docker-compose up -d --no-deps app   # 重新创建容器

# 2b. 如果服务器重启后 Docker 未自启
sudo systemctl start docker
docker-compose -f /opt/heartlock/docker-compose.yml up -d

# 2c. 如果服务器不可恢复（硬件故障）
# 新建一台服务器 → 安装 Docker → 拉取最新镜像
# 从最近的数据库备份恢复 → 更新 DNS 记录指向新服务器 IP
```

### 15.3 数据库损坏恢复流程

```bash
# P0 故障：数据库损坏 / 数据丢失

# 1. 停止应用（防止写入污染）
docker-compose stop app

# 2. 检查数据库状态
docker-compose logs --tail=30 db
docker exec heartlock-db pg_isready -U heartlock

# 3. 从最近备份恢复
LATEST_BACKUP=$(ls -t /opt/heartlock/backups/*.sql.gz | head -1)
echo "恢复备份: $LATEST_BACKUP"
gunzip -c "$LATEST_BACKUP" | docker exec -i heartlock-db psql -U heartlock heartlock

# 4. 启动应用
docker-compose start app

# 5. 验证数据完整性
curl http://localhost:8080/health
docker-compose logs --tail=20 app
```

### 15.4 密钥泄露响应流程

| 步骤 | 操作 | 负责人 |
|---|---|---|
| 1 | 立即下线受影响的 API | 值班开发者 |
| 2 | 紧急轮换主密钥（详见 Security.md 4.3.1） | 后端开发者 |
| 3 | 检查审计日志，确认泄露范围 | 后端开发者 |
| 4 | 通知所有活跃用户重新登录（JWT 失效） | 后端开发者 |
| 5 | 发布安全事件报告 | 项目负责人 |

### 15.5 备份恢复验证

每月进行一次备份恢复演练：

```bash
# 1. 在临时容器中恢复最近备份
docker run --rm -v /opt/heartlock/backups:/backup postgres:16-alpine \
  /bin/bash -c "gunzip -c /backup/heartlock_latest.sql.gz | psql -h test-host -U heartlock heartlock"

# 2. 验证恢复后的数据
# - 确认用户表不为空
# - 确认心锁表数据量在合理范围
# - 确认匹配检测 SQL 能正确执行

# 3. 记录验证结果
echo "[$(date)] 备份恢复验证完成" >> /var/log/heartlock/backup_verify.log
```

### 15.6 日常运维检查清单

| 频率 | 检查项目 | 操作 |
|---|---|---|
| 每日 | 健康检查日志 | 查看 /var/log/heartlock/health.log |
| 每日 | 磁盘使用率 | `df -h /` 确认 < 80% |
| 每日 | 容器运行状态 | `docker-compose ps` 确认 all up |
| 每周 | 备份完整性 | `ls -l /opt/heartlock/backups/` 确认最近备份 |
| 每周 | 日志清理 | `find /var/log/heartlock -name "*.log" -mtime +30 -delete` |
| 每月 | 备份恢复演练 | 在临时环境执行一次完整恢复 |
| 每月 | SSL 证书检查 | `certbot renew --dry-run` |
| 每月 | 安全审计 | 检查审计日志中的异常请求模式 |
