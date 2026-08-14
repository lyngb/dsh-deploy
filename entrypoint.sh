#!/bin/sh
set -e

# 1) 确保 DSH_HOME 存在
mkdir -p "$DSH_HOME/profiles"

# 2) 凭据文件：不存在则创建
touch "$DSH_HOME/.credentials.yaml"
if [ -n "$DEEPSEEK_API_KEY" ] && ! grep -q "DEEPSEEK_API_KEY" "$DSH_HOME/.credentials.yaml"; then
  printf 'DEEPSEEK_API_KEY: %s\n' "$DEEPSEEK_API_KEY" >> "$DSH_HOME/.credentials.yaml"
fi

# 3) 监听补丁（绕过 CLI 的 0.0.0.0 限制）
cat > "$DSH_HOME/web-host-patch.yml" <<'PATCH'
- id: webserver
  config:
    host: 0.0.0.0
PATCH

echo "=== DSH_HOME=$DSH_HOME PORT=$PORT ==="
echo "=== patch file ==="
cat "$DSH_HOME/web-host-patch.yml"

# 4) 诊断模式：循环重启，把真实报错打到容器日志
echo "=== starting dsh (diagnostic loop) ==="
while true; do
  dsh --profile web --patch "$DSH_HOME/web-host-patch.yml" --port "${PORT:-3080}" 2>&1 || true
  echo "=== dsh exited; restarting in 10s ==="
  sleep 10
done
