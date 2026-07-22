# Troubleshooting

Start with Flowtype's **Setup & Status** view. It is designed to identify permissions, model, helper-runtime, and package-readiness problems without requiring private recordings.

## `Fn` Does Nothing

1. Confirm Accessibility permission is granted to the exact Flowtype build being used.
2. Confirm the app is still running in the menu bar.
3. Re-open Setup & Status after replacing or rebuilding the app, because macOS permissions may remain associated with an older binary identity.
4. Avoid changing system security settings or applying Gatekeeper-bypass commands.

## Recording Starts But No Transcript Appears

1. Check Microphone permission and the selected input device.
2. Open Models and confirm the selected Qwen model is downloaded and ready.
3. Allow the first model preparation to finish; the initial download and load are slower than later dictations.
4. If the local engine is unavailable, check whether Apple Speech on-device recognition is supported and authorized.

## Transcript Is Copied But Not Pasted

Flowtype intentionally falls back to copy-only when it cannot safely resolve or validate the original target app. Check Accessibility permission, bring the intended text field to the foreground, and retry. The transcript may already be on the pasteboard.

## Model Download Or Repair Fails

- Confirm the Mac has free disk space and normal network access to Hugging Face.
- Use the in-app model repair/reset controls instead of manually editing model-cache files.
- Do not commit or attach model files, `.venv`, or package caches to an issue.

## High Memory Use

Local ASR uses unified memory and can consume several gigabytes while a model is loaded. A single helper continuing to grow toward `10 GB+`, multiple helper processes, or a capsule stuck at `Transcribing...` should be treated as a bug.

Record the following before reporting it:

- Flowtype, `uv`, and helper Python RSS;
- whether more than one helper exists;
- selected model ID;
- recording duration and full/chunked strategy;
- whether memory is ordinary RSS or Metal/IOAccelerator unified memory when visible;
- swap pressure and whether the problem reproduces after a clean app restart.

Do not attach a real recording to a public report.

## Generate Diagnostics

Use the in-app diagnostics action. It writes a latest file and a timestamped snapshot under Flowtype's local `Diagnostics/` directory. Inspect and redact the file before sharing it.

For public issues, include only:

- Flowtype version or source commit;
- macOS version and Mac chip;
- source build or official release origin;
- synthetic reproduction steps;
- the smallest relevant, reviewed diagnostic excerpt.

Security-sensitive reports must use the private process in [SECURITY.md](../SECURITY.md).
