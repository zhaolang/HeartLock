.PHONY: run test build lint migrate-up migrate-down docker-up docker-down

APP_NAME=heartlock-server

# 开发
run:
	go run ./cmd/server

test:
	go test -v -race -count=1 ./...

build:
	go build -o bin/$(APP_NAME) ./cmd/server

lint:
	golangci-lint run ./...

# 数据库
migrate-up:
	migrate -path migrations -database "postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable" up

migrate-down:
	migrate -path migrations -database "postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable" down 1

migrate-create:
	@read -p "Enter migration name: " name; \
	migrate create -ext sql -dir migrations -seq $$name

# Docker
docker-up:
	docker-compose --env-file .env.production up -d --build

docker-down:
	docker-compose down

docker-logs:
	docker-compose logs -f app

# 工具
tidy:
	go mod tidy

vendor:
	go mod vendor

# ============================================
# Docker 部署（增强）
# ============================================

docker-build:
	docker build -t heartlock:latest -f Dockerfile .

docker-export:
	docker save heartlock:latest | gzip > /tmp/heartlock-image.tar.gz
	@echo "镜像已导出到 /tmp/heartlock-image.tar.gz"
	@ls -lh /tmp/heartlock-image.tar.gz

docker-push:
	@echo "将镜像推送到服务器..."
	@echo "  scp /tmp/heartlock-image.tar.gz user@host:/opt/heartlock/"
	@echo "  ssh user@host 'cd /opt/heartlock && gunzip -c heartlock-image.tar.gz | docker load && docker-compose up -d'"

# 生成生产密钥
secrets:
	@echo "=== 生成生产密钥 ==="
	@echo ""
	@echo "JWT_SECRET:"
	@openssl rand -base64 32
	@echo ""
	@echo "DB_PASSWORD:"
	@openssl rand -base64 24 | tr -d '/+=' | cut -c1-24
	@echo ""
	@echo "MASTER_KEY:"
	@openssl rand -hex 32

# 部署到服务器（需先设置 DEPLOY_HOST 和 DEPLOY_USER 环境变量）
deploy:
	@if [ -z "$(DEPLOY_HOST)" ] || [ -z "$(DEPLOY_USER)" ]; then \
		echo "请设置环境变量: DEPLOY_HOST=服务器IP DEPLOY_USER=用户名"; \
		echo "示例: DEPLOY_HOST=1.2.3.4 DEPLOY_USER=ubuntu make deploy"; \
		exit 1; \
	fi
	bash ../deploy/scripts/deploy.sh --host "$(DEPLOY_HOST)" --user "$(DEPLOY_USER)"
