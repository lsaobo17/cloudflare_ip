# Cloudflare IP 优选 - Docker 部署指南

本项目已完整支持 Docker 与 Docker Compose 容器化部署，支持**定时常驻任务**、**单次测速运行**以及**容器内交互式终端配置面板**。

---

## 目录
- [一、云端在线自动构建（GitHub Actions，无需本地安装 Docker）](#一云端在线自动构建github-actions无需本地安装-docker)
- [二、快速开始（推荐 Docker Compose）](#二快速开始推荐-docker-compose)
- [三、使用 Docker CLI 运行](#三使用-docker-cli-运行)
- [四、运行模式说明](#四运行模式说明)
  - [1. 定时守护模式（默认）](#1-定时守护模式默认)
  - [2. 单次运行测速模式](#2-单次运行测速模式)
  - [3. 容器内交互式配置面板](#3-容器内交互式配置面板)
- [五、环境变量参考](#五环境变量参考)
- [六、数据持久化与结果使用](#六数据持久化与结果使用)
- [七、网络模式说明（Host 模式）](#七网络模式说明host-模式)
- [八、常见问题排查](#八常见问题排查)

---

## 一、云端在线自动构建（GitHub Actions，无需本地安装 Docker）

本项目已集成 **GitHub Actions 自动化 CI/CD 工作流**（位于 `.github/workflows/docker-build.yml`），无需在本地安装 Docker 编译环境即可全自动在云端完成镜像打包：

### 1. 触发方式
- **代码推送自动构建**：每次将代码推送到 GitHub 的 `main` 分支或发布 Release Tag 时，GitHub 云端服务器会自动编译镜像。
- **网页手动一键触发**：进入 GitHub 仓库页面 -> 点击 **Actions** 标签 -> 选择 **在线自动构建并发布 Docker 镜像** -> 点击 **Run workflow** 按钮即可立即在线构建。

### 2. 特性
- **多架构支持**：同时构建并发布 `linux/amd64`（主流 VPS/物理机）与 `linux/arm64`（甲骨文 ARM/群晖 NAS/树莓派）双架构镜像。
- **开箱即用**：镜像自动发布至 GitHub Packages（GHCR），无需配置任何 Docker Hub 账号凭证。

### 3. 如何直接使用云端构建好的镜像
镜像地址为：`ghcr.io/<你的GitHub用户名>/cloudflare_ip:latest`（例如 `ghcr.io/lsaobo17/cloudflare_ip:latest`）。

在 VPS 或 NAS 上直接拉取并运行：
```bash
docker run -d \
  --name cloudflare_ip \
  --restart unless-stopped \
  --net=host \
  -v $(pwd)/.env:/app/.env \
  -v $(pwd)/best_ips.txt:/app/best_ips.txt \
  -v $(pwd)/full_ips.txt:/app/full_ips.txt \
  ghcr.io/lsaobo17/cloudflare_ip:latest
```

---

## 二、快速开始（推荐 Docker Compose）

### 1. 配置参数
如果本地还没有 `.env` 文件，请从模板复制并修改：
```bash
cp .env.example .env
nano .env  # 或使用文本编辑器打开修改
```

### 2. 构建并启动容器
在项目根目录下执行：
```bash
# 构建镜像并在后台启动（如使用在线镜像，可直接将 docker-compose.yml 中的 build 注释，指定 image）
docker compose up -d --build
```

### 3. 查看实时测速日志
```bash
# 查看实时运行日志与测速进度
docker compose logs -f
```

### 4. 停止与管理
```bash
# 停止容器
docker compose stop

# 重启容器
docker compose restart

# 销毁容器
docker compose down
```

---

## 三、使用 Docker CLI 运行

如果您不想使用 Docker Compose，也可以直接使用 `docker` 命令行：

### 1. 构建镜像
```bash
docker build -t cloudflare_ip:latest .
```

### 2. 后台定时常驻运行（Linux 环境推荐加上 `--net=host`）
```bash
docker run -d \
  --name cloudflare_ip \
  --restart unless-stopped \
  --net=host \
  -v $(pwd)/.env:/app/.env \
  -v $(pwd)/best_ips.txt:/app/best_ips.txt \
  -v $(pwd)/full_ips.txt:/app/full_ips.txt \
  -v $(pwd)/README.MD:/app/README.MD \
  cloudflare_ip:latest
```

### 3. 查看日志
```bash
docker logs -f cloudflare_ip
```

---

## 四、运行模式说明

### 1. 定时守护模式（默认）
容器启动后会：
1. 首先立即执行一次完整的测速任务（可由 `RUN_ON_START=false` 关闭）；
2. 随后进入轻量级定时调度器，按照设定的 CRON 周期定时执行；
3. 输出完整的日志到控制台（可通过 `docker logs` 查看）。

默认 CRON 表达式为：`0 8,14-23,0-2 * * *`（每天 14:00~02:00 与 08:00 整点自动测速）。

如需调整定时频率（例如每 2 小时测速一次），只需在 `docker-compose.yml` 中修改 `CRON_SCHEDULE`：
```yaml
environment:
  - CRON_SCHEDULE=0 */2 * * *
```

### 2. 单次运行测速模式
如果希望通过外部脚本（如宿主机原生 crontab）触发，或者仅临时测速一次：

**方式 A：通过 Docker Compose 运行**
```bash
docker compose run --rm -e RUN_ONCE=true cloudflare_ip
```

**方式 B：指定仅本地测速（不触发云端上传与通知）**
```bash
docker compose run --rm cloudflare_ip bash auto.sh local
```

**方式 C：通过 Docker CLI 单次运行**
```bash
docker run --rm -it \
  --net=host \
  -e RUN_ONCE=true \
  -v $(pwd)/.env:/app/.env \
  -v $(pwd)/best_ips.txt:/app/best_ips.txt \
  -v $(pwd)/full_ips.txt:/app/full_ips.txt \
  cloudflare_ip:latest
```

### 3. 容器内交互式配置面板
项目自带交互式命令行配置管理面板 `config.sh`，可以在容器内直接运行并回写宿主机的 `.env`：

```bash
docker compose run --rm cloudflare_ip bash config.sh
```
在控制台中即可使用方向键与数字键交互式配置 R2 凭据、GitHub Token、测速并发、通知开关等参数。

---

## 五、环境变量参考

| 变量名 | 默认值 | 作用说明 |
| :--- | :--- | :--- |
| `TZ` | `Asia/Shanghai` | 容器运行时区，用于日志和 README 时间戳 |
| `CRON_SCHEDULE` | `0 8,14-23,0-2 * * *` | 定时任务 5 位标准 Cron 表达式 |
| `RUN_ON_START` | `true` | 容器首次启动时是否立即触发一次测速 |
| `RUN_ONCE` | `false` | 是否在单次测速完毕后直接退出容器 |

> 提示：测速核心相关的参数（如 `TCP_WORKERS`、`SPEED_MIN`、`CF_ACCOUNT_ID`、`GH_TOKEN` 等）建议直接在挂载的 `.env` 文件中配置。

---

## 六、数据持久化与结果使用

通过数据卷挂载，测速生成的文件会实时保存在宿主机本地目录：

- `best_ips.txt`: 高速优选 IP 结果
- `full_ips.txt`: 全量地区低延迟可用 IP 结果
- `README.MD`: 测速更新记录文档
- `.env`: 运行配置与凭据

**与其他服务联动：**
- **Nginx / Web 订阅服务**：可以将当前目录挂载到宿主机 Nginx 容器作为静态文件站点，供 OpenWrt、Clash、Surge 订阅。
- **EdgeTunnel / Xray**：可以直接读取 `best_ips.txt` 中的 IP 列表。

---

## 七、网络模式说明（Host 模式）

- **Linux 环境（强烈推荐）**：使用 `network_mode: "host"`。优选 IP 需要高并发发起 TCP Ping 和多节点下载测速，宿主机 Host 网络能避开 Docker Bridge 虚拟网卡的 NAT 转发损耗，测出的延迟和下行速度最为准确。
- **Windows / macOS Docker Desktop**：如果提示不支持 host 网络，可直接在 `docker-compose.yml` 中注释掉 `network_mode: "host"`，会自动退回到标准桥接网络模式。

---

## 八、常见问题排查

1. **测速提示“缺少 INPUT_URL”**
   - 检查挂载的 `.env` 文件是否存在并配置了有效 `INPUT_URL`。容器首次启动若无 `.env` 会自动从 `.env.example` 复制。

2. **Windows 宿主机换行符报错（\r 异常）**
   - 容器入口 `entrypoint.sh` 已内置自动 `sed -i 's/\r$//'` 转换，确保无论在 Windows 还是 Linux 下编辑脚本均可无缝兼容。

3. **测速速度显示为 0 或超时**
   - 请检查测速时是否开启了本地代理劫持直连流量。运行测速需要能够直连 Cloudflare 节点。如果需要走本地代理上传到 GitHub 或发送 TG 通知，可在 `.env` 中配置 `LOCAL_USE_PROXY="true"`，脚本会自动将代理和直连测速隔离。
