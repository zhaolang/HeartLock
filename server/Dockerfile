# ============================================
# Stage 1: Build
# ============================================
FROM golang:1.22-alpine AS builder

# 国内服务器加速
ENV GOPROXY=https://goproxy.cn,direct

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server ./cmd/server

# ============================================
# Stage 2: Run
# ============================================
FROM alpine:3.19

# 避免 apk 在线仓库不可达，SSL 证书从 builder 复制
# Go 自带时区数据库，无需 tzdata
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

WORKDIR /app
COPY --from=builder /app/server .
COPY migrations/ ./migrations/
COPY admin/ ./admin/

# 创建非 root 用户运行
RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
    && chown -R appuser:appgroup /app
USER appuser

# 使用 busybox 内置 wget
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

EXPOSE 8080

ENTRYPOINT ["/app/server"]
