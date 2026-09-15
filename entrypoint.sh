#!/bin/bash
set -e

# 进入工作目录
cd /app

# 1. 自动处理 Windows 宿主机挂载文件可能携带的 CRLF 换行符
if [ -f .env ]; then
    sed -i 's/\r$//' .env 2>/dev/null || true
fi
sed -i 's/\r$//' *.sh *.py 2>/dev/null || true
chmod +x *.sh *.py 2>/dev/null || true

# 2. 检查 .env 配置文件，若不存在则从模板初始化
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        echo "⚠️ 未检测到 .env 配置文件，已从 .env.example 自动生成基础配置。"
        cp .env.example .env
    else
        echo "❌ 错误: 找不到 .env 或 .env.example 配置文件！"
        exit 1
    fi
fi

# 3. 将从 Docker 环境变量（如 docker-compose.yml）传入的配置同步/覆盖到 .env 文件中
python3 - <<'EOF'
import os

env_file = ".env"
vars_to_sync = [
    "DEFAULT_MODE", "USE_GH", "USE_R2", "USE_TG", "USE_MAIL",
    "INPUT_URL", "DOWNLOAD_TIMEOUT", "MAX_NODES",
    "TCP_WORKERS", "TCP_TIMEOUT", "SPEED_WORKERS", "SPEED_TIMEOUT",
    "SPEED_MIN", "SPEED_PROCESS_BUFFER", "TOP_PER_REGION",
    "CF_ACCOUNT_ID", "CF_ACCESS_KEY", "CF_SECRET_KEY", "CF_BUCKET_NAME",
    "GH_SYNC_MODE", "GH_OWNER", "GH_REPO_NAME", "GH_TOKEN", "GH_USE_PROXY", "GH_PROXY_DOMAIN",
    "TG_BOT_TOKEN", "TG_CHAT_ID", "TG_USE_PROXY", "TG_PROXY_DOMAIN",
    "MAIL_HOST", "MAIL_USER", "MAIL_PASS", "MAIL_TO",
    "LOCAL_USE_PROXY", "LOCAL_PROXY_ADDR"
]

lines = []
if os.path.exists(env_file):
    with open(env_file, "r", encoding="utf-8") as f:
        lines = f.readlines()

updated_keys = set()
new_lines = []
for line in lines:
    clean = line.strip()
    if clean and not clean.startswith("#") and "=" in clean:
        k, _ = clean.split("=", 1)
        k = k.strip()
        if k in vars_to_sync and os.environ.get(k):
            val = os.environ[k]
            new_lines.append(f'{k}="{val}"\n')
            updated_keys.add(k)
            continue
    new_lines.append(line)

for k in vars_to_sync:
    if k not in updated_keys and os.environ.get(k):
        val = os.environ[k]
        new_lines.append(f'{k}="{val}"\n')

with open(env_file, "w", encoding="utf-8") as f:
    f.writelines(new_lines)
EOF

# 4. 如果容器启动时传入了自定义命令（例如 bash config.sh, bash auto.sh local 等），直接执行该命令
if [ "$#" -gt 0 ]; then
    echo "▶️ 执行自定义指令: $@"
    exec "$@"
fi

# 5. 如果配置了 RUN_ONCE=true，则单次执行 auto.sh 后退出
if [ "${RUN_ONCE,,}" = "true" ] || [ "${RUN_ONCE}" = "1" ]; then
    echo "⚡ 运行单次测速任务 (RUN_ONCE=true)..."
    exec bash auto.sh
fi

# 6. 默认启动常驻定时调度器
echo "🕒 正在启动定时调度任务..."
exec python3 scheduler.py
