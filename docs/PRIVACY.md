# Privacy & Local Data

This document describes the current source behaviour. It is not a promise that third-party operating-system services, model hosts, or future releases never change.

## Transcription Paths

### Qwen3-ASR

The primary transcription path runs through a local Python helper:

- it binds to `127.0.0.1` on a dynamically selected port;
- app requests use a per-session authentication token;
- uploaded WAV data is written to a temporary file for local inference and that helper-side file is removed when the request finishes;
- the selected Qwen model runs locally through MLX on Apple Silicon.

Routine Qwen transcription does not require sending recordings to a cloud ASR endpoint.

### Apple Speech Fallback

The fallback path checks `supportsOnDeviceRecognition` and sets `requiresOnDeviceRecognition = true`. If on-device recognition is unavailable, that path fails instead of requesting server-side recognition.

## Network Operations

Flowtype is local-first, not universally offline:

- downloading or repairing a Qwen model contacts Hugging Face;
- installing Python dependencies during a source build may contact package indexes;
- opening external project links uses the user's browser.

The app asks for model-download consent before preparing a model. Model weights are not committed to this repository.

## Local Storage

Flowtype stores application data under the user's Application Support directory in a `Flowtype` folder. Current data can include:

- settings and model-download consent in macOS user defaults;
- local usage aggregates;
- `history.json` containing transcript history;
- `Recordings/` containing retry recordings;
- `Models/` containing Qwen model files;
- helper runtime files;
- generated diagnostics under `Diagnostics/`;
- one debug recording and its metadata under `Debug/` only when debug recording capture has been explicitly enabled.

## History And Recording Retention

- Transcript History is enabled by default.
- The default history limit is 100 entries and can be changed from 1 to 500.
- The ordinary temporary WAV is removed after every transcription task finishes, whether the task succeeds or fails.
- With History enabled, Flowtype copies only the most recent recordings needed for manual retry into a separate local retained-recording store.
- That store is continuously pruned to at most three recordings. A newer retained recording displaces an older one.
- Clearing History also removes all retained retry recordings.
- Debug recording capture is disabled by default; when enabled, the newest debug recording replaces the previous one.

Disabling future History storage does not by itself claim to erase every existing data class. Use the in-app clear controls and inspect the storage locations shown in Settings.

## Pasteboard And Accessibility

Accessibility permission is used to observe the `Fn` key and paste into the intended foreground process. Flowtype places the transcript on the macOS pasteboard as part of the paste flow. If the original target cannot be safely resolved, the app may fall back to copy-only behaviour.

## Diagnostics And Issue Reports

Generated diagnostics describe readiness, process state, timing, model selection, and failure provenance. They should still be reviewed before sharing.

Never attach any of the following to a public issue:

- real recordings or transcripts;
- credentials, tokens, private keys, or signing material;
- model caches or helper environments;
- unrelated Application Support data;
- diagnostics that have not been inspected and redacted.

For a dated comparison of processing location and retention claims across several dictation products, see [Local And Cloud Dictation Comparison](PRIVACY-COMPARISON.md). The comparison distinguishes cloud processing from cloud retention and does not claim that another input method uploads every keystroke.
