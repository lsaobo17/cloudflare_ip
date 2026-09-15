FROM python:3.11-slim

# 设置环境变量
ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

# 安装基础系统工具（curl、git、bash、ca-certificates、tzdata）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        bash \
        ca-certificates \
        tzdata && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 先复制 requirements.txt 提升构建缓存命中率
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制项目代码与脚本
COPY . .

# 确保脚本具备执行权限并去除 CRLF
RUN sed -i 's/\r$//' *.sh *.py 2>/dev/null || true && \
    chmod +x *.sh *.py

# 默认入口
ENTRYPOINT ["/app/entrypoint.sh"]
