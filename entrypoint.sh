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

# 2. 检查 .env 配置文件
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        echo "⚠️ 未检测到 .env 配置文件，已从 .env.example 自动生成基础配置。"
        cp .env.example .env
    else
        echo "❌ 错误: 找不到 .env 或 .env.example 配置文件！"
        exit 1
    fi
fi

# 3. 如果容器启动时传入了自定义命令（例如 bash config.sh, bash auto.sh local 等），直接执行该命令
if [ "$#" -gt 0 ]; then
    echo "▶️ 执行自定义指令: $@"
    exec "$@"
fi

# 4. 如果配置了 RUN_ONCE=true，则单次执行 auto.sh 后退出
if [ "${RUN_ONCE,,}" = "true" ] || [ "${RUN_ONCE}" = "1" ]; then
    echo "⚡ 运行单次测速任务 (RUN_ONCE=true)..."
    exec bash auto.sh
fi

# 5. 默认启动常驻定时调度器
echo "🕒 正在启动定时调度任务..."
exec python3 scheduler.py
