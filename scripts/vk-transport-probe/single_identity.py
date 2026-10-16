#!/usr/bin/env python3
"""Disposable experiment: two endpoints share one community identity.

Uses explicit conversation message IDs, not Bots Long Poll or getHistory.
This is a short, private test chat, not a production mailbox implementation.
"""

import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

from probe import (
    Bot, MEDIA_USER_AGENT, Network, ProbeError, check_range, document_url, download,
    https_url, make_video, payload_for, private_json, state_dir, upload,
)


def server_config(path):
    try:
        values = dict(line.split("=", 1) for line in path.read_text().splitlines()
                      if line.strip() and not line.lstrip().startswith("#") and "=" in line)
    except OSError:
        raise ProbeError("Нет сохранённой настройки серверного сообщества.") from None
    values = {key.strip(): value.strip() for key, value in values.items()}
    if not all(values.get("VK_SERVER_" + key) for key in ("GROUP", "TOKEN")):
        raise ProbeError("Нужны адрес и ключ серверного сообщества.")
    return values


def check_media_access(bot, chat):
    """Read-only preflight before replacing the working shared token."""
    if chat["group_id"] != bot.group_id:
        raise ProbeError("Сохранённая беседа создана другим сообществом.")
    own = bot.api("groups.getById")
    groups = own.get("groups", []) if isinstance(own, dict) else own
    if not isinstance(groups, list) or [g.get("id") for g in groups] != [chat["group_id"]]:
        raise ProbeError("Ключ выдан другому сообществу; прежняя настройка сохранена.")
    permissions = bot.api("groups.getTokenPermissions")
    names = sorted(p["name"] for p in permissions.get("permissions", []) if "name" in p)
    print("Права ключа: " + ", ".join(names), flush=True)
    if not {"messages", "docs"}.issubset(names):
        raise ProbeError("Нужен ключ с messages и docs. Это не проверка передачи MP4.")
    target = bot.api("docs.getMessagesUploadServer", type="doc", peer_id=chat["peer_id"])
    https_url(target.get("upload_url", ""))
    print("VK выдал адрес загрузки для сохранённой беседы; файл ещё не загружался.", flush=True)


def doctor(args, config):
    try:
        chat = json.loads((state_dir() / "api-chat.json").read_text())
    except (OSError, ValueError):
        raise ProbeError("Нет сохранённой API-беседы; повторно создавать её не требуется.") from None
    bot = Bot(Network(), config, "server", "api.vk.ru")
    check_media_access(bot, chat)
    return 0


class Mailbox:
    def __init__(self, bot, peer, cursor=0):
        self.bot, self.peer, self.cursor = bot, peer, cursor

    def poll(self):
        ids = ",".join(str(i) for i in range(self.cursor + 1, self.cursor + 101))
        result = self.bot.api("messages.getByConversationMessageId",
                              peer_id=self.peer, conversation_message_ids=ids)
        messages = result.get("items", [])
        # Never skip IDs merely because they were requested but do not exist yet.
        for message in messages:
            cmid = message.get("conversation_message_id", 0)
            if message.get("peer_id") != self.peer or not self.cursor < cmid <= self.cursor + 100:
                raise ProbeError("Некорректный номер/чат сообщения в ответе VK.")
        if messages:
            self.cursor = max(m["conversation_message_id"] for m in messages)
        return messages

    def send(self, run, request, kind, role, action, attachment="", **body):
        self.bot.send(self.peer, {**body, "run": run, "request": request,
                                 "kind": kind, "sender_role": role}, action, attachment)

    def receive(self, run, request, kind, role, timeout):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            for message in self.poll():
                payload = payload_for(message, self.bot.group_id, self.peer, run, request, kind)
                if payload is not None and payload.get("sender_role") == role:
                    return payload, message
            time.sleep(1)
        raise ProbeError("Ответ через чтение номеров сообщений не получен вовремя.")


def worker(args, bot):
    saved = json.loads(args.checkpoint.read_text())
    mailbox = Mailbox(bot, saved["peer"], saved["cursor"])
    payload, message = mailbox.receive(saved["run"], saved["request"],
                                       saved["kind"], "server", args.timeout)
    private_json(args.output, {"payload": payload, "message": message,
                               "cursor": mailbox.cursor, "hosts": sorted(bot.network.hosts)})
    return 0


def experiment(args, config):
    run = uuid.uuid4().hex
    folder = state_dir() / "single-identity-runs" / run
    folder.mkdir(parents=True, mode=0o700)
    report = {"scope": "one community identity, two local endpoints; not Android/whitelist",
              "status": "running", "checks": {"android": "not_tested", "whitelist": "not_tested",
              "offline_playback": "not_tested", "large_files": "not_tested"}}
    networks = [Network(), Network()]
    step = "round_trip"
    try:
        chat = json.loads((state_dir() / "api-chat.json").read_text())
        peer = chat["peer_id"]
        server, client = [Mailbox(Bot(net, config, "server", "api.vk.ru"), peer) for net in networks]
        if chat["group_id"] != server.bot.group_id:
            raise ProbeError("Сохранённая беседа создана другим сообществом.")

        def send(box, req, kind, role, **body):
            box.send(run, req, kind, role, uuid.uuid4().hex, **body)

        def receive(box, req, kind, role):
            return box.receive(run, req, kind, role, args.timeout)

        print("Одно сообщество: запрос и ответ через номера сообщений…", flush=True)
        request = uuid.uuid4().hex
        send(client, request, "LIST_RECENT", "client")
        receive(server, request, "LIST_RECENT", "client")
        items = [{"id": "sample", "title": "Synthetic test video"}]
        cache = folder / "server-cache.json"
        private_json(cache, {"items": items, "prepared_count": 1})
        send(server, request, "RESULT", "server", items=items)
        payload, _ = receive(client, request, "RESULT", "server")
        if payload.get("items") != items:
            raise ProbeError("Полученный список не совпал с контрольным.")
        report["checks"][step] = "pass"

        step = "duplicate_request"
        send(client, request, "LIST_RECENT", "client")
        receive(server, request, "LIST_RECENT", "client")
        saved = json.loads(cache.read_text())
        send(server, request, "RESULT", "server", items=saved["items"])
        payload, _ = receive(client, request, "RESULT", "server")
        if payload.get("items") != items or saved["prepared_count"] != 1:
            raise ProbeError("Повтор запроса не вернул сохранённый результат.")
        report["checks"][step] = "pass"

        step = "reply_during_disconnect_new_process"
        checkpoint, output = folder / "checkpoint.json", folder / "received.json"
        # Persist BEFORE the send; child gets no response data from its parent.
        private_json(checkpoint, {"peer": peer, "cursor": client.cursor, "run": run,
                                  "request": request, "kind": "READY"})
        send(server, request, "READY", "server", status="ready")
        process = subprocess.run([sys.executable, str(Path(__file__).resolve()),
                                  "--config", str(args.config.resolve()), "_receive",
                                  "--checkpoint", str(checkpoint), "--output", str(output),
                                  "--timeout", str(args.timeout)], capture_output=True, timeout=args.timeout + 20)
        if process.returncode or not output.exists():
            raise ProbeError("Новый процесс не получил сохранённый ответ из VK.")
        captured = json.loads(output.read_text())
        if captured["payload"].get("status") != "ready":
            raise ProbeError("Новый процесс получил неверный результат.")
        client.cursor = captured["cursor"]
        client.bot.network.hosts.update(captured["hosts"])
        report["checks"][step] = "pass"

        step = "status_after_cursor_reset"
        client.cursor = 0
        status_request = uuid.uuid4().hex
        send(client, status_request, "GET_STATUS", "client", result_for=request)
        receive(server, status_request, "GET_STATUS", "client")
        saved = json.loads(cache.read_text())
        send(server, status_request, "STATUS", "server", items=saved["items"])
        payload, _ = receive(client, status_request, "STATUS", "server")
        if payload.get("items") != items:
            raise ProbeError("Повторный запрос статуса вернул неверный результат.")
        report["checks"][step] = "pass"

        if not args.text_only:
            report["media_user_agent"] = MEDIA_USER_AGENT
            step = "document_permissions"
            permissions = server.bot.api("groups.getTokenPermissions")
            if not any(p.get("name") == "docs" for p in permissions.get("permissions", [])):
                raise ProbeError("У серверного ключа нет права docs; загрузка MP4 не проверена.")
            report["checks"][step] = "pass"
            step = "document_upload"
            print("Проверка MP4-документа и получения независимым клиентом…", flush=True)
            video = folder / "sample.mp4"
            make_video(video)
            attachment, expected = upload(server.bot, peer, video, run)
            report["checks"][step] = "pass"
            step = "document_receive"
            send(server, request, "FILE", "server", attachment=attachment, **expected)
            payload, message = receive(client, request, "FILE", "server")
            # Resolve from the receiver's VK response, not the uploader's URL.
            url = document_url(client.bot, message)
            report["checks"][step] = "pass"
            step = "download_sha256"
            received_metadata = {key: payload.get(key) for key in ("size", "sha256")}
            if received_metadata != expected:
                raise ProbeError("Описание файла не совпало с отправленным.")
            target = folder / "downloaded.mp4"
            download(client.bot.network, url, target, received_metadata)
            report["checks"][step] = "pass"
            report["size_bytes"] = target.stat().st_size
            report["downloaded_file"] = str(target)
            raw = target.read_bytes()
            report["checks"]["range_start"] = check_range(client.bot.network, url, raw, 0)
            report["checks"]["range_offset"] = check_range(client.bot.network, url, raw, 17)
        else:
            report["checks"]["media"] = "not_tested"
        report["status"] = "text_only_pass" if args.text_only else "transport_candidate_on_this_host"
    except ProbeError as error:
        report.update(status="not_confirmed", error=str(error))
        report["checks"][step] = "not_confirmed"
        print(str(error), file=sys.stderr)
    except Exception as error:
        report.update(status="tool_error", error="Ошибка инструмента: " + type(error).__name__)
        report["checks"][step] = "not_confirmed"
        print(report["error"], file=sys.stderr)
    finally:
        report["hosts"] = sorted(set().union(*(net.hosts for net in networks)))
        report_path = state_dir() / "single-identity-report.json"
        private_json(folder / "report.json", report)
        private_json(report_path, report)
        print("Отчёт без секретов: " + str(report_path), flush=True)
        print("Результат: " + report["status"], flush=True)
    return 0 if report["status"] in ("text_only_pass", "transport_candidate_on_this_host") else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=state_dir() / "credentials.env")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("doctor", help="Проверить сообщество, права и адрес загрузки; без сообщений и файлов.")
    run = commands.add_parser("run", help="Тестовые сообщения и маленький MP4 в сохранённой беседе.")
    run.add_argument("--text-only", action="store_true")
    run.add_argument("--timeout", type=int, default=20)
    child = commands.add_parser("_receive")
    child.add_argument("--checkpoint", type=Path, required=True)
    child.add_argument("--output", type=Path, required=True)
    child.add_argument("--timeout", type=int, default=20)
    args = parser.parse_args()
    try:
        config = server_config(args.config)
        if args.command == "doctor":
            return doctor(args, config)
        if args.command == "_receive":
            return worker(args, Bot(Network(), config, "server", "api.vk.ru"))
        return experiment(args, config)
    except ProbeError as error:
        print(str(error), file=sys.stderr)
        return 1
    except Exception as error:
        print("Ошибка инструмента: " + type(error).__name__, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
