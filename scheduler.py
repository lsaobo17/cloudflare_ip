#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Cloudflare IP 优选 Docker 定时调度器
支持标准 5 位 Cron 表达式，实时日志输出至 stdout，优雅响应容器停止信号。
"""

import os
import signal
import subprocess
import sys
import time
from datetime import datetime

try:
    from croniter import croniter
except ImportError:
    print("❌ 缺少 croniter 模块，请先运行: pip install croniter", flush=True)
    sys.exit(1)

# 信号控制
running = True

def sig_handler(signum, frame):
    global running
    sig_name = signal.Signals(signum).name
    print(f"\n[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 🛑 接收到系统停止信号 ({sig_name})，准备退出调度器...", flush=True)
    running = False

signal.signal(signal.SIGTERM, sig_handler)
signal.signal(signal.SIGINT, sig_handler)

def run_job():
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"\n=======================================================", flush=True)
    print(f"[{now_str}] 🚀 触发定时优选任务: bash auto.sh", flush=True)
    print(f"=======================================================", flush=True)
    
    # 直接运行 bash auto.sh，继承当前环境变量与工作目录
    try:
        proc = subprocess.run(["bash", "auto.sh"])
        exit_code = proc.returncode
        finish_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        if exit_code == 0:
            print(f"[{finish_str}] ✅ 本轮优选任务执行完毕。", flush=True)
        else:
            print(f"[{finish_str}] ⚠️ 本轮任务执行退出，返回状态码: {exit_code}", flush=True)
    except Exception as e:
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] ❌ 任务执行出错: {e}", flush=True)

def main():
    global running
    cron_expr = os.getenv("CRON_SCHEDULE", "0 8,14-23,0-2 * * *").strip()
    run_on_start = os.getenv("RUN_ON_START", "true").lower() in ("true", "1", "yes")

    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 🕒 优选调度器已启动", flush=True)
    print(f"    ├─ 定时计划 (CRON): {cron_expr}", flush=True)
    print(f"    └─ 启动时立即执行 (RUN_ON_START): {run_on_start}", flush=True)

    # 验证 cron 表达式有效性
    if not croniter.is_valid(cron_expr):
        print(f"❌ 错误: 无效的 CRON 表达式 '{cron_expr}'！请在环境变量中设置正确的 5 位 Cron 语法（例如: '0 * * * *'）。", flush=True)
        sys.exit(1)

    # 如果配置了启动时立即执行
    if run_on_start and running:
        run_job()

    while running:
        now = datetime.now()
        iter_cron = croniter(cron_expr, now)
        next_run = iter_cron.get_next(datetime)
        wait_seconds = (next_run - now).total_seconds()

        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] ⏳ 下次任务触发时间: {next_run.strftime('%Y-%m-%d %H:%M:%S')} (等待 {int(wait_seconds)} 秒)...", flush=True)

        # 细粒度分片 sleep，以便快速响应停止信号
        while wait_seconds > 0 and running:
            sleep_step = min(wait_seconds, 1.0)
            time.sleep(sleep_step)
            wait_seconds -= sleep_step

        if running:
            run_job()

    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 🏁 优选调度器已安全退出。", flush=True)

if __name__ == "__main__":
    main()
