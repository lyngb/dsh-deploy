#!/bin/sh
set -e

# 1) 确保 DSH_HOME 存在
mkdir -p "$DSH_HOME/profiles"

# 2) 凭据文件：不存在则创建
touch "$DSH_HOME/.credentials.yaml"

# 3) 若环境变量提供了 API Key 且文件里还没有，则写入
#    （优先保留挂载卷里已有的 key，避免每次重启覆盖）
if [ -n "$DEEPSEEK_API_KEY" ] && ! grep -q "DEEPSEEK_API_KEY" "$DSH_HOME/.credentials.yaml"; then
  printf 'DEEPSEEK_API_KEY: %s\n' "$DEEPSEEK_API_KEY" >> "$DSH_HOME/.credentials.yaml"
fi

# 4) 启动 web profile（端口可用环境变量覆盖）
exec dsh --profile web --port "${PORT:-3080}"
