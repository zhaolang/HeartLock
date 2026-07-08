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
