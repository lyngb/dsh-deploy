# DSH (DeepSeek Harness) cloud image -- same as local: global npm package + credentials file
FROM node:22-slim

# Base tools: git, TLS certs, and the toolchain node-pty needs to build from source
# (python3 + make + g++ -- node:22-slim has none of these by default)
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

# Install DSH (same version as local)
RUN npm install -g @deepseek-ai/dsh@0.1.0-rc.6

# Runtime env
ENV DSH_HOME=/data/dsh \
    PORT=3080 \
    HOME=/root \
    TZ=Asia/Shanghai

WORKDIR /workspace

# Entrypoint: generate credentials file from env on first start
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3080
VOLUME ["/data", "/workspace"]

CMD ["/entrypoint.sh"]
