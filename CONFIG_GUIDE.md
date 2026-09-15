# Cloudflare IP 优选 - 参数配置详细教程

本项目的所有核心功能、云端同步、通知推送与测速性能均由 `.env` 文件控制。

---

## 目录
- [一、修改配置的两种方式](#一修改配置的两种方式)
  - [方式 1：终端交互式面板（推荐小白）](#方式-1终端交互式面板推荐小白)
  - [方式 2：直接编辑 .env 文件（推荐快捷）](#方式-2直接编辑-env-文件推荐快捷)
- [二、常见使用场景快速预设（对号入座）](#二常见使用场景快速预设对号入座)
  - [场景 A：纯自用本地测速（无需任何第三方账号）](#场景-a纯自用本地测速无需任何第三方账号)
  - [场景 B：推送到 GitHub 仓库作为免费订阅源](#场景-b推送到-github-仓库作为免费订阅源)
  - [场景 C：推送到 Cloudflare R2 对象存储（最推荐）](#场景-c推送到-cloudflare-r2-对象存储最推荐)
- [三、核心参数详解与凭据获取指南](#三核心参数详解与凭据获取指南)
  - [1. 基础模式与功能开关](#1-基础模式与功能开关)
  - [2. 测速性能参数（一般保持默认）](#2-测速性能参数一般保持默认)
  - [3. Cloudflare R2 参数获取教程](#3-cloudflare-r2-参数获取教程)
  - [4. GitHub 自动同步参数获取教程](#4-github-自动同步参数获取教程)
  - [5. Telegram 战报通知配置教程](#5-telegram-战报通知配置教程)
  - [6. 邮件通知配置教程](#6-邮件通知配置教程)
  - [7. 代理配置（解决国内网络无法访问 TG / GitHub）](#7-代理配置解决国内网络无法访问-tg--github)
- [四、定时任务 CRON 表达式常用参考](#四定时任务-cron-表达式常用参考)

---

## 一、修改配置的两种方式

### 方式 1：终端交互式面板（推荐小白）
无需手动编辑代码，在容器内启动自带的交互式菜单：
```bash
docker compose run --rm cloudflare_ip bash config.sh
```
控制台会弹出一个全中文选项菜单，通过输入数字即可逐项开启/关闭功能、填入凭证，改动会自动保存并持久化到宿主机的 `.env` 文件。

### 方式 2：直接编辑 .env 文件（推荐快捷）
如果本地还没有 `.env` 文件，先从模板创建：
```bash
cp .env.example .env
```
然后使用任意编辑器打开 `.env` 逐项修改保存即可。

---

## 二、常见使用场景快速预设（对号入座）

### 场景 A：纯自用本地测速（无需任何第三方账号）
只需要在本地测速生成 `best_ips.txt`，供本机或家庭局域网内的 OpenWrt/EdgeTunnel 读取：
```ini
DEFAULT_MODE="local"
USE_GH="false"
USE_R2="false"
USE_TG="false"
USE_MAIL="false"
```
> **效果**：每次执行仅在本地测出最快 IP，不执行任何外部上传和推送。

### 场景 B：推送到 GitHub 仓库作为免费订阅源
希望自动把每天测出的最新 IP 提交到自己的 GitHub 仓库，生成可订阅的 Raw 链接：
```ini
DEFAULT_MODE="cloud"
USE_GH="true"
USE_R2="false"
GH_SYNC_MODE="api"          # 推荐 api
GH_OWNER="你的GitHub用户名"
GH_REPO_NAME="你的公开仓库名"  # 例如 cf-ips
GH_TOKEN="ghp_xxxxxx..."    # 拥有 repo 权限的个人访问令牌
```

### 场景 C：推送到 Cloudflare R2 对象存储（最推荐）
上传到 Cloudflare 免费对象存储，绑定自己的域名作为订阅源（不限流、无视墙、速度飞快）：
```ini
DEFAULT_MODE="cloud"
USE_R2="true"
USE_GH="false"
CF_ACCOUNT_ID="你的Cloudflare账户ID"
CF_ACCESS_KEY="你的R2访问密钥ID"
CF_SECRET_KEY="你的R2机密访问密钥"
CF_BUCKET_NAME="你的R2存储桶名称"
```

---

## 三、核心参数详解与凭据获取指南

### 1. 基础模式与功能开关
| 变量名 | 默认值 | 作用说明 |
| :--- | :--- | :--- |
| `DEFAULT_MODE` | `cloud` | 默认运行模式。`cloud`：测速并同步上传；`local`：仅本地测速不同步 |
| `USE_GH` | `true` | 是否将结果上传到 GitHub 仓库 |
| `USE_R2` | `true` | 是否将结果上传到 Cloudflare R2 存储桶 |
| `USE_TG` | `true` | 测速完成后是否发送 Telegram 战报通知 |
| `USE_MAIL` | `true` | 测速完成后是否发送 Email 邮件通知 |

> 💡 **技巧**：不需要的功能直接设为 `"false"`，脚本会自动跳过，不会报错。

---

### 2. 测速性能参数（一般保持默认）
| 变量名 | 默认值 | 说明与调优建议 |
| :--- | :--- | :--- |
| `INPUT_URL` | `https://ips.gaoji.uk/ips.txt` | 候选 IP 列表下载地址 |
| `TCP_WORKERS` | `400` | TCP 延迟探测并发数（VPS 性能强可调至 600~800，软路由建议 200） |
| `TCP_TIMEOUT` | `1.5` | TCP 探测超时上限（秒），过滤高延迟节点 |
| `SPEED_WORKERS` | `12` | 实际下载测速并发数（建议 8~16，不宜设过大以免抢占带宽） |
| `SPEED_TIMEOUT` | `6.0` | 单个 IP 测速限定秒数 |
| `SPEED_MIN` | `8.0` | 达标最低速率（Mbps），大于该值的 IP 才会写入 `best_ips.txt` |
| `TOP_PER_REGION` | `10` | 每个地区挑选延迟最低的前 N 个 IP 进行下载速度测试 |

---

### 3. Cloudflare R2 参数获取教程
R2 是 Cloudflare 提供的 S3 兼容对象存储，每月有 10GB 免费存储和千万次免费读取。

1. **获取 `CF_ACCOUNT_ID`（账户 ID）**：
   - 登录 [Cloudflare 控制台](https://dash.cloudflare.com/)；
   - 点击右侧或主页的任意域名，在页面右下角能看到 **“账户 ID” (Account ID)**，点击复制。
2. **获取 `CF_BUCKET_NAME`（存储桶名称）**：
   - 左侧菜单选择 **存储与数据库** -> **R2 对象存储**；
   - 点击 **创建存储桶**，输入一个英文名称（如 `cf-ips`），保持默认点击创建即可。
3. **获取 `CF_ACCESS_KEY` 与 `CF_SECRET_KEY`**：
   - 在 R2 页面右侧点击 **管理 API 令牌 (Manage API Tokens)**；
   - 点击 **创建 API 令牌**；
   - 权限选择 **管理员读写 (Object Read & Write)**；
   - TTL 选择永久或留空，点击页面底部的 **创建 API 令牌**；
   - **关键步骤**：页面会弹出 **访问密钥 ID** 和 **机密访问密钥**，复制并妥善保存（关闭后无法再次查看机密密钥）。
4. **绑定自定义域名作为订阅链接（可选）**：
   - 进入创建好的存储桶 -> **设置** -> **公开访问 / 自定义域**；
   - 绑定一个二级域名（如 `ips.yourdomain.com`）；
   - 之后订阅地址即为：
     - 高速优选：`https://ips.yourdomain.com/best_ips.txt`
     - 全量可用：`https://ips.yourdomain.com/full_ips.txt`

---

### 4. GitHub 自动同步参数获取教程
1. **创建接收 IP 的仓库**：
   - 在 GitHub 新建一个仓库（例如命名为 `cloudflare-best-ips`），设为 **Public**。
2. **获取 `GH_TOKEN`（个人访问令牌）**：
   - 点击 GitHub 右上角头像 -> **Settings**；
   - 点击左下角 **Developer settings** -> **Personal access tokens** -> **Tokens (classic)**；
   - 点击 **Generate new token (classic)**；
   - Note 填写备注（如 `cf-ip-sync`），勾选 **`repo`**（完整仓库访问权限）；
   - 点击生成，复制以 `ghp_` 开头的 Token。
3. **配置参数**：
   ```ini
   GH_SYNC_MODE="api"
   GH_OWNER="你的GitHub用户名"
   GH_REPO_NAME="cloudflare-best-ips"
   GH_TOKEN="ghp_xxxxxxxxxxxx"
   ```

---

### 5. Telegram 战报通知配置教程
1. **获取 `TG_BOT_TOKEN`**：
   - 在 Telegram 中搜索关注官方机器人 **`@BotFather`**；
   - 发送指令 `/newbot`，按提示给机器人起名称和用户名；
   - 创建成功后，会返回一段长字符 Token，格式类似 `1234567890:ABCdef...`。
2. **获取 `TG_CHAT_ID`**：
   - 在 Telegram 中搜索关注 **`@userinfobot`** 并点击启动；
   - 机器人会直接回复您的 **Id**（纯数字，如 `123456789`），这就是您的 Chat ID；
   - 如果是推送到频道或群组，请将创建的机器人拉进群，并设为管理员。
3. **国内机器反代支持**：
   - 如果运行在大陆境内服务器无法直连 Telegram，可将 `TG_USE_PROXY` 设为 `"true"`，并在 `TG_PROXY_DOMAIN` 中填入你的反代域名（如 CF Worker 反代 `api.telegram.org`）。

---

### 6. 邮件通知配置教程
测速完成后通过 SMTP 自动发送 HTML 格式的优选战报邮件。
以常见的 **QQ 邮箱** 为例：
```ini
MAIL_HOST="smtp.qq.com"
MAIL_USER="12345678@qq.com"       # 发件人QQ邮箱
MAIL_PASS="abcdefghijklmnop"      # 注意：是QQ邮箱后台生成的16位授权码，不是QQ登录密码！
MAIL_TO="your_target@domain.com"  # 接收战报的目标邮箱
```
> **如何获取 QQ 邮箱授权码**：
> 电脑网页登录 QQ 邮箱 -> 设置 -> 账户 -> 往下翻找到 **POP3/IMAP/SMTP/Exchange/CardDAV/CalDAV服务** -> 开启 **POP3/SMTP服务**，按提示发短信验证即可获得 16 位授权码。

---

### 7. 代理配置（解决国内网络无法访问 TG / GitHub）
如果您的运行设备配置了本地代理工具（例如 Clash、v2rayA 等）：
```ini
LOCAL_USE_PROXY="true"
LOCAL_PROXY_ADDR="http://127.0.0.1:7890"  # 本地代理端口
```
> ⚠️ **注意**：脚本在测速核心阶段会自动强行剔除所有代理变量，**确保测出的是本地真实直连速度**；仅在推送战报至 TG 或上传至 GitHub 时才会按需调用本地代理，不会影响测速精度。

---

## 四、定时任务 CRON 表达式常用参考

定时计划在 `docker-compose.yml` 中的 `CRON_SCHEDULE` 变量设置：

| 执行频率 | CRON 表达式 | 场景说明 |
| :--- | :--- | :--- |
| **项目原作者默认** | `0 8,14-23,0-2 * * *` | 每天 14:00~次日02:00（高峰期整点测速）以及 08:00 整点测速 |
| **每 1 小时一次** | `0 * * * *` | 24 小时全天整点更新 |
| **每 2 小时一次** | `0 */2 * * *` | 适合资源适中的 VPS / NAS |
| **每 6 小时一次** | `0 */6 * * *` | 每天运行 4 次（0点、6点、12点、18点） |
| **每天早晚各一次** | `0 8,20 * * *` | 每天早晨 8 点与晚间 20 点各一次 |
| **每 30 分钟一次** | `*/30 * * * *` | 高频更新（测速会持续占用网络带宽，请谨慎） |
