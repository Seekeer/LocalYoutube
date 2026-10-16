#!/usr/bin/env python3
"""Disposable VK community-to-community experiment. Python standard library only."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


PREFIX = "LT-PROBE/1 "
MAX_VIDEO = 10 * 1024 * 1024
API_HOSTS = ("api.vk.ru", "api.vk.com")
# On this host VK serves the document HTML page unless the request identifies
# an Android client. This emulates the target platform; it is not an Android test.
MEDIA_USER_AGENT = "LocalTubeProbe/1.0 (Android)"


class ProbeError(Exception):
    """Only static messages and non-secret error codes may cross this boundary."""


def state_dir() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "localtube-vk-probe"


def private_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = path.with_name(path.name + ".partial")
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as out:
        json.dump(value, out, ensure_ascii=False, indent=2)
        out.write("\n")
    os.chmod(temporary, 0o600)
    temporary.replace(path)


def read_config(path: Path) -> dict[str, str]:
    try:
        lines = path.read_text().splitlines()
    except OSError:
        raise ProbeError("Нет файла настройки. Сначала запустите setup.sh.") from None
    config = {}
    for line in lines:
        if line.strip() and not line.lstrip().startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            config[key.strip()] = value.strip()
    for role in ("SERVER", "CLIENT"):
        if not config.get(f"VK_{role}_GROUP") or not config.get(f"VK_{role}_TOKEN"):
            raise ProbeError("Настройка не завершена: нужны адрес и ключ каждого сообщества.")
    if config["VK_SERVER_TOKEN"] == config["VK_CLIENT_TOKEN"]:
        raise ProbeError("Для этой пробы нужны два разных ключа двух разных сообществ.")
    return config


def https_url(url: str) -> str:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise ProbeError("VK вернул неподдерживаемый адрес: требуется HTTPS без учётных данных в URL.")
    return url


class Redirects(urllib.request.HTTPRedirectHandler):
    def __init__(self, hosts: set[str]):
        self.hosts = hosts

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        https_url(newurl)
        self.hosts.add(urllib.parse.urlsplit(newurl).hostname)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class Network:
    def __init__(self):
        self.hosts: set[str] = set()
        self.opener = urllib.request.build_opener(Redirects(self.hosts))
        self.last_api = 0.0

    def open(self, url: str, data: bytes | None = None, headers=None, timeout=35):
        https_url(url)
        self.hosts.add(urllib.parse.urlsplit(url).hostname)
        request = urllib.request.Request(url, data=data, headers=headers or {})
        try:
            return self.opener.open(request, timeout=timeout)
        except urllib.error.HTTPError as error:
            raise ProbeError(f"HTTP {error.code}; адрес и тело ответа скрыты.") from None
        except (OSError, urllib.error.URLError, ValueError):
            raise ProbeError("Сетевая ошибка или таймаут; адрес и параметры скрыты.") from None

    def json(self, url: str, data: bytes | None = None, headers=None, timeout=35):
        with self.open(url, data, headers, timeout) as response:
            raw = response.read(2 * 1024 * 1024 + 1)
        if len(raw) > 2 * 1024 * 1024:
            raise ProbeError("Слишком большой JSON-ответ VK.")
        try:
            return json.loads(raw)
        except (ValueError, UnicodeError):
            raise ProbeError("Вместо JSON получен другой ответ; его содержимое скрыто.") from None


class Bot:
    def __init__(self, network: Network, config: dict, role: str, api_host: str):
        self.network, self.role = network, role
        self.token = config[f"VK_{role.upper()}_TOKEN"]
        self.version = config.get("VK_API_VERSION", "5.199")
        self.base = f"https://{api_host}/method/"
        self.group_id = self.resolve_group(config[f"VK_{role.upper()}_GROUP"])
        self.session: dict = {}
        self.observed: dict[str, int] = {}
        self.gaps: list[int] = []

    def api(self, method: str, **params):
        for attempt in range(3):
            time.sleep(max(0, 0.36 - (time.monotonic() - self.network.last_api)))
            self.network.last_api = time.monotonic()
            data = urllib.parse.urlencode({**params, "v": self.version, "access_token": self.token}).encode()
            result = self.network.json(self.base + method, data)
            if not isinstance(result, dict):
                raise ProbeError(f"{self.role}: неверная форма ответа {method}.")
            if "error" not in result:
                if "response" not in result:
                    raise ProbeError(f"{self.role}: нет response у {method}.")
                return result["response"]
            code = result["error"].get("error_code", 0)
            if code == 6 and attempt < 2:
                time.sleep(attempt + 1)
                continue
            # error_msg and request_params may contain credentials or signed URLs.
            hints = {5: "ключ недействителен", 7: "проверьте права ключа", 15: "нет доступа", 27: "проверьте ключ сообщества", 100: "проверьте настройки и параметры"}
            raise ProbeError(f"{self.role}: {method}, VK code={int(code)}; {hints.get(code, 'нужна диагностика метода')}.")

    def resolve_group(self, value: str) -> int:
        value = value.strip()
        if "/" in value:
            parsed = urllib.parse.urlsplit(value if "://" in value else "https://" + value)
            if parsed.hostname not in ("vk.com", "vk.ru", "www.vk.com", "www.vk.ru", "m.vk.com", "m.vk.ru"):
                raise ProbeError("Укажите адрес сообщества на vk.com/vk.ru или его числовой ID.")
            value = parsed.path.strip("/")
        match = re.fullmatch(r"(?:club|public|event)?([1-9][0-9]*)", value)
        if match:
            return int(match.group(1))
        if not re.fullmatch(r"[A-Za-z0-9_.]+", value):
            raise ProbeError("Не удалось распознать адрес сообщества.")
        resolved = self.api("utils.resolveScreenName", screen_name=value)
        if not isinstance(resolved, dict) or resolved.get("type") not in ("group", "event"):
            raise ProbeError("Этот адрес не указывает на сообщество VK.")
        return int(resolved["object_id"])

    def connect(self):
        self.session = self.api("groups.getLongPollServer", group_id=self.group_id)
        https_url(self.session["server"])
        return self.session

    def poll(self, wait: int = 2) -> list[dict]:
        if not self.session:
            self.connect()
        query = urllib.parse.urlencode({"act": "a_check", "key": self.session["key"], "ts": self.session["ts"], "wait": wait})
        separator = "&" if "?" in self.session["server"] else "?"
        result = self.network.json(self.session["server"] + separator + query, timeout=wait + 10)
        if not isinstance(result, dict):
            raise ProbeError("Неверный ответ Bots Long Poll.")
        failure = result.get("failed")
        if failure:
            self.gaps.append(int(failure))
            if failure == 1 and "ts" in result:
                self.session["ts"] = result["ts"]
            elif failure in (2, 3):
                self.connect()
            else:
                raise ProbeError("Bots Long Poll вернул неизвестную ошибку восстановления.")
            return []
        if "ts" not in result or not isinstance(result.get("updates", []), list):
            raise ProbeError("Нет курсора или списка событий Bots Long Poll.")
        self.session["ts"] = result["ts"]
        messages = []
        for event in result.get("updates", []):
            kind = str(event.get("type", "unknown"))
            self.observed[kind] = self.observed.get(kind, 0) + 1
            if kind == "message_new":
                obj = event.get("object", {})
                message = obj.get("message", obj)
                if isinstance(message, dict):
                    messages.append(message)
        return messages

    def send(self, peer: int, payload: dict, action: str, attachment: str = ""):
        random_id = int.from_bytes(hashlib.sha256(action.encode()).digest()[:4], "big") & 0x7FFFFFFF or 1
        params = {"peer_id": peer, "random_id": random_id, "message": PREFIX + json.dumps(payload, separators=(",", ":"))}
        if attachment:
            params["attachment"] = attachment
        return self.api("messages.send", **params)


def payload_for(message: dict, sender: int, peer: int, run: str, request: str, kind: str):
    if message.get("from_id") != -sender or message.get("peer_id") != peer:
        return None
    text = message.get("text", "")
    if not isinstance(text, str) or not text.startswith(PREFIX):
        return None
    try:
        payload = json.loads(text[len(PREFIX):])
    except ValueError:
        return None
    if not isinstance(payload, dict):
        return None
    if (payload.get("run"), payload.get("request"), payload.get("kind")) != (run, request, kind):
        return None
    return payload


def receive(bot: Bot, sender: int, peer: int, run: str, request: str, kind: str, timeout: int):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        for message in bot.poll(wait=min(2, max(1, int(deadline - time.monotonic())))):
            payload = payload_for(message, sender, peer, run, request, kind)
            if payload is not None:
                return payload, message
    raise ProbeError(f"{bot.role}: событие {kind} от второго бота не получено за {timeout} с. Проверьте доступ к переписке и доставку bot-to-bot.")


def discover(bots: dict[str, Bot], timeout: int) -> dict[str, int]:
    marker = "LT-PROBE " + uuid.uuid4().hex[:10]
    print("\nНапишите ОДНО сообщение в тестовую беседу с обоими ботами:", flush=True)
    print("\n    " + marker + "\n", flush=True)
    print("У обоих ботов должен быть полный доступ к переписке. Ожидаю сообщение…", flush=True)
    peers, humans = {}, {}
    deadline = time.monotonic() + timeout
    while len(peers) < 2 and time.monotonic() < deadline:
        for role, bot in bots.items():
            for message in bot.poll(wait=1):
                if message.get("text", "").strip() == marker and message.get("from_id", 0) > 0 and message.get("peer_id", 0) > 2_000_000_000:
                    peers[role] = int(message["peer_id"])
                    humans[role] = message["from_id"]
    if len(peers) != 2 or len(set(humans.values())) != 1:
        raise ProbeError("Не оба бота увидели контрольную фразу одного пользователя в беседе. Проверьте настройки сообщений и доступ к переписке.")
    return peers


def make_video(path: Path):
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise ProbeError("Для тестового MP4 нужен ffmpeg либо параметр --video с небольшим существующим MP4.")
    result = subprocess.run([ffmpeg, "-v", "error", "-f", "lavfi", "-i", "color=c=blue:s=160x90:d=2", "-an", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-y", str(path)], capture_output=True)
    if result.returncode:
        raise ProbeError("Не удалось создать тестовый MP4; передайте свой файл через --video.")


def upload(bot: Bot, peer: int, video: Path, run: str):
    data = video.read_bytes()
    target = bot.api("docs.getMessagesUploadServer", type="doc", peer_id=peer)
    boundary = "LocalTubeProbe" + uuid.uuid4().hex
    multipart = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="sample.mp4"\r\nContent-Type: video/mp4\r\n\r\n').encode() + data + f"\r\n--{boundary}--\r\n".encode()
    result = bot.network.json(target["upload_url"], multipart, {"Content-Type": "multipart/form-data; boundary=" + boundary})
    if not isinstance(result, dict) or not isinstance(result.get("file"), str):
        raise ProbeError("Upload не вернул дескриптор файла; ответ скрыт.")
    saved = bot.api("docs.save", file=result["file"], title="LocalTube probe " + run[:8])
    if isinstance(saved, list):
        document = saved[0] if saved else {}
    else:
        document = saved.get("doc", {}) if isinstance(saved, dict) else {}
    if not all(key in document for key in ("owner_id", "id")):
        raise ProbeError("docs.save не вернул документ.")
    attachment = f'doc{int(document["owner_id"])}_{int(document["id"])}'
    if document.get("access_key"):
        attachment += "_" + document["access_key"]
    return attachment, {"size": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def document_url(client: Bot, message: dict) -> str:
    for attachment in message.get("attachments", []):
        if attachment.get("type") != "doc":
            continue
        document = attachment.get("doc", {})
        if document.get("url"):
            return https_url(document["url"])
        identifier = f'{int(document["owner_id"])}_{int(document["id"])}'
        if document.get("access_key"):
            identifier += "_" + document["access_key"]
        result = client.api("docs.getById", docs=identifier)
        if isinstance(result, list) and result and result[0].get("url"):
            return https_url(result[0]["url"])
    raise ProbeError("Получатель не получил доступный URL документа. Серверный URL вместо него не подставляется.")


def download(network: Network, url: str, output: Path, expected: dict):
    size = expected.get("size")
    digest = expected.get("sha256")
    if not isinstance(size, int) or not 0 < size <= MAX_VIDEO or not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ProbeError("Неверный размер или SHA-256 в ответе второго бота.")
    temporary = output.with_suffix(".partial")
    total, checksum = 0, hashlib.sha256()
    try:
        with network.open(url, headers={"User-Agent": MEDIA_USER_AGENT}) as response, temporary.open("wb") as target:
            if response.status != 200:
                raise ProbeError("Полное скачивание не вернуло HTTP 200.")
            while chunk := response.read(65536):
                total += len(chunk)
                if total > size:
                    raise ProbeError("Получено больше данных, чем заявлено; файл отклонён.")
                checksum.update(chunk)
                target.write(chunk)
        if total != size or checksum.hexdigest() != digest:
            raise ProbeError("Размер или SHA-256 скачанного файла не совпал.")
        temporary.replace(output)
    finally:
        temporary.unlink(missing_ok=True)


def check_range(network: Network, url: str, expected: bytes, start: int):
    end = min(start + 31, len(expected) - 1)
    try:
        with network.open(url, headers={"Range": f"bytes={start}-{end}", "User-Agent": MEDIA_USER_AGENT}) as response:
            raw = response.read(end - start + 2)
            correct = response.status == 206 and response.headers.get("Content-Range") == f"bytes {start}-{end}/{len(expected)}" and raw == expected[start:end + 1]
        return "pass" if correct else "not_confirmed"
    except ProbeError:
        return "not_confirmed"


def restarted_receive(config_path: Path, folder: Path, client: Bot, sender: int, peer: int, run: str, request: str, kind: str, timeout: int, api_host: str):
    checkpoint = folder / "client-checkpoint.json"
    result = folder / "client-result.json"
    result.unlink(missing_ok=True)
    # Both contain signed Long Poll keys / attachment URLs and stay private.
    private_json(checkpoint, {"session": client.session, "sender": sender, "peer": peer, "run": run, "request": request, "kind": kind})
    command = [sys.executable, str(Path(__file__).resolve()), "--config", str(config_path.resolve()), "--api-host", api_host, "_receive", "--checkpoint", str(checkpoint.resolve()), "--output", str(result.resolve()), "--timeout", str(timeout)]
    try:
        process = subprocess.run(command, capture_output=True, timeout=timeout + 20)
    except subprocess.TimeoutExpired:
        raise ProbeError("Новый процесс клиента не завершил приём вовремя.") from None
    if process.returncode or not result.exists():
        detail = json.loads(result.read_text()).get("error", "") if result.exists() else ""
        # Worker writes only sanitized ProbeError text, never raw exceptions.
        raise ProbeError("Ответ после перезапуска не получен. " + detail)
    captured = json.loads(result.read_text())
    client.session = captured["session"]
    client.gaps.extend(captured["gaps"])
    client.network.hosts.update(captured["hosts"])
    return captured["payload"], captured["message"]


def worker(args, bot: Bot):
    snapshot = json.loads(args.checkpoint.read_text())
    bot.session = snapshot["session"]
    try:
        payload, message = receive(bot, snapshot["sender"], snapshot["peer"], snapshot["run"], snapshot["request"], snapshot["kind"], args.timeout)
        private_json(args.output, {"payload": payload, "message": message, "session": bot.session, "gaps": bot.gaps, "hosts": sorted(bot.network.hosts)})
        return 0
    except ProbeError as error:
        private_json(args.output, {"error": str(error)})
        return 1


def experiment(args, bots: dict[str, Bot], network: Network):
    folder = state_dir() / "runs" / uuid.uuid4().hex
    folder.mkdir(parents=True, mode=0o700)
    report_path = state_dir() / "report.json"
    server, client = bots["server"], bots["client"]
    report = {"scope": "two communities on this computer; Android/whitelist not tested", "status": "running", "checks": {"android_whitelist": "not_tested", "offline_playback_on_phone": "manual_pending"}}
    step = "discovery"
    try:
        for bot in bots.values():
            bot.connect()
        peers = discover(bots, args.discovery_timeout)
        report["checks"][step] = "pass"
        run, request = uuid.uuid4().hex, uuid.uuid4().hex
        command = {"run": run, "request": request, "kind": "LIST_RECENT"}
        answer = {"run": run, "request": request, "kind": "RESULT", "items": [{"id": "sample", "title": "Synthetic test video"}]}
        step = "round_trip"
        print("Проверка запроса и ответа…", flush=True)
        client.send(peers["client"], command, run + "-request")
        receive(server, client.group_id, peers["server"], run, request, "LIST_RECENT", args.timeout)
        # A persistent result cache belongs to this test, not to VK.
        cache = folder / "server-cache.json"
        private_json(cache, {request: answer, "prepared_count": 1})
        server.send(peers["server"], answer, run + "-response")
        received, _ = receive(client, server.group_id, peers["client"], run, request, "RESULT", args.timeout)
        if received != answer:
            raise ProbeError("Содержимое ответа не совпало с контрольным списком.")
        report["checks"][step] = "pass"

        step = "duplicate_request"
        client.send(peers["client"], command, run + "-duplicate")
        receive(server, client.group_id, peers["server"], run, request, "LIST_RECENT", args.timeout)
        saved = json.loads(cache.read_text())
        server.send(peers["server"], saved[request], run + "-duplicate-response")
        receive(client, server.group_id, peers["client"], run, request, "RESULT", args.timeout)
        report["checks"][step] = "pass"
        report["prepared_count"] = saved["prepared_count"]

        step = "reply_during_disconnect"
        print("Проверка ответа во время отключения и нового процесса клиента…", flush=True)
        # No client polling occurs between this send and the worker startup.
        ready = {"run": run, "request": request, "kind": "READY", "status": "ready"}
        server.send(peers["server"], ready, run + "-offline-ready")
        try:
            restarted_receive(args.config, folder, client, server.group_id, peers["client"], run, request, "READY", args.timeout, args.api_host)
            report["checks"][step] = "pass"
        except ProbeError as error:
            # Losing this event need not rule out a transport with status replay.
            report["checks"][step] = "not_confirmed"
            report["restart_warning"] = str(error)
            print("Прямое получение старого ответа не подтверждено; проверяю повторный запрос статуса…", flush=True)

        step = "status_after_cursor_reset"
        print("Проверка сохранённого результата после потери курсора…", flush=True)
        client.connect()  # Old events may be lost; ask the server anew.
        client.send(peers["client"], {"run": run, "request": request, "kind": "GET_STATUS"}, run + "-status")
        receive(server, client.group_id, peers["server"], run, request, "GET_STATUS", args.timeout)
        saved = json.loads(cache.read_text())  # Reload from disk, not an in-memory result.
        server.send(peers["server"], saved[request], run + "-status-response")
        receive(client, server.group_id, peers["client"], run, request, "RESULT", args.timeout)
        report["checks"][step] = "pass"

        if not args.text_only:
            step = "document_upload"
            print("Проверка MP4-документа и скачивания получателем…", flush=True)
            video = args.video or folder / "sample.mp4"
            if not args.video:
                make_video(video)
            if not video.is_file() or video.suffix.lower() != ".mp4" or not 0 < video.stat().st_size <= MAX_VIDEO:
                raise ProbeError("Укажите MP4 размером от 1 байта до 10 МиБ.")
            with video.open("rb") as source:
                if source.read(12)[4:8] != b"ftyp":
                    raise ProbeError("У файла не обнаружен заголовок MP4 (ftyp). Выберите настоящий MP4.")
            attachment, expected = upload(server, peers["server"], video, run)
            report["checks"][step] = "pass"
            step = "document_receive"
            server.send(peers["server"], {"run": run, "request": request, "kind": "FILE", **expected}, run + "-file", attachment)
            payload, message = receive(client, server.group_id, peers["client"], run, request, "FILE", args.timeout)
            url = document_url(client, message)
            report["checks"][step] = "pass"
            step = "download_sha256"
            if {key: payload.get(key) for key in expected} != expected:
                raise ProbeError("Описание файла, полученное клиентом, не совпало.")
            output = folder / "downloaded.mp4"
            download(network, url, output, expected)
            report["checks"][step] = "pass"
            report["downloaded_file"] = str(output)
            report["size_bytes"] = output.stat().st_size
            raw = output.read_bytes()
            report["checks"]["range_start"] = check_range(network, url, raw, 0)
            report["checks"]["range_offset"] = check_range(network, url, raw, min(17, len(raw) - 1))
        else:
            report["checks"]["media"] = "not_tested"
        report["status"] = "text_only_pass" if args.text_only else "transport_candidate_on_this_host"
        print("\nОбмен в этой среде подтверждён. Android, белые списки и просмотр в авиарежиме ещё не проверены.", flush=True)
    except ProbeError as error:
        report["status"] = "needs_investigation"
        report["checks"][step] = "not_confirmed"
        report["error"] = str(error)
        print("\nПроверка остановлена: " + str(error), file=sys.stderr)
    except KeyboardInterrupt:
        report["status"] = "interrupted"
        raise
    except Exception as error:
        report["status"] = "tool_error"
        report["checks"][step] = "not_confirmed"
        report["error"] = f"Ошибка инструмента ({type(error).__name__}); секретные параметры скрыты."
        print(report["error"], file=sys.stderr)
    finally:
        report["hosts"] = sorted(network.hosts)
        report["long_poll_gaps"] = {role: bot.gaps for role, bot in bots.items()}
        report["event_types_seen"] = {role: bot.observed for role, bot in bots.items()}
        private_json(report_path, report)
        print("Отчёт без ключей и подписанных URL: " + str(report_path), flush=True)
        if report.get("downloaded_file"):
            print("Скачанный MP4: " + report["downloaded_file"], flush=True)
    return 0 if report["status"] in ("transport_candidate_on_this_host", "text_only_pass") else 1


def parser():
    result = argparse.ArgumentParser(description="Проверка VK-ботов без LocalTube production API.")
    result.add_argument("--config", type=Path, default=state_dir() / "credentials.env")
    result.add_argument("--api-host", choices=API_HOSTS, default="api.vk.ru")
    commands = result.add_subparsers(dest="command", required=True, metavar="{doctor,run}")
    commands.add_parser("doctor", help="Проверить ключи и Long Poll; не отправляет сообщения.")
    run = commands.add_parser("run", help="Отправить тестовые сообщения и небольшой MP4 в настроенную беседу.")
    run.add_argument("--video", type=Path)
    run.add_argument("--text-only", action="store_true")
    run.add_argument("--timeout", type=int, default=40, choices=range(10, 121), metavar="10..120")
    run.add_argument("--discovery-timeout", type=int, default=180)
    child = commands.add_parser("_receive")
    child.add_argument("--checkpoint", type=Path, required=True)
    child.add_argument("--output", type=Path, required=True)
    child.add_argument("--timeout", type=int, default=40)
    return result


def main():
    os.umask(0o077)
    args = parser().parse_args()
    try:
        config = read_config(args.config)
        network = Network()
        if args.command == "_receive":
            return worker(args, Bot(network, config, "client", args.api_host))
        bots = {role: Bot(network, config, role, args.api_host) for role in ("server", "client")}
        if bots["server"].group_id == bots["client"].group_id:
            raise ProbeError("Для этой пробы нужны два разных сообщества.")
        if args.command == "doctor":
            for role, bot in bots.items():
                settings = bot.api("groups.getLongPollSettings", group_id=bot.group_id)
                if not settings.get("is_enabled") or not settings.get("events", {}).get("message_new"):
                    raise ProbeError(f"{role}: включите Long Poll API и событие message_new в настройках сообщества.")
                bot.connect()
                print(f"{role}: ключ и Bots Long Poll работают.")
            return 0
        return experiment(args, bots, network)
    except ProbeError as error:
        print(str(error), file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nОстановлено пользователем. Ключи в настройке сохранены.", file=sys.stderr)
        return 130
    except Exception as error:
        # No traceback: libraries can include a signed URL in exception text.
        print(f"Непредвиденная ошибка ({type(error).__name__}); секретные параметры скрыты.", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
