#!/bin/bash
# ============================================
# HeartLock 数据清理脚本
# ============================================
# 清理过期数据：REVOKED 元数据、操作日志
# 应用内已有定时任务，此脚本作为额外兜底
# 部署路径: /opt/heartlock/scripts/cleanup.sh
# 建议定时任务（crontab）:
#   0 4 * * * /opt/heartlock/scripts/cleanup.sh
# ============================================

set -euo pipefail

LOG_FILE="/var/log/heartlock/cleanup.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "[$(date)] 开始清理..." >> "$LOG_FILE"

# 应用内的定时任务已经在清理，这里只做兜底
# 如果应用正常运行，以下 SQL 的执行结果应该一直是 0

# 1. 清理 REVOKED 超过 30 天的心锁元数据
docker exec heartlock-db psql -U heartlock heartlock -c "
DELETE FROM heart_locks
WHERE status = 'REVOKED'
  AND destroyed_at IS NOT NULL
  AND destroyed_at < NOW() - INTERVAL '30 days';
" >> "$LOG_FILE" 2>&1

# 2. 清理操作日志（保留 7 天）
docker exec heartlock-db psql -U heartlock heartlock -c "
DELETE FROM operation_logs
WHERE created_at < NOW() - INTERVAL '7 days';
" >> "$LOG_FILE" 2>&1

echo "[$(date)] 清理完成" >> "$LOG_FILE"
