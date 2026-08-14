#!/bin/sh
set -e

# 1) 确保 DSH_HOME 存在
mkdir -p "$DSH_HOME/profiles"

# 2) 凭据文件：创建并设为 600（dsh 强制要求仅本人可读，644 会拒绝启动）
touch "$DSH_HOME/.credentials.yaml"
chmod 600 "$DSH_HOME/.credentials.yaml"
if [ -n "$DEEPSEEK_API_KEY" ] && ! grep -q "DEEPSEEK_API_KEY" "$DSH_HOME/.credentials.yaml"; then
  printf 'DEEPSEEK_API_KEY: %s\n' "$DEEPSEEK_API_KEY" >> "$DSH_HOME/.credentials.yaml"
fi

# 3) 监听补丁：CLI 禁止 --host 0.0.0.0，改用配置补丁；
#    webServer 配置要求 host 和 port 都提供（缺一不可）
cat > "$DSH_HOME/web-host-patch.yml" <<PATCH
- id: webserver
  config:
    host: 0.0.0.0
    port: ${PORT:-3080}
PATCH

# 4) 启动（有域名时放行浏览器信任）
ARGS="--profile web --patch $DSH_HOME/web-host-patch.yml --port ${PORT:-3080}"
if [ -n "$COOLIFY_FQDN" ]; then
  ARGS="$ARGS --trusted-host $COOLIFY_FQDN"
fi
exec dsh $ARGS
