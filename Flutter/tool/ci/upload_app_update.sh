#!/usr/bin/env bash
# Run from Flutter. Publication uses the existing API deployment SSH credentials.
set -euo pipefail
# Only the first-parent main chain is an ordered distribution history. A merged
# side branch is an ancestor too, but must not publish a competing version code.
git fetch origin +refs/heads/main:refs/remotes/origin/main
source_commit="$(git rev-parse HEAD)"
# Do not use grep -q: read the whole pipe so pipefail cannot report SIGPIPE.
git rev-list --first-parent origin/main | grep -Fx "$source_commit" > /dev/null || {
  echo 'Only commits on the canonical main first-parent chain may publish Android updates'
  exit 1
}
channel="$1"
apk="$2"
: "${DEPLOY_HOST:?Missing DEPLOY_HOST}"
: "${DEPLOY_USER:?Missing DEPLOY_USER}"
root="${APP_UPDATES_ROOT:-/srv/localtube/app-updates}"
[[ "$root" =~ ^/[a-zA-Z0-9_./-]+$ ]] || { echo 'Invalid storage path'; exit 1; }
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
if [[ -n "${DEPLOY_HOST_KEY:-}" ]]; then
  printf '%s\n' "$DEPLOY_HOST_KEY" > "$stage/known_hosts"
else
  # Public host key verified against /etc/ssh on the existing LAN server.
  printf '%s %s\n' "$DEPLOY_HOST" "$(cat ../.gitea/app-update-host-key.pub)" > "$stage/known_hosts"
fi
opts=(-o "UserKnownHostsFile=$stage/known_hosts" -o StrictHostKeyChecking=yes -o ConnectTimeout=30)
if [[ -n "${DEPLOY_SSH_KEY:-}" ]]; then
  printf '%s\n' "$DEPLOY_SSH_KEY" > "$stage/key"
  chmod 600 "$stage/key"
  opts+=(-i "$stage/key" -o IdentitiesOnly=yes -o BatchMode=yes)
  ssh_cmd=(ssh "${opts[@]}")
  scp_cmd=(scp "${opts[@]}")
else
  export SSHPASS="${DEPLOY_PASSWORD:?Missing SSH key or password}"
  ssh_cmd=(sshpass -e ssh "${opts[@]}")
  scp_cmd=(sshpass -e scp "${opts[@]}")
fi
build_tools="${ANDROID_SDK_ROOT:-${ANDROID_HOME:?Missing Android SDK}}/build-tools"
aapt="$(find "$build_tools" -name aapt | sort -V | tail -n 1)"
apksigner="$(dirname "$aapt")/apksigner"
"$apksigner" verify "$apk"
"$aapt" dump badging "$apk" > "$stage/badging"
python3 - "$apk" "$channel" "$stage" <<'PY'
import hashlib, json, os, re, sys
from pathlib import Path
apk, channel, stage = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
match = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", (stage / 'badging').read_text())
if not match:
    raise ValueError('Cannot read APK identity')
app_id, code, name = match.groups()
expected = {'preview': 'org.localtube.app.debug', 'stable': 'org.localtube.app.stable'}
if app_id != expected[channel] or int(code) != int(os.environ['BUILD_NUMBER']):
    raise ValueError('Unexpected APK identity/version')
with apk.open('rb') as source:
    digest = hashlib.file_digest(source, 'sha256').hexdigest()
(stage / 'metadata.json').write_text(json.dumps(dict(channel=channel, applicationId=app_id,
    versionCode=int(code), versionName=name, artifactId=f'{code}-{digest}', size=apk.stat().st_size, sha256=digest)))
PY
target="${DEPLOY_USER}@${DEPLOY_HOST}"
# Separate upload directory: a failed SCP can never touch latest or a published APK.
remote_stage="$("${ssh_cmd[@]}" "$target" 'mktemp -d /tmp/localtube-update.XXXXXXXXXX')"
[[ "$remote_stage" =~ ^/tmp/localtube-update\.[a-zA-Z0-9]+$ ]] || exit 1
cleanup() {
  "${ssh_cmd[@]}" "$target" "rm -rf '$remote_stage'" || true
  rm -rf "$stage"
}
trap cleanup EXIT
"${scp_cmd[@]}" "$apk" "$target:$remote_stage/upload.apk"
"${scp_cmd[@]}" "$stage/metadata.json" tool/ci/publish_app_update.py "$target:$remote_stage/"
"${ssh_cmd[@]}" "$target" "python3 '$remote_stage/publish_app_update.py' --root '$root' --apk '$remote_stage/upload.apk' --metadata '$remote_stage/metadata.json'"
