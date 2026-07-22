# Flowtype

English · [简体中文](README.md)

> **Release status:** The first public release is in preparation. The source is under pre-publication review; no prebuilt DMG, checksum, signing, or notarization claim is active yet.

Flowtype is a local-first macOS dictation app. Hold `Fn` to speak, release it to transcribe locally, and the result is pasted into the app you were using. It is designed for real speech that mixes Chinese, English, technical terms, and spoken mathematics.

![Flowtype home screen showing synthetic demo usage statistics and feature entry points](website/assets/flowtype-home-sanitized.png)

## Why Flowtype

General-purpose dictation often interrupts technical thought when languages, terminology, and mathematical notation appear in the same sentence. Flowtype aims to place what you already said at the cursor quickly and faithfully; it is not an automatic writing service.

## Highlights

- **Hold, speak, release, paste:** use `Fn` from the current app to record, transcribe, and paste.
- **Mixed language and terminology:** local Qwen3-ASR with user-controlled terminology context.
- **Spoken mathematics:** render mathematical expressions as Unicode or LaTeX.
- **Local-first:** the primary engine runs on Apple Silicon without a required cloud ASR subscription.
- **Recoverable failures:** History, up to three local retry recordings, model status, and diagnostics.
- **Native macOS workflow:** menu bar, recording capsule, permission onboarding, and model management.

## Requirements

- macOS 14 or later;
- an Apple Silicon Mac;
- Microphone and Accessibility permissions;
- Swift 5.9 or later for source builds;
- several gigabytes of free storage and unified memory for the local model and runtime.

When preparing a local model for the first time, Flowtype downloads Qwen3-ASR model files from Hugging Face after explicit confirmation. Model weights are not stored in this repository or bundled with the source archive.

## Getting Started

The current public candidate supports source builds only. A signed and notarized DMG is not available yet. Read [Installation & Source Builds](docs/INSTALL.md), and do not download unofficial files presented as a Flowtype release.

From the repository root, run the development checks:

```bash
swift test
uv run --project Helpers/qwen-asr-helper --frozen pytest
make build
```

`make build` creates a locally ad-hoc-signed development bundle at `.build/Flowtype.app`; it is not an official distribution build.

## Privacy, With Concrete Boundaries

- Qwen3-ASR transcription uses a local helper bound to `127.0.0.1` and protected by a per-session token.
- Apple Speech fallback runs only when on-device recognition is supported and sets `requiresOnDeviceRecognition`.
- Transcript History is stored locally, enabled by default, and defaults to 100 entries; it can be disabled or adjusted in Settings.
- With History enabled, up to three recent recordings are retained locally for manual retry; clearing History also clears those retry recordings.
- Model download is an explicit network operation. The website, source build, and routine local transcription have different network boundaries.

See [Privacy & Local Data](docs/PRIVACY.md) for details. Never attach real recordings, transcripts, credentials, or private diagnostics to an issue.

## Documentation

- [Installation & Source Builds](docs/INSTALL.md)
- [Privacy & Local Data](docs/PRIVACY.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)

The static product website lives in [`website/`](website/). It has no build step, analytics, cookies, external scripts, or runtime package dependencies. GitHub and download controls remain disabled until real release URLs pass review.

## License

Flowtype software and project-provided assets are licensed under [`GPL-3.0-only`](LICENSE) to the extent the project can grant those rights. Exceptions for third-party components, assets, and marks are documented in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), [ASSET_PROVENANCE.md](ASSET_PROVENANCE.md), and [TRADEMARKS.md](TRADEMARKS.md).
