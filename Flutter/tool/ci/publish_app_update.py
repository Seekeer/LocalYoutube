"""Publish an already signed APK from an isolated SSH upload directory (Linux)."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile

APPLICATION_IDS = {'preview': 'org.localtube.app.debug',
                   'stable': 'org.localtube.app.stable'}


def sync_directory(directory):
    descriptor = os.open(directory, os.O_DIRECTORY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def atomic_json(path, value):
    descriptor, name = tempfile.mkstemp(dir=path.parent, prefix='.metadata-')
    try:
        with os.fdopen(descriptor, 'w') as output:
            json.dump(value, output, sort_keys=True)
            output.write('\n')
            output.flush()
            os.fsync(output.fileno())
        os.chmod(name, 0o644)
        os.replace(name, path)
        sync_directory(path.parent)
    finally:
        Path(name).unlink(missing_ok=True)


def publish(root, apk, metadata):
    channel = metadata['channel']
    if APPLICATION_IDS.get(channel) != metadata['applicationId']:
        raise ValueError('Channel/application ID mismatch')
    code = metadata['versionCode']
    if type(code) is not int or not 0 < code <= 2100000000:
        raise ValueError('Invalid Android versionCode')
    if not isinstance(metadata['versionName'], str) or not metadata['versionName'].strip():
        raise ValueError('Missing version name')
    directory = root / channel
    packages = directory / 'packages'
    packages.mkdir(parents=True, exist_ok=True)
    descriptor, staged_name = tempfile.mkstemp(dir=packages, prefix='.upload-')
    staged = Path(staged_name)
    try:
        # Copy and verify in the destination filesystem before taking the publication lock.
        with os.fdopen(descriptor, 'wb') as output, apk.open('rb') as source:
            shutil.copyfileobj(source, output)
            output.flush()
            os.fsync(output.fileno())
        with staged.open('rb') as source:
            digest = hashlib.file_digest(source, 'sha256').hexdigest()
        if (staged.stat().st_size <= 0 or staged.stat().st_size != metadata['size']
                or digest != metadata['sha256']
                or metadata['artifactId'] != f'{code}-{digest}'):
            raise ValueError('Incomplete or corrupt APK')
        with (directory / '.publish.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            version = directory / f'{code}.json'
            if version.exists() and json.loads(version.read_text()) != metadata:
                raise ValueError('A published version cannot be replaced')
            artifact = packages / (metadata['artifactId'] + '.apk')
            os.chmod(staged, 0o644)
            if not artifact.exists():
                os.link(staged, artifact)
                sync_directory(packages)
            latest = directory / 'latest.json'
            atomic_json(version, metadata)
            if latest.exists() and json.loads(latest.read_text())['versionCode'] >= code:
                return
            atomic_json(latest, metadata)
    finally:
        staged.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--metadata', type=Path, required=True)
    args = parser.parse_args()
    publish(args.root, args.apk, json.loads(args.metadata.read_text()))


if __name__ == '__main__':
    main()
