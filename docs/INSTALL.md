# Installation & Source Builds

## Release Status

The official [`v0.1.0-preview.2` GitHub Release](https://github.com/smgonthebeat/Flowtype/releases/tag/v0.1.0-preview.2) contains an Apple Silicon DMG and SHA-256 file. This Preview uses a local development signature; it is not signed with an Apple Developer ID and has not been notarized by Apple. It is therefore not a seamless trusted installer, and macOS will block the first launch.

## Requirements

- Apple Silicon Mac running macOS 14 or later.
- Several gigabytes of free disk space and unified memory for Qwen3-ASR.

The Preview DMG includes the app and its managed `uv` runtime. Xcode Command
Line Tools with Swift 5.9 or later and [`uv`](https://docs.astral.sh/uv/getting-started/installation/)
are required only for developers building from source.

## Install The Preview DMG

1. Download [`Flowtype.dmg`](https://github.com/smgonthebeat/Flowtype/releases/download/v0.1.0-preview.2/Flowtype.dmg) and its [`Flowtype.dmg.sha256`](https://github.com/smgonthebeat/Flowtype/releases/download/v0.1.0-preview.2/Flowtype.dmg.sha256) from the official Release.
2. Open the DMG and drag `Flowtype.app` to Applications.
3. Try to open Flowtype once and dismiss the macOS warning.
4. Open **System Settings → Privacy & Security**. In Security, click **Open Anyway**, then confirm **Open**.
5. Grant Microphone and Accessibility permissions when Flowtype requests them.

Apple documents this standard exception flow in [Open a Mac app from an unknown developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). Only override the warning when the DMG came from this official Release and its checksum matches. Do not disable Gatekeeper or run quarantine-removal or Gatekeeper-disabling commands.

## Developer Requirements

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

Launching the GUI, copying into `/Applications`, distribution signing, notarization, and DMG verification are separate actions. The published Preview is intentionally unnotarized and uses the documented Privacy & Security exception flow; do not disable macOS security controls.

## Updating A Source Checkout

Review upstream changes before rebuilding. Keep local model caches, recordings, and Application Support data outside Git; they are not part of the source tree.
