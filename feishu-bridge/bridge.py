#!/usr/bin/env python3
"""
Feishu (Lark) bot bridge for DSH.

Turns Feishu messages into `dsh --profile headless` tasks and replies with the result.
Runs with a WebSocket long connection -- no public IP needed.

Env:
  FEISHU_APP_ID / FEISHU_APP_SECRET : Feishu custom app credentials (required)
  DEEPSEEK_API_KEY                  : DeepSeek API key (written to $DSH_HOME/.credentials.yaml on boot)
  DSH_HOME                          : default /data/dsh
  BRIDGE_WORKDIR                    : workspace the headless agent operates in (default /workspace)
  BRIDGE_CONTEXT_FILE               : conversation memory file (default $DSH_HOME/feishu-context.md)
  BRIDGE_TIMEOUT                    : seconds to wait for a headless answer (default 240)
  ALLOWED_OPEN_IDS                  : optional comma-separated open_id allowlist
"""
import asyncio
import json
import os
import re
import subprocess
import sys
import threading
import time

import lark_oapi as lark
from lark_oapi.core.const import FEISHU_DOMAIN
from lark_oapi.api.im.v1 import ReplyMessageRequest, ReplyMessageRequestBody

APP_ID = os.environ.get("FEISHU_APP_ID", "")
APP_SECRET = os.environ.get("FEISHU_APP_SECRET", "")
DSH_HOME = os.environ.get("DSH_HOME", "/data/dsh")
WORKDIR = os.environ.get("BRIDGE_WORKDIR", "/workspace")
CTX_FILE = os.environ.get("BRIDGE_CONTEXT_FILE", os.path.join(DSH_HOME, "feishu-context.md"))
TIMEOUT = int(os.environ.get("BRIDGE_TIMEOUT", "240"))
ALLOWED = [s.strip() for s in os.environ.get("ALLOWED_OPEN_IDS", "").split(",") if s.strip()]
MAX_CTX_CHARS = 8000
MAX_REPLY = 3500

# ---- red-line guard: headless mode has NO confirmation step, so refuse these ----
RED_LINES = [
    r"删除.{0,6}(文件|目录|文件夹)|rm\s+-rf|Remove-Item\s+-Recurse|del\s+/[sq]",
    r"\.env|密钥|token|密码|secret|api[_-]?key",
    r"git\s+push|git\s+rebase|git\s+reset\s+--hard|强制推送",
    r"数据库.{0,4}(删除|清空|drop)|drop\s+table|schema\s+.*(变更|迁移)|数据迁移",
    r"npm\s+(install|i)\s+-g|pip\s+install.{0,20}(-g|--user)|chmod\s+777",
    r"发布|部署到生产|npm\s+publish|上线",
]


def check_red_line(text: str):
    for pat in RED_LINES:
        if re.search(pat, text, re.I):
            return pat
    return None


def ensure_credentials():
    os.makedirs(os.path.join(DSH_HOME, "profiles"), exist_ok=True)
    path = os.path.join(DSH_HOME, ".credentials.yaml")
    if not os.path.exists(path):
        open(path, "w").close()
    key = os.environ.get("DEEPSEEK_API_KEY", "")
    if key and "DEEPSEEK_API_KEY" not in open(path, encoding="utf-8").read():
        with open(path, "a", encoding="utf-8") as f:
            f.write("DEEPSEEK_API_KEY: %s\n" % key)
    os.chmod(path, 0o600)


def load_context():
    if not os.path.exists(CTX_FILE):
        return ""
    try:
        txt = open(CTX_FILE, encoding="utf-8").read()
    except Exception:
        return ""
    return txt[-MAX_CTX_CHARS:]


def append_context(user, ai):
    try:
        with open(CTX_FILE, "a", encoding="utf-8") as f:
            f.write("用户: %s\nAI: %s\n---\n" % (user[:500], ai[:1500]))
    except Exception:
        pass


def run_headless(prompt: str) -> str:
    os.makedirs(WORKDIR, exist_ok=True)
    env = dict(os.environ)
    env["DSH_HOME"] = DSH_HOME
    try:
        r = subprocess.run(
            ["dsh", "--profile", "headless", prompt],
            cwd=WORKDIR, env=env, capture_output=True, text=True,
            timeout=TIMEOUT,
        )
        out = r.stdout or ""
        if r.returncode != 0 and r.stderr:
            out += "\n" + r.stderr
        return out.strip() or "(无输出)"
    except subprocess.TimeoutExpired:
        return "(任务超时：超过 %d 秒，请简化问题)" % TIMEOUT
    except FileNotFoundError:
        return "(错误：容器内找不到 dsh 命令)"
    except Exception as e:
        return "(错误：%s)" % str(e)[:200]


def reply(message_id, text):
    try:
        body = ReplyMessageRequestBody.builder() \
            .content(json.dumps({"text": text})) \
            .msg_type("text") \
            .build()
        req = ReplyMessageRequest.builder() \
            .message_id(message_id) \
            .request_body(body) \
            .build()
        resp = client.im.v1.message.reply(req)
        if not resp.success():
            print("reply failed: code=%s msg=%s" % (resp.code, resp.msg), flush=True)
    except Exception as e:
        print("reply error:", e, flush=True)


def process_and_reply(message_id, user_text, prompt):
    answer = run_headless(prompt)
    append_context(user_text, answer)
    reply(message_id, answer[:MAX_REPLY])


def on_message(data):
    try:
        event = data.event
        msg = event.message
        if msg.message_type != "text":
            reply(msg.message_id, "暂只支持文字消息。")
            return
        content = json.loads(msg.content or "{}").get("text", "")
        sender = event.sender.sender_id.open_id
        if ALLOWED and sender not in ALLOWED:
            return
        if not content.strip():
            return

        hit = check_red_line(content)
        if hit:
            reply(msg.message_id, "⚠️ 这条消息涉及敏感操作（删除/密钥/git/数据库/发布等），无头模式无法确认，已拒绝执行。请回到电脑上操作。")
            return

        ctx = load_context()
        prompt = ("以下是之前的对话记录（仅作背景参考）：\n%s\n\n" % ctx) if ctx else ""
        prompt += "用户（飞书）说：%s\n请直接回答，用中文。" % content

        threading.Thread(target=process_and_reply, args=(msg.message_id, content, prompt), daemon=True).start()
    except Exception as e:
        print("handler error:", e, flush=True)


client = None


def main():
    global client
    if not APP_ID or not APP_SECRET:
        print("FEISHU_APP_ID / FEISHU_APP_SECRET 未配置，退出。", flush=True)
        sys.exit(1)
    ensure_credentials()

    client = lark.Client.builder() \
        .app_id(APP_ID) \
        .app_secret(APP_SECRET) \
        .domain(FEISHU_DOMAIN) \
        .log_level(lark.LogLevel.INFO) \
        .build()

    handler = lark.EventDispatcherHandler.builder("", "") \
        .register_p2_im_message_receive_v1(on_message) \
        .build()

    ws_client = lark.ws.Client(APP_ID, APP_SECRET, domain=FEISHU_DOMAIN, event_handler=handler, log_level=lark.LogLevel.INFO)

    def run_ws():
        import lark_oapi.ws.client as _lark_ws_client
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        _lark_ws_client.loop = loop
        try:
            while True:
                try:
                    ws_client.start()
                except Exception as e:
                    print("websocket error:", e, flush=True)
                time.sleep(5)
        finally:
            try:
                asyncio.set_event_loop(None)
                loop.close()
            except Exception:
                pass

    threading.Thread(target=run_ws, daemon=True).start()
    print("feishu bridge started (websocket long connection)", flush=True)
    while True:
        time.sleep(3600)


if __name__ == "__main__":
    main()
