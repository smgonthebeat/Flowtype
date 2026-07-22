# Contributing To Flowtype

Thank you for helping improve Flowtype.

## Before Starting

For significant behaviour, architecture, privacy, packaging, or user-interface
changes, open an issue first. Small fixes and test improvements can be proposed
directly.

Never include real recordings, transcripts, credentials, private diagnostics,
personal paths, model caches, or Apple signing material in an issue or pull
request.

## Development Checks

Run the narrowest relevant tests first, then the shared suites:

```bash
swift test
uv run --project Helpers/qwen-asr-helper pytest
uv run --project script python -m unittest discover -s script/tests
```

For packaging changes, also build and verify the app bundle locally. Launching,
installing, signing for distribution, and notarizing are separate operations and
may require explicit macOS permissions or Apple Developer credentials.

## Public Projection Workflow

The public repository is produced from a private upstream source-of-truth using
a deterministic allowlist export. Contributors can submit ordinary issues and
pull requests to the public repository. Maintainers reproduce accepted changes
in the upstream repository before publishing the corresponding public update,
so a pull request may be rebased or replaced by an equivalent exported commit.

Do not edit generated release artifacts or commit build output, model files,
virtual environments, local configuration, or downloaded caches.

## Contribution License

By submitting a contribution, you agree that it may be distributed under the
repository's `GPL-3.0-only` license. You retain copyright in your contribution.
