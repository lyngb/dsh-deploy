# DSH (DeepSeek Harness) 云端镜像 —— 与本地一致：全局 npm 包 + 凭据文件机制
FROM node:22-slim

# 基础工具（git 等）
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 安装 DSH（与本地版本一致）
RUN npm install -g @deepseek-ai/dsh@0.1.0-rc.6

# 运行环境
ENV DSH_HOME=/data/dsh \
    PORT=3080 \
    HOME=/root \
    TZ=Asia/Shanghai

WORKDIR /workspace

# 启动脚本：首次运行用环境变量生成凭据文件
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3080
VOLUME ["/data", "/workspace"]

CMD ["/entrypoint.sh"]
