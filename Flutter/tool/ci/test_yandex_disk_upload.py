import unittest
import urllib.error
from contextlib import redirect_stderr
from io import StringIO
from unittest.mock import patch

import yandex_disk_upload


class FakeYandexDiskClient:
    def __init__(self):
        self.calls = []

    def request_json(self, url: str, *, method: str = "GET", **_kwargs):
        self.calls.append((method, url))
        if method == "PUT" and "/resources?path=" in url:
            raise urllib.error.HTTPError(
                url=url,
                code=409,
                msg="Conflict",
                hdrs=None,
                fp=None,
            )
        if method == "GET" and "/resources?" in url:
            return {
                "_embedded": {
                    "items": [
                        {
                            "name": "localtube_preview-v1.0.3-b3.apk",
                            "path": "disk:/Builds/LocalTube/localtube_preview-v1.0.3-b3.apk",
                            "type": "file",
                            "created": "2026-04-03T10:00:00+00:00",
                        },
                        {
                            "name": "localtube_preview-v1.0.2-b2.apk",
                            "path": "disk:/Builds/LocalTube/localtube_preview-v1.0.2-b2.apk",
                            "type": "file",
                            "created": "2026-04-02T10:00:00+00:00",
                        },
                        {
                            "name": "localtube_preview-v1.0.1-b1.apk",
                            "path": "disk:/Builds/LocalTube/localtube_preview-v1.0.1-b1.apk",
                            "type": "file",
                            "created": "2026-04-01T10:00:00+00:00",
                        },
                        {
                            "name": "localtube_stable-v1.0.1-b1.apk",
                            "path": "disk:/Builds/LocalTube/localtube_stable-v1.0.1-b1.apk",
                            "type": "file",
                            "created": "2026-04-01T09:00:00+00:00",
                        },
                    ]
                }
            }
        if method == "GET" and "/resources/upload?" in url:
            return {"href": "https://upload.example/localtube-preview.apk"}
        if method == "DELETE":
            return {}
        raise AssertionError(f"Unexpected request: {method} {url}")


class CleanupForbiddenClient(FakeYandexDiskClient):
    def request_json(self, url: str, *, method: str = "GET", **kwargs):
        if method == "GET" and "/resources?" in url:
            self.calls.append((method, url))
            raise urllib.error.HTTPError(
                url=url,
                code=403,
                msg="Forbidden",
                hdrs=None,
                fp=None,
            )
        return super().request_json(url, method=method, **kwargs)


class YandexDiskUploadTests(unittest.TestCase):
    def test_request_json_does_not_log_suppressed_http_status(self) -> None:
        client = yandex_disk_upload.YandexDiskClient("token")
        error = urllib.error.HTTPError(
            url="https://cloud-api.yandex.net/v1/disk/resources",
            code=409,
            msg="Conflict",
            hdrs=None,
            fp=None,
        )

        stderr = StringIO()
        with patch("urllib.request.urlopen", side_effect=error):
            with redirect_stderr(stderr):
                with self.assertRaises(urllib.error.HTTPError):
                    client.request_json(
                        "https://cloud-api.yandex.net/v1/disk/resources",
                        method="PUT",
                        suppressed_error_codes=(409,),
                    )

        self.assertEqual(stderr.getvalue(), "")

    def test_ensure_remote_directory_ignores_existing_directory_conflict(self) -> None:
        client = FakeYandexDiskClient()

        yandex_disk_upload.ensure_remote_directory(client, "disk:/Builds/LocalTube")

        self.assertEqual(len(client.calls), 1)
        self.assertEqual(client.calls[0][0], "PUT")

    def test_cleanup_deletes_oldest_matching_files_beyond_keep_count(self) -> None:
        client = FakeYandexDiskClient()

        deleted = yandex_disk_upload.cleanup_remote_files(
            client,
            "disk:/Builds/LocalTube",
            "localtube_preview",
            keep_count=2,
        )

        self.assertEqual(deleted, ["localtube_preview-v1.0.1-b1.apk"])
        delete_calls = [call for call in client.calls if call[0] == "DELETE"]
        self.assertEqual(len(delete_calls), 1)
        self.assertIn("permanently=true", delete_calls[0][1])
        self.assertNotIn("localtube_stable", delete_calls[0][1])

    def test_cleanup_forbidden_does_not_block_upload_url_generation(self) -> None:
        client = CleanupForbiddenClient()

        stderr = StringIO()
        with redirect_stderr(stderr):
            upload_url = yandex_disk_upload.prepare_upload_url(
                client,
                "disk:/Builds/LocalTube",
                "disk:/Builds/LocalTube/localtube_preview-v1.0.4-b4.apk",
                "localtube_preview",
                keep_count=3,
            )

        self.assertEqual(upload_url, "https://upload.example/localtube-preview.apk")
        self.assertIn("Skipping Yandex Disk cleanup after API 403", stderr.getvalue())

    def test_get_upload_url_quotes_remote_path_and_requests_overwrite(self) -> None:
        client = FakeYandexDiskClient()

        upload_url = yandex_disk_upload.get_upload_url(
            client,
            "disk:/Builds/LocalTube/localtube preview.apk",
        )

        self.assertEqual(upload_url, "https://upload.example/localtube-preview.apk")
        self.assertIn("path=disk%3A%2FBuilds%2FLocalTube%2Flocaltube%20preview.apk", client.calls[-1][1])
        self.assertIn("overwrite=true", client.calls[-1][1])


if __name__ == "__main__":
    unittest.main()
