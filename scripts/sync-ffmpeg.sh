#!/usr/bin/env bash
# shellcheck disable=SC2016 # Markdown backticks are literal text.
# 手动同步已准备好的 S3 组件，不编译或重新压缩 FFmpeg。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MANIFEST="$ROOT/ffmpeg-manifest.json" OUTPUT=ffmpeg-dist PUBLISH=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --publish) PUBLISH=true; shift;;
    --manifest|--output)
      [ "$#" -ge 2 ] || { echo "Missing value: $1" >&2; exit 1; }
      case "$1" in --manifest) MANIFEST=$2;; --output) OUTPUT=$2;; esac; shift 2;;
    *) echo "Unknown argument: $1" >&2; exit 1;;
  esac
done
if [ -d "$OUTPUT" ] && [ -n "$(ls -A "$OUTPUT")" ]; then echo 'Output directory must be empty' >&2; exit 1; fi
mkdir -p "$OUTPUT"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/recolx-sync.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
BATCH=$(jq -er .release "$MANIFEST")
[[ "$BATCH" =~ ^ffmpeg-[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo 'Invalid source batch' >&2; exit 1; }
jq -e '(.ffmpeg|map(.platform)|sort)==["linux-x86_64","macos-aarch64","macos-x86_64","windows-x86_64"] and all(.ffmpeg[]; .file==("ffmpeg-"+.platform+".xz") and .license=="LGPL" and (.binary_sha256|test("^[a-f0-9]{64}$")) and .binary_size>0)' "$MANIFEST" >/dev/null
BASE="https://oss-cf.recolx.ai/client/ffmpeg/$BATCH"
jq -c '.ffmpeg[]' "$MANIFEST" > "$TMP/entries"
# 全部下载和校验成功后才触碰 GitHub Release，单个下载失败不会留下半套新资产。
while IFS= read -r entry; do
  platform=$(jq -r .platform <<< "$entry"); name=$(jq -r .file <<< "$entry")
  curl --fail --silent --show-error --location --retry 3 "$BASE/$name" -o "$OUTPUT/$name"
  curl --fail --silent --show-error --location --retry 3 "$BASE/$platform-LICENSE.txt" -o "$OUTPUT/$platform-LICENSE.txt"
  [ -s "$OUTPUT/$platform-LICENSE.txt" ] || { echo "Empty license: $platform" >&2; exit 1; }
  xz --memlimit-decompress=256MiB -dc "$OUTPUT/$name" > "$TMP/binary"
  hash=$(openssl dgst -sha256 -r "$TMP/binary" | awk '{print $1}')
  size=$(wc -c < "$TMP/binary" | tr -d ' ')
  [ "$hash" = "$(jq -r .binary_sha256 <<< "$entry")" ] && [ "$size" = "$(jq -r .binary_size <<< "$entry")" ] || { echo "Binary checksum/size mismatch: $platform" >&2; exit 1; }
  printf 'Verified %s: %s (%s bytes)\n' "$platform" "$hash" "$size"
done < "$TMP/entries"
cp "$MANIFEST" "$OUTPUT/ffmpeg-manifest.json"
[ "$PUBLISH" = true ] || { echo 'All files verified. Pass --publish to update the latest release.'; exit 0; }
REPO=${GITHUB_REPOSITORY:-Recolx-AI/recolx-dist}
[ "$REPO" = Recolx-AI/recolx-dist ] || { echo 'Unexpected publishing repository' >&2; exit 1; }
{
  printf '# FFmpeg optional components\n\nSource batch: `%s`.\n\n' "$BATCH"
  printf 'These prebuilt files are synchronized from S3; FFmpeg is not rebuilt by this workflow. Each `.xz` contains one executable.\n\n'
  printf 'Stable URLs: `https://github.com/Recolx-AI/recolx-dist/releases/download/latest/<filename>`.\n\n'
  jq -r '.ffmpeg[] | "- **"+.platform+"** ("+.version+"): `"+.file+"`\n  - Extracted SHA256: `"+.binary_sha256+"`\n  - Upstream archive: "+.source.url' "$MANIFEST"
  printf '\nLicense notices are attached. Source/build references: https://ffmpeg.org/download.html, https://github.com/FFmpeg-Builds/FFmpeg-Builds, https://pypi.org/project/ae-ffmpeg/1.1.2/.\n'
  printf '\nThe latest assets may change. Clients keep verifying their bundled SHA256 and can fall back to their pinned S3 batch.\n'
} > "$TMP/notes.md"
if ! gh api "repos/$REPO/releases/tags/latest" > "$TMP/release.json" 2> "$TMP/github-error"; then
  grep -q 'HTTP 404' "$TMP/github-error" || { cat "$TMP/github-error" >&2; exit 1; }
  gh release create latest -R "$REPO" --draft --target "${GITHUB_SHA:-$(git -C "$ROOT" rev-parse HEAD)}" --title 'FFmpeg latest' --notes-file "$TMP/notes.md"
fi
# 不删除历史版本标签；只更新用户明确指定的 rolling latest。
gh release upload latest -R "$REPO" "$OUTPUT"/* --clobber
gh release edit latest -R "$REPO" --draft=false --latest --title 'FFmpeg latest' --notes-file "$TMP/notes.md"
