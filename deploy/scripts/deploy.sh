#!/bin/bash
# ============================================
# HeartLock 一键部署脚本
# ============================================
# 使用方式:
#   方式一 - 本地构建 + SCP 推送到服务器（推荐首次部署）:
#     bash deploy/scripts/deploy.sh --host <服务器IP> --user <用户名>
#
#   方式二 - 在服务器上直接拉取 Git 仓库 + Docker Compose 构建:
#     # SSH 到服务器后执行:
#     bash deploy/scripts/deploy.sh --local
#
# 前提条件:
#   本地: Docker, Docker Compose, openssl
#   服务器: Docker, Docker Compose, Git, Nginx, certbot
# ============================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOY_DIR="$PROJECT_ROOT/deploy"

usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --host <IP>     云服务器 IP 地址"
    echo "  --user <USER>   SSH 用户名（默认 root）"
    echo "  --local         在服务器本地直接部署（从 Git 拉取）"
    echo "  --help          显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  bash $0 --host 1.2.3.4 --user ubuntu"
    echo "  bash $0 --local"
    exit 0
}

# 默认值
SSH_USER="root"
SSH_HOST=""
LOCAL_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --host) SSH_HOST="$2"; shift 2 ;;
        --user) SSH_USER="$2"; shift 2 ;;
        --local) LOCAL_MODE=true; shift ;;
        --help) usage ;;
        *) echo -e "${RED}未知选项: $1${NC}"; usage ;;
    esac
done

# ====================
# 模式一：本地构建 + 推送到服务器
# ====================
deploy_remote() {
    echo -e "${GREEN}=== HeartLock 远程部署 ===${NC}"
    echo "服务器: $SSH_USER@$SSH_HOST"
    echo ""

    # 1. 检查 Docker 是否可用
    echo -e "${YELLOW}[1/6] 检查本地环境...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}请先安装 Docker${NC}"
        exit 1
    fi
    
    # 2. 本地构建 Docker 镜像
    echo -e "${YELLOW}[2/6] 构建 Docker 镜像...${NC}"
    cd "$PROJECT_ROOT/server"
    docker build -t heartlock:latest -f Dockerfile .
    echo -e "${GREEN}  ✅ 镜像构建完成${NC}"

    # 3. 保存镜像并压缩
    echo -e "${YELLOW}[3/6] 导出并压缩镜像...${NC}"
    docker save heartlock:latest | gzip > /tmp/heartlock-image.tar.gz
    echo -e "${GREEN}  ✅ 镜像导出完成${NC}"

    # 4. 准备服务器目录
    echo -e "${YELLOW}[4/6] 准备服务器...${NC}"
    ssh "$SSH_USER@$SSH_HOST" "mkdir -p /opt/heartlock/{nginx,scripts,backups}"
    
    # 5. 传输文件
    echo -e "${YELLOW}[5/6] 传输文件到服务器...${NC}"
    # 传输 Docker 镜像
    scp /tmp/heartlock-image.tar.gz "$SSH_USER@$SSH_HOST:/opt/heartlock/"
    # 传输 docker-compose.yml 和 .env.production
    scp "$PROJECT_ROOT/server/docker-compose.yml" "$SSH_USER@$SSH_HOST:/opt/heartlock/"
    # 传输 Nginx 配置
    scp "$DEPLOY_DIR/nginx/heartlock.conf" "$SSH_USER@$SSH_HOST:/opt/heartlock/nginx/"
    # 传输部署脚本
    scp "$DEPLOY_DIR/scripts/backup.sh" "$SSH_USER@$SSH_HOST:/opt/heartlock/scripts/"
    scp "$DEPLOY_DIR/scripts/health_check.sh" "$SSH_USER@$SSH_HOST:/opt/heartlock/scripts/"
    scp "$DEPLOY_DIR/scripts/cleanup.sh" "$SSH_USER@$SSH_HOST:/opt/heartlock/scripts/"
    echo -e "${GREEN}  ✅ 文件传输完成${NC}"

    # 6. 在服务器上加载镜像并启动
    echo -e "${YELLOW}[6/6] 在服务器部署...${NC}"
    ssh "$SSH_USER@$SSH_HOST" '
        cd /opt/heartlock
        
        # 加载 Docker 镜像
        gunzip -c heartlock-image.tar.gz | docker load
        rm -f heartlock-image.tar.gz
        
        # 检查 .env.production 是否存在
        if [ ! -f .env.production ]; then
            echo "  ⚠️  .env.production 不存在！"
            echo "  请先创建并填入密钥: vi /opt/heartlock/.env.production"
            echo "  参考模板: cat /opt/heartlock/deploy/.env.production.template"
            exit 1
        fi
        
        # 启动服务
        docker-compose --env-file .env.production up -d
        
        # 等待服务启动
        sleep 3
        
        # 检查健康状态
        curl -s http://localhost:8080/health | python3 -m json.tool
        
        echo ""
        echo "  ✅ 部署完成！"
        echo "  查看日志: docker-compose logs -f app"
    '
    
    # 清理本地临时文件
    rm -f /tmp/heartlock-image.tar.gz
    
    echo ""
    echo -e "${GREEN}=== 部署完成！===${NC}"
    echo "API 地址: https://api.heartlock.app"
    echo "管理后台: https://api.heartlock.app/admin"
    echo ""
    echo -e "${YELLOW}后续步骤:${NC}"
    echo "  1. 配置 Nginx: sudo ln -sf /opt/heartlock/nginx/heartlock.conf /etc/nginx/sites-enabled/"
    echo "  2. 申请 SSL: sudo certbot --nginx -d api.heartlock.app"
    echo "  3. 重启 Nginx: sudo nginx -s reload"
    echo "  4. 设置 crontab: crontab /opt/heartlock/scripts/crontab"
}

# ====================
# 模式二：在服务器上直接从 Git 拉取 + 构建
# ====================
deploy_local() {
    echo -e "${GREEN}=== HeartLock 本地服务器部署 ===${NC}"
    
    # 1. 检查环境
    echo -e "${YELLOW}[1/5] 检查环境...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}请先安装 Docker${NC}"
        echo "安装: curl -fsSL https://get.docker.com | sh"
        exit 1
    fi
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}请先安装 Docker Compose${NC}"
        exit 1
    fi
    echo -e "${GREEN}  ✅ 环境就绪${NC}"
    
    # 2. 准备目录
    echo -e "${YELLOW}[2/5] 准备目录...${NC}"
    mkdir -p /opt/heartlock/{nginx,scripts,backups}
    cd /opt/heartlock
    
    # 3. 克隆/拉取代码
    HEARTLOCK_DIR="/opt/heartlock"
    if [ -d "$HEARTLOCK_DIR/repo" ]; then
        echo -e "${YELLOW}[3/5] 拉取最新代码...${NC}"
        cd "$HEARTLOCK_DIR/repo"
        git pull
    else
        echo -e "${YELLOW}[3/5] 克隆仓库...${NC}"
        # 提示用户输入仓库地址
        read -p "请输入 Git 仓库地址: " REPO_URL
        if [ -z "$REPO_URL" ]; then
            # 从现有项目手动复制
            echo "请将 server/ 目录手动复制到 /opt/heartlock/repo/"
            exit 1
        fi
        git clone "$REPO_URL" "$HEARTLOCK_DIR/repo"
    fi
    
    # 4. 构建镜像
    echo -e "${YELLOW}[4/5] 构建 Docker 镜像...${NC}"
    cd "$HEARTLOCK_DIR/repo/server"
    docker-compose --env-file "$HEARTLOCK_DIR/.env.production" build
    
    # 5. 启动服务
    echo -e "${YELLOW}[5/5] 启动服务...${NC}"
    cp "$HEARTLOCK_DIR/repo/deploy/nginx/heartlock.conf" "$HEARTLOCK_DIR/nginx/"
    cp "$HEARTLOCK_DIR/repo/deploy/scripts/"*.sh "$HEARTLOCK_DIR/scripts/"
    chmod +x "$HEARTLOCK_DIR/scripts/"*.sh
    
    # 复制并启动
    cd "$HEARTLOCK_DIR/repo/server"
    docker-compose --env-file "$HEARTLOCK_DIR/.env.production" up -d
    
    echo ""
    echo -e "${GREEN}=== 部署完成！===${NC}"
}

# 主逻辑
if [ "$LOCAL_MODE" = true ]; then
    deploy_local
elif [ -n "$SSH_HOST" ]; then
    deploy_remote
else
    usage
fi
