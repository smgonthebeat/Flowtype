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

### Changed

- Updated the local Apple Silicon ASR runtime from `mlx-qwen3-asr 0.3.3` to
  `0.3.5` after transcript-parity, latency, memory, helper, Swift, and packaging
  checks. This is a maintenance update for upstream memory-management and
  model-loading edge cases; it is not presented as an accuracy or performance
  improvement.
- Added a synthetic macOS TTS benchmark harness and unit-tested comparison
  metrics. Generated audio, raw transcripts, model files, and benchmark output
  remain excluded from the repository.

### Release Gate

- No public version tag, signed/notarized DMG, checksum, or installation verification has been published yet.
