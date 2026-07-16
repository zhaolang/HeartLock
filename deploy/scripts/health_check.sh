#!/bin/bash
# ============================================
# HeartLock 健康检查脚本
# ============================================
# 部署路径: /opt/heartlock/scripts/health_check.sh
# 建议定时任务（crontab）:
#   */10 * * * * /opt/heartlock/scripts/health_check.sh
# ============================================

set -euo pipefail

URL="http://localhost:8081/health"
LOG_FILE="/var/log/heartlock/health.log"
mkdir -p "$(dirname "$LOG_FILE")"

# 健康检查
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$URL" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    # 成功 - 调试级别日志，不写文件（避免日志膨胀）
    # 只在每天第一次成功时记录
    TODAY=$(date +%Y%m%d)
    LAST_LOG=$(tail -1 "$LOG_FILE" 2>/dev/null | grep -o "$TODAY" || echo "")
    if [ -z "$LAST_LOG" ]; then
        echo "[$(date)] ✅ 健康检查正常 (HTTP $HTTP_CODE)" >> "$LOG_FILE"
    fi
else
    echo "[$(date)] ❌ 健康检查失败! HTTP状态码: $HTTP_CODE" >> "$LOG_FILE"
    
    # 连续失败 3 次时尝试重启
    FAIL_COUNT=$(grep "健康检查失败" "$LOG_FILE" | tail -3 | wc -l)
    if [ "$FAIL_COUNT" -ge 3 ]; then
        echo "[$(date)] ⚠️  连续 3 次失败，尝试重启容器..." >> "$LOG_FILE"
        cd /opt/heartlock && docker-compose restart app
        sleep 5
        if curl -s -o /dev/null -w "%{http_code}" "$URL" | grep -q "200"; then
            echo "[$(date)] ✅ 重启后恢复" >> "$LOG_FILE"
        else
            echo "[$(date)] 🔴 重启后仍未恢复，需要人工介入！" >> "$LOG_FILE"
        fi
    fi
fi

# 磁盘检查
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
    echo "[$(date)] ⚠️  磁盘使用率 ${DISK_USAGE}%（超过 85%）" >> "$LOG_FILE"
fi

# Docker 容器状态检查
CONTAINER_STATUS=$(docker ps --filter "name=heartlock" --format "{{.Names}}: {{.Status}}" 2>/dev/null)
echo "[$(date)] 容器状态: $CONTAINER_STATUS" >> "$LOG_FILE"
