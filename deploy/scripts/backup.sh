#!/bin/bash
# ============================================
# HeartLock 数据库备份脚本
# ============================================
# 部署路径: /opt/heartlock/scripts/backup.sh
# 建议定时任务（crontab）:
#   0 3 * * * /opt/heartlock/scripts/backup.sh
# ============================================

set -euo pipefail

BACKUP_DIR="/opt/heartlock/backups"
DB_CONTAINER="heartlock-db"
DB_USER="heartlock"
DB_NAME="heartlock"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${DATE}.sql.gz"
LOG_FILE="${BACKUP_DIR}/backup.log"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 执行备份
echo "[$(date)] 开始备份 ${DB_NAME}..." >> "$LOG_FILE"

if docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" 2>/dev/null | gzip > "$BACKUP_FILE"; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "[$(date)] ✅ 备份完成: ${BACKUP_FILE} (${BACKUP_SIZE})" >> "$LOG_FILE"
else
    echo "[$(date)] ❌ 备份失败!" >> "$LOG_FILE"
    exit 1
fi

# 清理超过保留天数的旧备份
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
echo "[$(date)] 已清理 ${RETENTION_DAYS} 天前的旧备份" >> "$LOG_FILE"

# 保留最近 7 天的备份文件列表
echo "最近备份文件:" >> "$LOG_FILE"
ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -10 >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"
