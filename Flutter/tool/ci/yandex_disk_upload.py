import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


API_BASE_URL = "https://cloud-api.yandex.net/v1/disk"


class YandexDiskClient:
    def __init__(self, token: str):
        self._headers = {"Authorization": "OAuth " + token}

    def request_json(
        self,
        url: str,
        *,
        method: str = "GET",
        suppressed_error_codes: tuple[int, ...] = (),
    ) -> dict[str, Any]:
        request = urllib.request.Request(url, method=method, headers=self._headers)
        try:
            with urllib.request.urlopen(request) as response:
                if response.status == 204:
                    return {}
                return json.load(response)
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            if error.code not in suppressed_error_codes:
                print(f"Yandex Disk API {method} {url} failed with {error.code}: {body}", file=sys.stderr)
            raise


def quote_path(path: str) -> str:
    return urllib.parse.quote(path, safe="")


def resource_url(path: str, *, extra: str = "") -> str:
    suffix = f"&{extra}" if extra else ""
    return f"{API_BASE_URL}/resources?path={quote_path(path)}{suffix}"


def ensure_remote_directory(client: Any, remote_dir: str) -> None:
    try:
        client.request_json(resource_url(remote_dir), method="PUT", suppressed_error_codes=(409,))
    except urllib.error.HTTPError as error:
        if error.code != 409:
            raise


def cleanup_remote_files(
    client: Any,
    remote_dir: str,
    cleanup_prefix: str,
    *,
    keep_count: int,
) -> list[str]:
    if keep_count < 0:
        raise ValueError("keep_count must be greater than or equal to 0")
    if not cleanup_prefix:
        return []

    response = client.request_json(
        resource_url(
            remote_dir,
            extra="limit=1000&fields=_embedded.items.name,_embedded.items.path,_embedded.items.type,_embedded.items.created",
        )
    )
    items = response.get("_embedded", {}).get("items", [])
    matching_files = [
        item
        for item in items
        if item.get("type") == "file" and str(item.get("name", "")).startswith(cleanup_prefix)
    ]
    matching_files.sort(key=lambda item: (str(item.get("created", "")), str(item.get("name", ""))), reverse=True)

    deleted_names = []
    for item in matching_files[keep_count:]:
        path = item.get("path")
        name = item.get("name")
        if not path or not name:
            continue
        client.request_json(resource_url(str(path), extra="permanently=true"), method="DELETE")
        deleted_names.append(str(name))
    return deleted_names


def get_upload_url(client: Any, remote_path: str) -> str:
    response = client.request_json(
        f"{API_BASE_URL}/resources/upload?path={quote_path(remote_path)}&overwrite=true"
    )
    href = response.get("href")
    if not href:
        raise RuntimeError("Yandex Disk upload URL response did not include href.")
    return str(href)


def prepare_upload_url(
    client: Any,
    remote_dir: str,
    remote_path: str,
    cleanup_prefix: str,
    *,
    keep_count: int,
) -> str:
    ensure_remote_directory(client, remote_dir)
    try:
        deleted_names = cleanup_remote_files(client, remote_dir, cleanup_prefix, keep_count=keep_count)
    except urllib.error.HTTPError as error:
        if error.code != 403:
            raise
        print("Skipping Yandex Disk cleanup after API 403; continuing with APK upload.", file=sys.stderr)
    else:
        for deleted_name in deleted_names:
            print(f"Deleted old Yandex Disk artifact: {deleted_name}", file=sys.stderr)
    return get_upload_url(client, remote_path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--remote-dir", required=True)
    parser.add_argument("--remote-path", required=True)
    parser.add_argument("--cleanup-prefix", default="")
    parser.add_argument("--keep", type=int, default=8)
    args = parser.parse_args()

    token = os.environ.get("YANDEX_DISK_TOKEN", "")
    if not token:
        print("Missing Yandex Disk OAuth token secret: YANDEX_DISK_TOKEN", file=sys.stderr)
        return 1

    client = YandexDiskClient(token)
    print(
        prepare_upload_url(
            client,
            args.remote_dir,
            args.remote_path,
            args.cleanup_prefix,
            keep_count=args.keep,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
