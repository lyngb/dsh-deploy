# dsh-deploy

DeepSeek Harness (DSH) 云端部署文件。

- `Dockerfile` — Node 22 基础镜像 + 官方 npm 包 `@deepseek-ai/dsh`
- `entrypoint.sh` — 启动脚本：用环境变量生成凭据文件（`.credentials.yaml`）
- `docker-compose.yml` — 本地试跑用

## 环境变量

| 变量 | 说明 |
| --- | --- |
| `DEEPSEEK_API_KEY` | DeepSeek API 密钥（必填） |
| `PORT` | 监听端口，默认 3080 |
| `DSH_HOME` | 数据目录，默认 `/data/dsh` |

## 持久化

- `/data` — DSH 数据（profiles / 凭据 / 会话）
- `/workspace` — 工作区
