# Changelog

All notable public changes to Flowtype will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and public releases will use semantic version tags where practical.

## [Unreleased]

### Added

- Public source, tests, deterministic bundle assembly, and a static product website.
- Local Qwen3-ASR transcription with Apple Speech on-device fallback.
- Chinese-English mixed dictation, terminology context, and spoken-math formatting.
- Local History, retry recovery, model management, readiness checks, and diagnostics.
- Chinese and English repository documentation plus GitHub community templates.
- An owner-approved real-use homepage capture documenting 4,680 dictations and
  60 hours 37 minutes of estimated time saved before the first binary release;
  transcript-history rows are heavily blurred for privacy.

### Changed

- Updated the local Apple Silicon ASR runtime from `mlx-qwen3-asr 0.3.3` to
  `0.3.5` after transcript-parity, latency, memory, helper, Swift, and packaging
  checks. This is a maintenance update for upstream memory-management and
  model-loading edge cases; it is not presented as an accuracy or performance
  improvement.
- Added a synthetic macOS TTS benchmark harness and unit-tested comparison
  metrics. Generated audio, raw transcripts, model files, and benchmark output
  remain excluded from the repository.

### Preview Release

- The public GitHub repository and hosted CI are live.
- `v0.1.0-preview.2` keeps the same app functionality as Preview 1 while adding
  a compact Retina Finder installer with 144-point icons, a centred drag arrow,
  and clear bilingual drag-to-Applications guidance.
- `v0.1.0-preview.1` publishes the locally verified Apple Silicon DMG and
  SHA-256 checksum as a GitHub Pre-release.
- The Preview uses a local development signature and is not notarized by Apple;
  first-open instructions use macOS Privacy & Security → Open Anyway without
  disabling Gatekeeper or removing quarantine attributes.
