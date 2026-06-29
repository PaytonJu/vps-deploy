#!/bin/bash
# ============================================================
# VPS 一键部署脚本
# 部署：个人主页（Home_Page）+ 青春档案（laoda-page）
# 使用方法：
#   1. 首次使用： chmod +x deploy-vps.sh
#   2. 配置服务器信息（见下方 CONFIG）
#   3. 运行： ./deploy-vps.sh
# ============================================================

set -e

# ==================== 配置区域 ====================
# 第一次使用前请修改这里

SSH_HOST="198.46.193.163"
SSH_USER="root"
SSH_PORT="22"
SSH_PASSWORD=""                # 建议用 SSH 密钥代替密码

DOMAIN="jucode.org"
DOMAIN_LAODA_PATH="/laoda"     # 青春档案的访问路径

HOME_PAGE_PORT="5002"
LAODA_PAGE_PORT="5003"

HOME_PAGE_REPO="https://github.com/PaytonJu/Home_Page.git"
LAODA_PAGE_REPO="https://github.com/PaytonJu/laoda-page.git"

# ====================================================
# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ==================== SSH 助手 ====================
SSH_CMD="ssh -o StrictHostKeyChecking=no -p $SSH_PORT"
SCP_CMD="scp -o StrictHostKeyChecking=no -P $SSH_PORT"

if [ -n "$SSH_PASSWORD" ]; then
    SSH_CMD="sshpass -p '$SSH_PASSWORD' $SSH_CMD"
    SCP_CMD="sshpass -p '$SSH_PASSWORD' $SCP_CMD"
fi

ssh_run() {
    $SSH_CMD "$SSH_USER@$SSH_HOST" "$@"
}

# ==================== 安装依赖 ====================
install_deps() {
    log "安装系统依赖..."
    ssh_run "
        apt-get update -qq && apt-get install -y -qq nginx python3 python3-pip git sshpass curl 2>/dev/null
    " || warn "部分依赖安装可能已存在"
    log "依赖安装完成"
}

# ==================== 拉取代码 ====================
pull_code() {
    log "拉取个人主页代码..."
    ssh_run "
        if [ -d /root/Home_Page ]; then
            cd /root/Home_Page && git pull
        else
            git clone $HOME_PAGE_REPO /root/Home_Page
        fi
    "

    log "拉取青春档案代码..."
    ssh_run "
        if [ -d /root/laoda_page ]; then
            cd /root/laoda_page && git pull
        else
            git clone $LAODA_PAGE_REPO /root/laoda_page
        fi
    "
    log "代码拉取完成"
}

# ==================== 配置 Nginx ====================
setup_nginx() {
    log "配置 Nginx..."
    ssh_run "
        cat > /etc/nginx/sites-enabled/default << 'NGINX'
# 默认站点（仅用于安全占位，不提供实际内容）
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 444;
}

# ===== 主站：$DOMAIN =====
server {
    listen 80;
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN;

    # SSL 证书（换服务器后需重新申请或复制证书）
    ssl_certificate /root/cert/$DOMAIN/fullchain.pem;
    ssl_certificate_key /root/cert/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # 青春档案
    location $DOMAIN_LAODA_PATH/ {
        proxy_pass http://127.0.0.1:$LAODA_PAGE_PORT/;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
    }

    # 个人主页
    location / {
        proxy_pass http://127.0.0.1:$HOME_PAGE_PORT;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
    }
}

# ===== 备用域名 =====
server {
    listen 80;
    listen 443 ssl;
    server_name fuckdengxiangning.sbs;

    ssl_certificate /root/cert/fuckdengxiangning.sbs/fullchain.pem;
    ssl_certificate_key /root/cert/fuckdengxiangning.sbs/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:$HOME_PAGE_PORT;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
    }
}
NGINX
    "
    ssh_run "nginx -t && systemctl reload nginx" || warn "Nginx 测试失败，稍后手动检查"
    log "Nginx 配置完成"
}

# ==================== 部署青春档案（静态文件服务） ====================
deploy_laoda() {
    log "启动青春档案（端口 $LAODA_PAGE_PORT）..."

    # 创建 systemd 服务
    ssh_run "
        cat > /etc/systemd/system/laoda-page.service << 'SERVICE'
[Unit]
Description=Youth Archive - laoda page
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/laoda_page
ExecStart=/usr/bin/python3 -m http.server $LAODA_PAGE_PORT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
        systemctl daemon-reload
        systemctl enable laoda-page
        systemctl restart laoda-page
    "
    log "青春档案已启动"
}

# ==================== 部署个人主页 ====================
deploy_homepage() {
    log "部署个人主页（端口 $HOME_PAGE_PORT）..."

    # 安装 Python 依赖
    ssh_run "
        cd /root/Home_Page
        pip3 install -r requirements.txt -q 2>/dev/null || pip install -r requirements.txt -q
    " || warn "安装依赖可能有问题，稍后检查"

    # 创建 systemd 服务
    ssh_run "
        cat > /etc/systemd/system/home-page.service << 'SERVICE'
[Unit]
Description=Personal Homepage
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/Home_Page
ExecStart=/usr/bin/python3 /root/Home_Page/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
        systemctl daemon-reload
        systemctl enable home-page
        systemctl restart home-page
    "
    log "个人主页已启动"
}

# ==================== 申请 SSL 证书 ====================
setup_ssl() {
    log "检查并申请 SSL 证书..."
    ssh_run "
        if ! command -v acme.sh &>/dev/null; then
            curl https://get.acme.sh | sh -s email=admin@$DOMAIN
        fi
        # 申请证书
        ~/.acme.sh/acme.sh --issue -d $DOMAIN -d www.$DOMAIN --nginx 2>/dev/null || true
        ~/.acme.sh/acme.sh --install-cert -d $DOMAIN --key-file /root/cert/$DOMAIN/privkey.pem --fullchain-file /root/cert/$DOMAIN/fullchain.pem --reloadcmd 'systemctl reload nginx' 2>/dev/null || true

        ~/.acme.sh/acme.sh --issue -d fuckdengxiangning.sbs --nginx 2>/dev/null || true
        ~/.acme.sh/acme.sh --install-cert -d fuckdengxiangning.sbs --key-file /root/cert/fuckdengxiangning.sbs/privkey.pem --fullchain-file /root/cert/fuckdengxiangning.sbs/fullchain.pem --reloadcmd 'systemctl reload nginx' 2>/dev/null || true
    " || warn "SSL 证书申请可能需要手动处理（DNS 验证等）"
    log "SSL 证书处理完成"
}

# ==================== 状态检查 ====================
check_status() {
    echo ""
    log "========== 服务状态 =========="
    ssh_run "
        echo '--- Nginx ---'
        systemctl is-active nginx
        echo '--- 个人主页 ---'
        systemctl is-active home-page 2>/dev/null || echo '未安装'
        curl -s -o /dev/null -w 'HTTP %{http_code}' http://127.0.0.1:$HOME_PAGE_PORT/ 2>/dev/null && echo ''
        echo '--- 青春档案 ---'
        systemctl is-active laoda-page 2>/dev/null || echo '未安装'
        curl -s -o /dev/null -w 'HTTP %{http_code}' http://127.0.0.1:$LAODA_PAGE_PORT/ 2>/dev/null && echo ''
    "
    echo ""
    log "部署完成！"
    log "个人主页：https://$DOMAIN"
    log "青春档案：https://$DOMAIN$DOMAIN_LAODA_PATH"
}

# ==================== 主流程 ====================
main() {
    echo ""
    echo "========================================"
    echo "   VPS 一键部署脚本"
    echo "   目标：$SSH_HOST"
    echo "========================================"
    echo ""

    read -p "即将部署到 $SSH_HOST，是否继续？(y/n): " confirm
    if [ "$confirm" != "y" ]; then
        err "已取消"
    fi

    install_deps
    pull_code
    setup_ssl
    setup_nginx
    deploy_homepage
    deploy_laoda
    check_status
}

main "$@"
