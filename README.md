# recolx-dist

Public distribution assets for the **Recolx.AI desktop client**. This repository contains no source code. Releases host optional components that the client downloads on demand. The same files are mirrored at <https://oss-cf.recolx.ai/client/>. The client tries GitHub first and falls back to the mirror if the download fails.

## FFmpeg

Releases tagged `ffmpeg-<version>` provide one file per platform: `ffmpeg-<platform>.xz`. Each archive contains a single FFmpeg executable compressed with xz. After downloading and extracting it, the client verifies the extracted file against the SHA256 checksum in its bundled manifest.

- License: **LGPL**. Only builds without GPL or nonfree components are included. FFmpeg is a trademark of the FFmpeg developers; copyright belongs to the respective authors. See [FFmpeg Legal](https://ffmpeg.org/legal.html).
- Sources:
  - Windows / Linux: LGPL builds from [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds).
  - macOS: static LGPLv3 builds from [ae-ffmpeg on PyPI](https://pypi.org/project/ae-ffmpeg/).
- Corresponding source code: [FFmpeg Downloads](https://ffmpeg.org/download.html). See the relevant release notes for the specific version and build configuration.

These assets are generated and uploaded automatically by the mirroring workflow in the Recolx client repository. Do not modify them manually.
