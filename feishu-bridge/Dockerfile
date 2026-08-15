# Feishu bot bridge for DSH -- combines node (for dsh) + python (for lark-oapi)
FROM node:22-slim

# Base tools + python for the bridge
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-pip git ca-certificates python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

# Install DSH (headless agent engine)
RUN npm install -g @deepseek-ai/dsh@0.1.0-rc.6

# Install Feishu SDK
RUN pip3 install --break-system-packages lark-oapi

WORKDIR /bridge
COPY bridge.py /bridge/bridge.py

ENV DSH_HOME=/data/dsh \
    TZ=Asia/Shanghai

VOLUME ["/data", "/workspace"]

CMD ["python3", "/bridge/bridge.py"]
