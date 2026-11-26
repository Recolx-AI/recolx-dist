#!/usr/bin/env bash
# 验证校验失败不会发布、默认只验证，以及首次发布的调用顺序。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/source"
export FIXTURE="$TMP/source" GH_LOG="$TMP/gh.log"
printf 'fixture binary' > "$TMP/binary"
hash=$(openssl dgst -sha256 -r "$TMP/binary" | awk '{print $1}')
size=$(wc -c < "$TMP/binary")
jq --arg hash "$hash" --argjson size "$size" '.ffmpeg |= map(.binary_sha256=$hash | .binary_size=$size)' "$ROOT/ffmpeg-manifest.json" > "$TMP/manifest.json"
for platform in windows-x86_64 linux-x86_64 macos-aarch64 macos-x86_64; do
  xz -c "$TMP/binary" > "$FIXTURE/ffmpeg-$platform.xz"
  printf 'test license' > "$FIXTURE/$platform-LICENSE.txt"
done
cat > "$TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -eu
while [ "$#" -gt 0 ]; do
  case "$1" in https://*) name=${1##*/}; shift;; -o) output=$2; shift 2;; *) shift;; esac
done
cp "$FIXTURE/$name" "$output"
MOCK
cat > "$TMP/bin/gh" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
if [ "$1" = api ]; then echo 'HTTP 404' >&2; exit 1; fi
MOCK
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH" GITHUB_REPOSITORY=Recolx-AI/recolx-dist
bash "$ROOT/scripts/sync-ffmpeg.sh" --manifest "$TMP/manifest.json" --output "$TMP/check"
[ ! -e "$GH_LOG" ]
bash "$ROOT/scripts/sync-ffmpeg.sh" --manifest "$TMP/manifest.json" --output "$TMP/publish" --publish
[ "$(wc -l < "$GH_LOG")" -eq 4 ]
sed -n '2p' "$GH_LOG" | grep -q '^release create latest '
sed -n '3p' "$GH_LOG" | grep -q '^release upload latest '
sed -n '4p' "$GH_LOG" | grep -q '^release edit latest '
rm "$GH_LOG"
printf 'wrong executable' | xz -c > "$FIXTURE/ffmpeg-windows-x86_64.xz"
if bash "$ROOT/scripts/sync-ffmpeg.sh" --manifest "$TMP/manifest.json" --output "$TMP/bad" --publish; then
  echo 'Expected hash rejection' >&2; exit 1
fi
[ ! -e "$GH_LOG" ]
echo 'PASS: verify-only, initial publish order, checksum rejection before publishing'
