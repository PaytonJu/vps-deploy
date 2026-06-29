#!/bin/bash
# ============================================================
# 🚀 VPS 一键部署脚本
# 版本：1.0
#
# 这个脚本会帮你自动部署两个项目到你的 VPS 上：
#   1. 个人主页（Home_Page）—— 你的域名首页
#   2. 青春档案（laoda-page）—— 存青春回忆的页面
#
# 💡 什么时候用？
#   - 第一次买 VPS，要部署网站
#   - 换 VPS 了，要迁移到新服务器
#   - 服务器重装系统了，要重新部署
#
# 📋 使用步骤：
#   1. 把本脚本放到你的电脑上
#   2. 修改下面"配置区域"里的内容（改 IP、域名、密码）
#   3. 终端运行： chmod +x deploy.sh && ./deploy.sh
#   4. 等着它自动跑完就行
#
# ⚠️ 注意：
#   - 你的 VPS 需要是 Ubuntu/Debian 系统
#   - 脚本会自动安装 Nginx、Python3、Git 等软件
#   - 如果 SSH 设置了密钥登录，密码那行可以留空
# ============================================================

set -e  # 只要任何一步出错，脚本就停，防止搞坏系统

# ============================================================
# ==================== 🛠 配置区域 ====================
# ！！换 VPS 的时候，只要改这个地方就行 ！！
# ============================================================

SSH_HOST="198.46.193.163"         # ← 你的 VPS IP 地址
SSH_USER="root"                    # ← SSH 登录用户名（一般就是 root）
SSH_PORT="22"                      # ← SSH 端口（默认 22）
SSH_PASSWORD="6dMvNlZr2TgYT92w79" # ← SSH 密码（建议后期换成密钥登录更安全）

DOMAIN="jucode.org"                # ← 你的域名
DOMAIN_LAODA_PATH="/laoda"         # ← 青春档案的访问路径（比如 jucode.org/laoda）

HOME_PAGE_PORT="5002"              # ← 个人主页运行的端口（一般不用改）
LAODA_PAGE_PORT="5003"             # ← 青春档案运行的端口（一般不用改）

# GitHub 仓库地址（不用改，除非你 fork 了）
HOME_PAGE_REPO="https://github.com/PaytonJu/Home_Page.git"
LAODA_PAGE_REPO="https://github.com/PaytonJu/laoda-page.git"

# ============================================================
# ==================== 以下内容不用动 ====================
# ============================================================

# --- 终端颜色（让输出更好看） ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 打印带颜色的日志 ---
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# --- SSH 连接命令（支持密码和密钥两种方式） ---
# 如果填了密码就用 sshpass 自动登录，没填就用密钥
SSH_CMD="ssh -o StrictHostKeyChecking=no -p $SSH_PORT"
SCP_CMD="scp -o StrictHostKeyChecking=no -P $SSH_PORT"

if [ -n "$SSH_PASSWORD" ]; then
    SSH_CMD="sshpass -p '$SSH_PASSWORD' $SSH_CMD"
    SCP_CMD="sshpass -p '$SSH_PASSWORD' $SCP_CMD"
fi

# 在远程服务器上执行命令
ssh_run() {
    $SSH_CMD "$SSH_USER@$SSH_HOST" "$@"
}

# ============================================================
# 以下每个函数对应部署的一个步骤
# ============================================================

# -------------------- 第1步：安装依赖 --------------------
# 目标：在 VPS 上安装 Nginx（网页服务器）、Python3、Git 等
install_deps() {
    log "【1/7】安装系统依赖（nginx、python3、git...）"
    ssh_run "
        apt-get update -qq && apt-get install -y -qq nginx python3 python3-pip git sshpass curl 2>/dev/null
    " || warn "部分依赖可能已存在，没关系继续"
    log "✅ 依赖安装完成"
}

# -------------------- 第2步：拉取代码 --------------------
# 目标：从 GitHub 把两个项目的代码拉到 VPS 上
pull_code() {
    log "【2/7】从 GitHub 拉取最新代码..."

    log "   → 拉取个人主页..."
    ssh_run "
        if [ -d /root/Home_Page ]; then
            cd /root/Home_Page && git pull    # 已有代码就更新
        else
            git clone $HOME_PAGE_REPO /root/Home_Page  # 没有就全新克隆
        fi
    "

    log "   → 拉取青春档案..."
    ssh_run "
        if [ -d /root/laoda_page ]; then
            cd /root/laoda_page && git pull
        else
            git clone $LAODA_PAGE_REPO /root/laoda_page
        fi
    "
    log "✅ 代码拉取完成"
}

# -------------------- 第3步：配置 Nginx 反向代理 --------------------
# 目标：让 Nginx 把用户访问的域名转发到对应的 Python 服务
# 比如访问 jucode.org → 转到 5002 端口（个人主页）
#     访问 jucode.org/laoda → 转到 5003 端口（青春档案）
setup_nginx() {
    log "【3/7】配置 Nginx 反向代理..."

    # 写入 Nginx 配置文件
    ssh_run "
        cat > /etc/nginx/sites-enabled/default << 'NGINX'
# ===== 默认站点（啥都不干，防止被扫到） =====
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 444;  # 直接断开连接，啥都不返回
}

# ===== 🌐 主站：$DOMAIN =====
server {
    listen 80;
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN;

    # --- SSL 证书（https 加密） ---
    # 换服务器后需要重新申请证书，或者把旧证书复制过来
    ssl_certificate /root/cert/$DOMAIN/fullchain.pem;
    ssl_certificate_key /root/cert/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # 青春档案（访问 /laoda 开头的路径时，转发到 5003 端口）
    location $DOMAIN_LAODA_PATH/ {
        proxy_pass http://127.0.0.1:$LAODA_PAGE_PORT/;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
    }

    # 个人主页（访问其他所有路径时，转发到 5002 端口）
    location / {
        proxy_pass http://127.0.0.1:$HOME_PAGE_PORT;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
    }
}

# ===== 🔁 备用域名（fuckdengxiangning.sbs 也指向个人主页） =====
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
    # 测试 Nginx 配置是否正确，正确的话重新加载
    ssh_run "nginx -t && systemctl reload nginx" || warn "Nginx 配置测试失败，稍后需要手动检查"
    log "✅ Nginx 配置完成"
}

# -------------------- 第4步：部署青春档案 --------------------
# 目标：用 Python 内置的 HTTP 服务器提供静态文件服务
# 并创建 systemd 服务（服务器重启后自动启动）
deploy_laoda() {
    log "【4/7】启动青春档案（端口 $LAODA_PAGE_PORT）..."

    # 创建 systemd 服务单元文件
    # systemd 是 Linux 的服务管理器，可以保证程序挂了自动重启
    ssh_run "
        cat > /etc/systemd/system/laoda-page.service << 'SERVICE'
[Unit]
Description=青春档案 - 静态页面服务
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
        systemctl daemon-reload    # 重新加载 systemd
        systemctl enable laoda-page  # 设为开机自启
        systemctl restart laoda-page # 启动服务
    "
    log "✅ 青春档案已启动"
}

# -------------------- 第5步：部署个人主页 --------------------
# 目标：安装 Python 依赖后启动个人主页的 Flask 应用
deploy_homepage() {
    log "【5/7】部署个人主页（端口 $HOME_PAGE_PORT）..."

    # 安装 Python 第三方库（Flask 等）
    ssh_run "
        cd /root/Home_Page
        pip3 install -r requirements.txt -q 2>/dev/null || pip install -r requirements.txt -q
    " || warn "安装依赖可能有问题，稍后可以手动检查"

    # 同样创建 systemd 服务
    ssh_run "
        cat > /etc/systemd/system/home-page.service << 'SERVICE'
[Unit]
Description=个人主页 Flask 服务
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
    log "✅ 个人主页已启动"
}

# -------------------- 第6步：申请 SSL 证书 --------------------
# 目标：用 acme.sh 免费申请 Let's Encrypt 的 HTTPS 证书
# 这样网站就能用 https:// 安全访问了
setup_ssl() {
    log "【6/7】检查并申请 SSL 证书..."
    ssh_run "
        # 安装 acme.sh（如果还没装的话）
        if ! command -v acme.sh &>/dev/null; then
            curl https://get.acme.sh | sh -s email=admin@$DOMAIN
        fi

        # 为主域名申请证书
        ~/.acme.sh/acme.sh --issue -d $DOMAIN -d www.$DOMAIN --nginx 2>/dev/null || echo '证书可能已存在或需要手动处理'
        ~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
            --key-file /root/cert/$DOMAIN/privkey.pem \
            --fullchain-file /root/cert/$DOMAIN/fullchain.pem \
            --reloadcmd 'systemctl reload nginx' 2>/dev/null || true

        # 为备用域名申请证书
        ~/.acme.sh/acme.sh --issue -d fuckdengxiangning.sbs --nginx 2>/dev/null || echo '证书可能已存在或需要手动处理'
        ~/.acme.sh/acme.sh --install-cert -d fuckdengxiangning.sbs \
            --key-file /root/cert/fuckdengxiangning.sbs/privkey.pem \
            --fullchain-file /root/cert/fuckdengxiangning.sbs/fullchain.pem \
            --reloadcmd 'systemctl reload nginx' 2>/dev/null || true
    " || warn "SSL 证书申请可能需要手动处理（DNS 验证等）"
    log "✅ SSL 证书处理完成"
}

# -------------------- 第7步：检查服务状态 --------------------
# 目标：确认所有服务都正常运行
check_status() {
    echo ""
    log "========== 📊 服务状态检查 =========="
    ssh_run "
        echo '--- Nginx 状态 ---'
        systemctl is-active nginx
        echo ''
        echo '--- 个人主页 ---'
        systemctl is-active home-page 2>/dev/null || echo '❗ 未安装/未运行'
        curl -s -o /dev/null -w 'HTTP 响应码: %{http_code}' http://127.0.0.1:$HOME_PAGE_PORT/ 2>/dev/null && echo ''
        echo ''
        echo '--- 青春档案 ---'
        systemctl is-active laoda-page 2>/dev/null || echo '❗ 未安装/未运行'
        curl -s -o /dev/null -w 'HTTP 响应码: %{http_code}' http://127.0.0.1:$LAODA_PAGE_PORT/ 2>/dev/null && echo ''
    "
    echo ""
    echo "========================================="
    log "🎉 全部部署完成！"
    log "   个人主页：https://$DOMAIN"
    log "   青春档案：https://$DOMAIN$DOMAIN_LAODA_PATH"
    echo ""
    echo "📝 常用管理命令："
    echo "   systemctl status home-page     # 查看个人主页状态"
    echo "   systemctl status laoda-page    # 查看青春档案状态"
    echo "   systemctl restart home-page    # 重启个人主页"
    echo "   systemctl restart laoda-page   # 重启青春档案"
    echo "   journalctl -u home-page -f     # 实时查看日志"
    echo "   systemctl reload nginx         # 重载 Nginx 配置"
    echo "========================================="
}

# ============================================================
# ==================== 主流程 ====================
# 这就是脚本的入口，按顺序执行上面的 7 个步骤
# ============================================================
main() {
    echo ""
    echo "========================================"
    echo "   🚀 VPS 一键部署脚本"
    echo "   目标服务器：$SSH_HOST"
    echo "   部署项目：个人主页 + 青春档案"
    echo "========================================"
    echo ""

    # 安全确认（防止手滑点到运行）
    read -p "确认要将代码部署到 $SSH_HOST 吗？(输入 y 确认): " confirm
    if [ "$confirm" != "y" ]; then
        err "用户取消部署"
    fi

    # 开始按步骤部署
    install_deps       # 第1步：装软件
    pull_code          # 第2步：拉代码
    setup_ssl          # 第3步：申请证书
    setup_nginx        # 第4步：配 Nginx
    deploy_homepage    # 第5步：部署个人主页
    deploy_laoda       # 第6步：部署青春档案
    check_status       # 第7步：检查结果
}

# 执行主函数
main "$@"
