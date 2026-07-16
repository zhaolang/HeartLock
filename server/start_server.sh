#!/bin/bash
# HeartLock 一键启动脚本
# 在 Mac 终端中运行: bash start_server.sh

set -e

# 检查 Go
if ! command -v go &> /dev/null; then
    export PATH="/Users/zhaolang/.local/go/bin:$PATH"
fi

# 检查 PostgreSQL
export PATH="/Users/zhaolang/pg16/bin:$PATH"

echo "=== HeartLock 服务端启动 ==="

# 1. 检查 PostgreSQL
echo "1. 检查 PostgreSQL..."
if pg_isready -q 2>/dev/null; then
    echo "   ✅ PostgreSQL 已运行"
else
    echo "   ⚠️  PostgreSQL 未运行，尝试启动..."
    # 尝试启动 PostgreSQL（具体命令取决于安装方式）
    echo "   请手动启动 PostgreSQL 后重试"
    exit 1
fi

# 2. 检查数据库
echo "2. 检查数据库..."
if psql -U heartlock -d heartlock -c "SELECT 1;" &>/dev/null; then
    echo "   ✅ 数据库已存在"
else
    echo "   创建数据库..."
    createdb -U heartlock heartlock 2>/dev/null || true
    psql -U heartlock -d heartlock -c "ALTER USER heartlock WITH PASSWORD 'heartlock_dev';" 2>/dev/null || true
    echo "   ✅ 数据库已创建"
fi

# 3. 编译服务端
echo "3. 编译服务端..."
cd /Users/zhaolang/Documents/heartlock/server
CGO_ENABLED=1 go build -ldflags="-linkmode=external" -o bin/heartlock-server ./cmd/server
echo "   ✅ 编译成功"

# 4. 停止旧进程
echo "4. 停止旧进程..."
PID_FILE="heartlock.pid"
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    kill "$OLD_PID" 2>/dev/null || true
    sleep 1
    rm -f "$PID_FILE"
fi

# 5. 启动服务端
echo "5. 启动服务端..."
nohup ./bin/heartlock-server > heartlock.log 2>&1 &
PID=$!
echo $PID > "$PID_FILE"
sleep 2

if kill -0 "$PID" 2>/dev/null; then
    echo "   ✅ 服务端已启动 (PID: $PID)"
    echo ""
    echo "=== 测试 API ==="
    curl -s http://localhost:8081/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8081/health
    echo ""
    echo ""
    echo "=== 运行测试脚本 ==="
    echo "执行: ./dev_test.sh"
    bash dev_test.sh
else
    echo "   ❌ 服务端启动失败"
    cat heartlock.log
    exit 1
fi
