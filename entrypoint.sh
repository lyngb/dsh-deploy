#!/bin/sh
set -e

# 1) 确保 DSH_HOME 存在
mkdir -p "$DSH_HOME/profiles"

# 2) 凭据文件：不存在则创建
touch "$DSH_HOME/.credentials.yaml"

# 3) 若环境变量提供了 API Key 且文件里还没有，则写入
if [ -n "$DEEPSEEK_API_KEY" ] && ! grep -q "DEEPSEEK_API_KEY" "$DSH_HOME/.credentials.yaml"; then
  printf 'DEEPSEEK_API_KEY: %s\n' "$DEEPSEEK_API_KEY" >> "$DSH_HOME/.credentials.yaml"
fi

# 4) 诊断模式：循环重启 dsh 并打印输出（定位启动崩溃原因用；修好后改回单次启动）
echo "=== dsh web starting (diagnostic loop) ==="
while true; do
  dsh --profile web --host 0.0.0.0 --port "${PORT:-3080}" 2>&1 || true
  echo "=== dsh exited; restarting in 10s ==="
  sleep 10
done
