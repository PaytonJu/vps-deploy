# 🚀 VPS 一键部署脚本

## 这是什么？

一个脚本搞定两个网站的部署：

1. **个人主页**（`https://jucode.org`）— 用 Flask 写的个人网站
2. **青春档案**（`https://jucode.org/laoda`）— 存青春回忆的静态页面

## 什么时候需要用？

- ✅ **第一次买 VPS** → 跑一次脚本，网站就上线了
- ✅ **换 VPS / 迁移服务器** → 改个 IP，再跑一次，完事
- ✅ **服务器重装系统** → 同样的操作

## 怎么用？

### 第一步：下载脚本

```bash
git clone https://github.com/PaytonJu/vps-deploy.git
cd vps-deploy
```

### 第二步：修改配置

编辑 `deploy.sh`，翻到上面那个"配置区域"，改这几个地方：

```bash
SSH_HOST="你的VPS的IP地址"      # 必改
SSH_PASSWORD="你的VPS密码"      # 必改
DOMAIN="你的域名"               # 必改
```

### 第三步：运行

```bash
chmod +x deploy.sh
./deploy.sh
```

然后等它跑完就行了，大概 1-3 分钟。

## 它自动做了哪些事？

| 步骤 | 做的事 |
|------|--------|
| ① 安装依赖 | 装 Nginx、Python3、Git 等 |
| ② 拉取代码 | 从 GitHub 下载两个项目的最新代码 |
| ③ 申请证书 | 自动申请 Let's Encrypt 的 HTTPS 证书 |
| ④ 配置 Nginx | 设置反向代理，域名指向对应的服务 |
| ⑤ 部署主页 | 启动 Flask 应用（开机自启） |
| ⑥ 部署档案 | 启动静态文件服务器（开机自启） |
| ⑦ 检查状态 | 确认所有服务正常运行 |

## 常用管理命令

部署完之后，你可能会需要用到的命令：

```bash
# 查看服务状态
systemctl status home-page     # 个人主页
systemctl status laoda-page    # 青春档案
systemctl status nginx         # 网页服务器

# 重启服务
systemctl restart home-page    # 重启个人主页
systemctl restart laoda-page   # 重启青春档案
systemctl reload nginx         # 重载 Nginx 配置

# 看日志
journalctl -u home-page -f     # 实时看个人主页日志
journalctl -u laoda-page -f    # 实时看青春档案日志
```

## 上传新内容

修改完代码后：

```bash
# 推送到 GitHub
git add .
git commit -m "改了啥"
git push

# 然后到服务器上更新
ssh root@你的IP
cd /root/laoda_page    # 或者 /root/Home_Page
git pull
```

## 两个项目对应的仓库

| 项目 | GitHub 地址 |
|------|-------------|
| 个人主页 | https://github.com/PaytonJu/Home_Page |
| 青春档案 | https://github.com/PaytonJu/laoda-page |
| 部署脚本（当前） | https://github.com/PaytonJu/vps-deploy |
