"""Publish a complete CI bundle as a run-specific GitHub Release."""
import argparse
import os
from pathlib import Path
import subprocess
import zipfile


def publish(prefix, files, prerelease=True, bundle='results.zip'):
    files = [Path(path) for path in files if Path(path).is_file()]
    if not files:
        raise ValueError('No files to publish')
    if bundle == 'update.zip' and sorted(path.name for path in files) != ['manifest.json', 'update.apk']:
        raise ValueError('Expected exactly manifest.json and update.apk')
    archive = Path(os.environ['RUNNER_TEMP']) / bundle
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as output:
        for path in files:
            output.write(path, path.name)
    tag = f"{prefix}-{os.environ['GITHUB_RUN_ID']}-{os.environ['GITHUB_RUN_ATTEMPT']}"
    repository = os.environ['GITHUB_REPOSITORY']

    def gh(*args):
        subprocess.run(['gh', 'release', *args, '--repo', repository], check=True)

    options = ['--prerelease'] if prerelease else []
    gh('create', tag, '--target', os.environ['GITHUB_SHA'], '--draft', '--latest=false',
       '--title', tag, '--notes', f"CI run: https://github.com/{repository}/actions/runs/"
       + os.environ['GITHUB_RUN_ID'], *options)
    gh('upload', tag, str(archive))
    # Delivery ignores the draft if upload fails.
    gh('edit', tag, '--draft=false', '--latest=false')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prefix', required=True)
    parser.add_argument('--stable', action='store_true')
    parser.add_argument('--bundle', default='results.zip')
    parser.add_argument('files', nargs='+')
    args = parser.parse_args()
    publish(args.prefix, args.files, not args.stable, args.bundle)
