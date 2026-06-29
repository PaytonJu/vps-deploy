# VPS 部署指南

## 仓库

两个项目已推到 GitHub：

| 项目 | 仓库 |
|------|------|
| 个人主页 | `https://github.com/PaytonJu/Home_Page.git` |
| 青春档案 | `https://github.com/PaytonJu/laoda-page.git` |

## 一键部署

```bash
# 1. 先修改 deploy-vps.sh 顶部的配置
#    - SSH_HOST（服务器 IP）
#    - SSH_PASSWORD（密码，建议用 SSH 密钥）
#    - DOMAIN（你的域名）

# 2. 运行
chmod +x deploy-vps.sh
./deploy-vps.sh
```

脚本会自动：
1. 安装系统依赖（nginx, python3, git 等）
2. 拉取两个仓库的最新代码
3. 申请/安装 SSL 证书
4. 配置 Nginx 反向代理
5. 创建 systemd 服务并启动
6. 检查服务状态

## 手动部署（如果需要）

### 青春档案
```bash
# 从 GitHub 拉取
cd /root
git clone https://github.com/PaytonJu/laoda-page.git

# 启动 HTTP 服务（端口 5003）
cd /root/laoda_page
python3 -m http.server 5003

# 或使用 systemd 服务（推荐）
# service 文件见 deploy-vps.sh
```

### 个人主页
```bash
# 从 GitHub 拉取
cd /root
git clone https://github.com/PaytonJu/Home_Page.git

# 安装依赖
cd /root/Home_Page
pip3 install -r requirements.txt

# 启动（端口 5002）
python3 app.py
```

## 换 VPS 后的迁移步骤

1. 在新服务器装好系统
2. 安装 git、sshpass
3. `git clone https://github.com/PaytonJu/vps-deploy.git`
4. 修改 `deploy-vps.sh` 中的配置
5. `./deploy-vps.sh`
6. 将域名 DNS 解析到新服务器 IP
