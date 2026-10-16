# Changelog

All notable public changes to Flowtype will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and public releases will use semantic version tags where practical.

## [Unreleased]

### Added

- Public source, tests, and deterministic bundle assembly.
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
- `v0.1.0-preview.9` refreshes Home: the four stat cards get new Flowtype Dawn
  illustrations (a relit lightning badge, softer glass and a gentle glow),
  placed in the same frame in every theme, and the Apple theme uses them in
  light mode. The grey subtitle under the Home title is removed. Dictation
  behaviour is unchanged from Preview 8. The static website has been removed
  from the repository; the README is the project page.
- `v0.1.0-preview.8` introduces Flowtype Dawn, a light appearance and the new
  default theme: a clean white window with soft peach and sky light in the
  corners, white cards with a faint violet shadow, a peach-to-lilac-to-sky
  accent, and light glass stat-card artwork on Home. The recording capsule's
  waveform and transcribing dots follow the same gradient with a soft glow, and
  the onboarding recording illustrations match. New installs open in Flowtype
  Dawn; a theme you already chose is kept, and the Apple, Codex and Oscurange
  themes are unchanged. Dictation behaviour is unchanged from Preview 7.
- `v0.1.0-preview.7` introduces the new Flowtype app icon: a frosted glass tile
  with soft warm and blue light, carrying the same microphone, sound-wave and
  speech-bubble mark. The website and README use the same icon. App behaviour
  is unchanged from Preview 6.
- `v0.1.0-preview.6` rebuilds first run as an illustrated five-page guide:
  choose Chinese or English for the whole interface on the first page, prepare
  the model and permissions before continuing, then practise holding `Fn` on a
  drawn MacBook keyboard without pasting anywhere. The recording capsule shows a
  live waveform, a no-speech hint and a countdown near the recording limit.
  Interface text comes in three sizes (Settings or `⌘+` / `⌘−`), and the menu
  bar menu shows readiness. Help now covers basic use, common problems and a
  single **Check and copy diagnostics** action with contact links. Formatting
  gains spoken filler cleanup (on by default for new installs), rebuilt number,
  date, academic-reference and spoken-math handling, and paste now targets the
  app that owns keyboard focus. Long dictations no longer fail on an empty final
  chunk.
- `v0.1.0-preview.5` adds downloaded-byte, smoothed transfer-speed, and estimated
  time-remaining feedback to first-run model preparation. A completed setup now
  hands its verified readiness state directly to Home, so users are not asked
  to run **Prepare Flowtype** a second time merely to refresh the UI.
- `v0.1.0-preview.4` prevents Flowtype's internal ASR context and Hotword lists
  from being committed as transcripts, including truncated and Unicode-variant
  echoes. Model preparation now reports live byte-based progress, prefers the
  pinned ModelScope mirror for fresh downloads, resumes partial transfers,
  verifies every artifact, and retains Hugging Face fallback.
- `v0.1.0-preview.3` makes clean-install preparation a visible one-click flow:
  the first **Prepare Flowtype** action requests the required permissions,
  automatically downloads the approximately 1.9 GB default Qwen3-ASR 0.6B
  model, and shows download/preparation progress.
- `v0.1.0-preview.2` keeps the same app functionality as Preview 1 while adding
  a compact Retina Finder installer with 144-point icons, a centred drag arrow,
  and clear bilingual drag-to-Applications guidance.
- `v0.1.0-preview.1` publishes the locally verified Apple Silicon DMG and
  SHA-256 checksum as a GitHub Pre-release.
- The Preview uses a local development signature and is not notarized by Apple;
  first-open instructions use macOS Privacy & Security → Open Anyway without
  disabling Gatekeeper or removing quarantine attributes.
