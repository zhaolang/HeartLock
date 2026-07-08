#!/bin/bash
# HeartLock 开发服务器启动脚本
# 使用方法: ./dev.sh [start|stop|restart|test|logs]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$SCRIPT_DIR/heartlock.pid"
LOG_FILE="$SCRIPT_DIR/heartlock.log"

# 加载开发环境变量
export APP_ENV=development
export APP_PORT=8080
export APP_VERSION=1.0.0

export DB_HOST=127.0.0.1
export DB_PORT=5432
export DB_USER=heartlock
export DB_PASSWORD=heartlock_dev
export DB_NAME=heartlock
export DB_SSLMODE=disable
export DB_MAX_OPEN_CONNS=25
export DB_MAX_IDLE_CONNS=10

export JWT_SECRET=dev-secret-change-in-production
export JWT_EXPIRY_HOURS=720
export MASTER_KEY=0000000000000000000000000000000000000000000000000000000000000000

export LOG_LEVEL=debug

# PostgreSQL 和 Go 路径
export PATH="/Users/zhaolang/.local/go/bin:/Users/zhaolang/pg16/bin:$PATH"

case "${1:-start}" in
  start)
    echo "Building HeartLock server..."
    cd "$SCRIPT_DIR"
    CGO_ENABLED=1 go build -ldflags="-linkmode=external" -o bin/heartlock-server ./cmd/server
    
    if [ -f "$PID_FILE" ]; then
      OLD_PID=$(cat "$PID_FILE")
      if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Server already running (PID $OLD_PID)"
        exit 1
      fi
    fi
    
    echo "Starting HeartLock server..."
    nohup "$SCRIPT_DIR/bin/heartlock-server" > "$LOG_FILE" 2>&1 &
    PID=$!
    echo $PID > "$PID_FILE"
    
    sleep 2
    if kill -0 "$PID" 2>/dev/null; then
      echo "Server started (PID $PID)"
      curl -s http://localhost:8080/health | python3 -m json.tool
    else
      echo "Server failed to start!"
      cat "$LOG_FILE"
      exit 1
    fi
    ;;
    
  stop)
    if [ -f "$PID_FILE" ]; then
      PID=$(cat "$PID_FILE")
      echo "Stopping server (PID $PID)..."
      kill "$PID" 2>/dev/null || true
      rm -f "$PID_FILE"
      echo "Server stopped."
    else
      echo "No PID file found."
    fi
    ;;
    
  restart)
    $0 stop
    sleep 1
    $0 start
    ;;
    
  logs)
    if [ -f "$LOG_FILE" ]; then
      tail -f "$LOG_FILE"
    else
      echo "No log file found."
    fi
    ;;
    
  test)
    if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then
      echo "Server not running. Starting..."
      $0 start
    fi
    echo "Running API tests..."
    bash "$SCRIPT_DIR/dev_test.sh"
    ;;
    
  *)
    echo "Usage: $0 {start|stop|restart|test|logs}"
    ;;
esac
