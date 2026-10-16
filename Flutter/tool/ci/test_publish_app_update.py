from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('publish_app_update.py')


class PublicationTests(unittest.TestCase):
    def test_complete_package_becomes_latest_for_both_channels(self):
        for channel, app_id in [('preview', 'org.localtube.app.debug'),
                                ('stable', 'org.localtube.app.stable')]:
            with self.subTest(channel=channel), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                result, metadata = self.publish(root, channel, app_id, 20, b'complete apk')
                self.assertEqual(0, result.returncode, result.stderr)
                latest = json.loads((root / channel / 'latest.json').read_text())
                self.assertEqual(metadata, latest)
                self.assertEqual(b'complete apk', (root / channel / 'packages' / (latest['artifactId'] + '.apk')).read_bytes())

    def test_interrupted_upload_keeps_previous_publication(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.publish(root)
            previous = (root / 'preview/latest.json').read_bytes()
            result, _ = self.publish(root, code=21, data=b'partial', expected=b'complete apk')
            self.assertNotEqual(0, result.returncode)
            self.assertEqual(previous, (root / 'preview/latest.json').read_bytes())

    def test_late_old_build_cannot_replace_newer_and_artifact_is_immutable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, first = self.publish(root, code=21)
            self.publish(root, code=20, data=b'older')
            self.assertEqual(first, json.loads((root / 'preview/latest.json').read_text()))
            result, _ = self.publish(root, code=21, data=b'replacement')
            self.assertNotEqual(0, result.returncode)
            self.assertEqual(first, json.loads((root / 'preview/latest.json').read_text()))
            self.assertEqual(b'complete apk', (root / 'preview/packages' / (first['artifactId'] + '.apk')).read_bytes())

    def test_concurrent_builds_choose_the_newest_complete_package(self):
        with tempfile.TemporaryDirectory() as directory, ThreadPoolExecutor(max_workers=4) as workers:
            root = Path(directory)
            results = list(workers.map(lambda code: self.publish(root, code=code), [22, 20, 23, 21]))
            for result, _ in results:
                self.assertEqual(0, result.returncode, result.stderr)
            latest = json.loads((root / 'preview/latest.json').read_text())
            self.assertEqual(23, latest['versionCode'])
            for _, metadata in results:
                self.assertEqual(b'complete apk', (root / 'preview/packages' / (metadata['artifactId'] + '.apk')).read_bytes())

    def test_wrong_channel_identity_is_not_published(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result, _ = self.publish(root, app_id='org.localtube.app.stable')
            self.assertNotEqual(0, result.returncode)
            self.assertFalse((root / 'preview/latest.json').exists())

    def publish(self, root, channel='preview', app_id='org.localtube.app.debug', code=20,
                data=b'complete apk', expected=None):
        digest = hashlib.sha256(data if expected is None else expected).hexdigest()
        metadata = dict(channel=channel, applicationId=app_id, versionCode=code,
                        versionName=f'1.0.{code}', artifactId=f'{code}-{digest}',
                        size=len(data if expected is None else expected), sha256=digest)
        with tempfile.TemporaryDirectory() as stage:
            apk = Path(stage) / 'upload.apk'
            apk.write_bytes(data)
            manifest = Path(stage) / 'metadata.json'
            manifest.write_text(json.dumps(metadata))
            result = subprocess.run([sys.executable, str(SCRIPT), '--root', str(root),
                                     '--apk', str(apk), '--metadata', str(manifest)],
                                    capture_output=True, text=True)
        return result, metadata


if __name__ == '__main__':
    unittest.main()
