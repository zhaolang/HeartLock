#!/bin/bash
# ============================================
# HeartLock 生产密钥生成脚本
# ============================================
# 使用方式:
#   bash deploy/scripts/generate-secrets.sh
#   或从项目根目录: bash deploy/scripts/generate-secrets.sh
# ============================================

set -euo pipefail

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== HeartLock 生产密钥生成 ===${NC}"
echo ""

# 生成 JWT_SECRET（32 字节 base64）
JWT_SECRET=$(openssl rand -base64 32)
echo -e "${YELLOW}JWT_SECRET${NC}"
echo "  值: $JWT_SECRET"
echo "  复制到 .env.production 的 JWT_SECRET 字段"
echo ""

# 生成 DB_PASSWORD（24 字节 base64）
DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)
echo -e "${YELLOW}DB_PASSWORD${NC}"
echo "  值: $DB_PASSWORD"
echo "  复制到 .env.production 的 DB_PASSWORD 字段"
echo ""

# 生成 MASTER_KEY（32 字节 HEX）
MASTER_KEY=$(openssl rand -hex 32)
echo -e "${YELLOW}MASTER_KEY${NC}"
echo "  值: $MASTER_KEY"
echo "  复制到 .env.production 的 MASTER_KEY 字段"
echo ""

# 生成管理员初始密码（24 字节 base64）
ADMIN_PASSWORD=$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-18)
echo -e "${YELLOW}管理员初始密码${NC}"
echo "  值: $ADMIN_PASSWORD"
echo "  首次部署后管理员登录使用此密码"
echo "  登录后请在管理后台立即修改！"
echo ""

echo -e "${GREEN}=== 生成完成 ===${NC}"
echo ""
echo "将以上密钥填入 /opt/heartlock/.env.production 后执行："
echo "  cd /opt/heartlock && docker-compose up -d"
