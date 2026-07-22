# Installation & Source Builds

## Release Status

Flowtype's source is public, but there is no Developer ID signed and notarized public DMG yet. Ordinary users should not need Swift or a source checkout: wait for the official asset on [GitHub Releases](https://github.com/smgonthebeat/Flowtype/releases). This document does not claim that a source-built or locally signed app is an official trusted binary release.

## Requirements

- Apple Silicon Mac running macOS 14 or later.
- Xcode Command Line Tools with Swift 5.9 or later.
- [`uv`](https://docs.astral.sh/uv/getting-started/installation/).
- Several gigabytes of free disk space and unified memory for Qwen3-ASR.

The Xcode/Swift and `uv` requirements below apply only to developers building
from source. The planned DMG includes the app and its managed `uv` runtime.

Check the local toolchain:

```bash
swift --version
uv --version
```

## Build From Source

From the repository root:

```bash
swift test
uv run --project Helpers/qwen-asr-helper --frozen pytest
make build
```

The app bundle is created at:

```text
.build/Flowtype.app
```

The default build uses ad-hoc local signing. It is suitable for development and inspection, not for representing the app as an official distributed release.

## First Run

Flowtype needs:

1. Microphone permission to record speech.
2. Accessibility permission to monitor `Fn` and paste into the active app.
3. Optional Speech Recognition permission when Apple Speech fallback is used.
4. Explicit confirmation before downloading a local Qwen3-ASR model.

The model download is separate from the repository checkout and may take time. Model files are stored under Flowtype's Application Support directory, not in the repository.

## Local Verification

Source-level verification does not require launching the app:

```bash
swift test
uv run --project Helpers/qwen-asr-helper --frozen pytest
uv run --project script --frozen python -B -m unittest discover -s script/tests
make build
make verify-package
```

Launching the GUI, copying into `/Applications`, distribution signing, notarization, and DMG verification are separate actions. Do not bypass Gatekeeper with `xattr`, and do not disable macOS security controls to run an unverified build.

## Updating A Source Checkout

Review upstream changes before rebuilding. Keep local model caches, recordings, and Application Support data outside Git; they are not part of the source tree.
