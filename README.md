# recolx-dist

Public optional components for the **Recolx.AI desktop client**.

## FFmpeg downloads

The [`latest` release](https://github.com/Recolx-AI/recolx-dist/releases/tag/latest) provides stable download URLs:

| Platform | Download |
| --- | --- |
| Windows x86_64 | [ffmpeg-windows-x86_64.xz](https://github.com/Recolx-AI/recolx-dist/releases/download/latest/ffmpeg-windows-x86_64.xz) |
| Linux x86_64 | [ffmpeg-linux-x86_64.xz](https://github.com/Recolx-AI/recolx-dist/releases/download/latest/ffmpeg-linux-x86_64.xz) |
| macOS Apple Silicon | [ffmpeg-macos-aarch64.xz](https://github.com/Recolx-AI/recolx-dist/releases/download/latest/ffmpeg-macos-aarch64.xz) |
| macOS Intel | [ffmpeg-macos-x86_64.xz](https://github.com/Recolx-AI/recolx-dist/releases/download/latest/ffmpeg-macos-x86_64.xz) |

Each xz archive contains one executable. Platform-specific license notices and `ffmpeg-manifest.json` are attached to the release.

## Occasional manual synchronization

Open **Actions → Sync FFmpeg latest → Run workflow**. There is no push trigger, schedule, or client-release trigger. The workflow downloads the existing S3 batch specified by `ffmpeg-manifest.json`, checks each extracted binary's SHA256 and size, and updates the fixed `latest` release. It does not compile or recompress FFmpeg.

This workflow runs in this repository and uses its automatically supplied `GITHUB_TOKEN` with `contents: write`. No `DIST_RELEASE_TOKEN`, personal token, or S3 credentials are required.

For a component upgrade, first prepare a new versioned S3 batch in the client repository. Copy the reviewed FFmpeg manifest here, commit it, and run this workflow. Keep old S3 batches: clients pin binary hashes, so older clients can fall back to their original batch when the rolling latest binary changes. Historical version-tagged releases remain available.

Local verification: `bash scripts/sync-ffmpeg.sh --output /tmp/ffmpeg-check` (the output directory must be empty). Add `--publish` to upload using your local `gh` login.

## Licenses and provenance

Only LGPL builds are included. FFmpeg is a trademark of the FFmpeg developers; copyright belongs to the respective authors. See [FFmpeg Legal](https://ffmpeg.org/legal.html).

- Windows/Linux: [FFmpeg-Builds](https://github.com/FFmpeg-Builds/FFmpeg-Builds).
- macOS: static LGPLv3 builds from [ae-ffmpeg](https://pypi.org/project/ae-ffmpeg/).
- Source code: [FFmpeg Downloads](https://ffmpeg.org/download.html). Exact upstream archive URLs and binary checksums are recorded in the manifest and release notes.
