#!/usr/bin/env python3
"""Private responder for the disposable Android VK transport probe.

Run this on the trusted LocalTube server (or another trusted host with the
community key). It polls the existing VK conversation, answers only the
LT-ANDROID-PROBE/1 envelope, and keeps the request/result journal outside the
repository. The token is read from credentials.env and never printed.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import time
import uuid

from single_identity import Mailbox, server_config
from probe import Bot, Network, ProbeError, private_json, state_dir, upload


ANDROID_PREFIX = "LT-ANDROID-PROBE/1 "


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=state_dir() / "credentials.env")
    parser.add_argument("--chat", type=Path, default=state_dir() / "api-chat.json")
    parser.add_argument("--video", type=Path, help="small MP4; defaults to the latest private probe sample")
    parser.add_argument("--state", type=Path, default=state_dir() / "android-server.json")
    parser.add_argument("--timeout", type=int, default=0, help="stop after this many seconds; 0 means run until Ctrl+C")
    return parser.parse_args()


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


def choose_video(path: Path | None) -> Path:
    if path:
        if not path.is_file():
            raise ProbeError("Переданный MP4 не найден.")
        return path
    samples = sorted((state_dir() / "single-identity-runs").glob("*/sample.mp4"), key=lambda p: p.stat().st_mtime)
    if not samples:
        raise ProbeError("Нет приватного sample.mp4; передайте --video с небольшим MP4.")
    return samples[-1]


def payload_from(message: dict, group_id: int, peer: int):
    if message.get("peer_id") != peer or message.get("from_id") != -group_id:
        return None
    text = message.get("text", "")
    if not isinstance(text, str) or not text.startswith(ANDROID_PREFIX):
        return None
    try:
        payload = json.loads(text[len(ANDROID_PREFIX):])
    except ValueError:
        return None
    if not isinstance(payload, dict) or payload.get("role") != "client":
        return None
    if not all(isinstance(payload.get(key), str) and re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", payload[key]) for key in ("request", "run")):
        return None
    return payload


def public_result(request: dict, expected: dict, *, duplicate: bool = False) -> dict:
    return {
        "protocol": "LT-ANDROID-PROBE/1",
        "run": request["run"],
        "request": request["request"],
        "kind": "RESULT",
        "role": "server",
        "status": "ready",
        "prepared_count": 1,
        "duplicate": duplicate,
        "size": expected["size"],
        "sha256": expected["sha256"],
        "mime": "video/mp4",
    }


def result_for(request: dict, journal: dict, expected: dict):
    """Prepare a replayable response; callers must persist it before sending."""
    command = request.get("command")
    if command not in ("LIST_RECENT", "GET_STATUS"):
        return None
    key = request["request"]
    signature = {k: request.get(k) for k in ("command", "run", "result_for")}
    previous = journal.get(key)
    if previous:
        if previous["signature"] != signature:
            return {**public_result(request, expected), "status": "conflict"}
        return {**previous["result"], "duplicate": True}
    if command == "GET_STATUS":
        target = request.get("result_for")
        original = journal.get(target) if isinstance(target, str) else None
        if original and original["signature"]["command"] == "LIST_RECENT":
            result = {**original["result"], "run": request["run"], "request": key}
        else:
            result = {**public_result(request, expected), "status": "unknown"}
    else:
        result = public_result(request, expected)
        result["items"] = [{"id": "sample", "title": "Synthetic test video"}]
    journal[key] = {"signature": signature, "result": result}
    return result


def send_result(bot, peer, result, attachment):
    # A new response attempt must not be suppressed by VK's random_id cache
    # after a fresh duplicate command. Logical idempotency lives in the journal.
    params = {"peer_ids": peer, "random_id": uuid.uuid4().int & 0x7FFFFFFF or 1,
              "message": ANDROID_PREFIX + json.dumps(result, separators=(",", ":"))}
    if result.get("status") == "ready":
        params["attachment"] = attachment
    ack = bot.api("messages.send", **params)
    if not isinstance(ack, list) or len(ack) != 1 or ack[0].get("error") or not ack[0].get("conversation_message_id"):
        raise ProbeError("Ответчик не получил подтверждение отправки VK.")
    return ack[0]["conversation_message_id"]


def main() -> int:
    args = parse_args()
    config = server_config(args.config)
    chat = load_json(args.chat, {})
    if not isinstance(chat, dict) or not isinstance(chat.get("peer_id"), int):
        raise ProbeError("Нет сохранённой API-беседы.")
    peer = chat["peer_id"]
    video = choose_video(args.video)
    bot = Bot(Network(), config, "server", "api.vk.ru")
    if int(chat.get("group_id", 0)) != bot.group_id:
        raise ProbeError("Сохранённая беседа создана другим сообществом.")
    run_state = load_json(args.state, {})
    if not isinstance(run_state, dict):
        run_state = {}
    run_state.setdefault("cursor", 0)
    run_state.setdefault("requests", {})
    attachment, expected = upload(bot, peer, video, "android")
    run_state["attachment"] = attachment
    run_state["expected"] = expected
    private_json(args.state, run_state)
    print(f"Android VK responder active for peer {peer}; Ctrl+C to stop.", flush=True)

    started = time.monotonic()
    mailbox = Mailbox(bot, peer, int(run_state["cursor"]))
    try:
        while not args.timeout or time.monotonic() - started < args.timeout:
            for message in mailbox.poll():
                request = payload_from(message, bot.group_id, peer)
                if request is None:
                    continue
                request_id = request["request"]
                command = request.get("command")
                result = result_for(request, run_state["requests"], expected)
                if result is None:
                    continue
                private_json(args.state, run_state)
                # Delayed recovery is a deliberate user-visible pause.
                delay = request.get("delay_seconds", 0)
                if isinstance(delay, int) and 0 < delay <= 120:
                    time.sleep(delay)
                send_result(bot, peer, result, attachment)
                print(f"replied command={command} request={request_id[:8]}", flush=True)
            run_state["cursor"] = mailbox.cursor
            private_json(args.state, run_state)
            time.sleep(2)
    except KeyboardInterrupt:
        print("Android VK responder stopped.", flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ProbeError as error:
        raise SystemExit(str(error))
