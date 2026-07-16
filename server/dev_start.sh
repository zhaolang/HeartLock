#!/bin/bash
# HeartLock 开发服务器启动脚本

export APP_ENV=development
export APP_PORT=8081
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

BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$BIN_DIR/heartlock.pid"
LOG_FILE="$BIN_DIR/heartlock.log"

# Kill existing process if any
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Stopping existing server (PID $OLD_PID)..."
        kill "$OLD_PID" 2>/dev/null
        sleep 2
    fi
fi

cd "$BIN_DIR"
echo "Starting HeartLock server..."
nohup "$BIN_DIR/bin/heartlock-server" > "$LOG_FILE" 2>&1 &
PID=$!
echo $PID > "$PID_FILE"

# Wait for server to be ready
sleep 2
if kill -0 "$PID" 2>/dev/null; then
    echo "Server started (PID $PID)"
    echo "Checking /health..."
    curl -s http://localhost:8081/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8081/health
else
    echo "Server failed to start!"
    cat "$LOG_FILE"
fi
