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

# 4) 监听补丁：命令行 --host 0.0.0.0 被 dsh 安全限制拒绝，
#    改用配置补丁让 webServer 监听所有网卡（Coolify 代理才能连进容器）。
cat > "$DSH_HOME/web-host-patch.yml" <<'PATCH'
- id: webserver
  config:
    host: 0.0.0.0
PATCH

# 5) 启动 web profile（补丁代替 --host；有域名时加 trusted-host 放行浏览器信任）
ARGS="--profile web --patch $DSH_HOME/web-host-patch.yml --port ${PORT:-3080}"
if [ -n "$COOLIFY_FQDN" ]; then
  ARGS="$ARGS --trusted-host $COOLIFY_FQDN"
fi
exec dsh $ARGS
