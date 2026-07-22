# Security Policy

## Reporting A Vulnerability

Do not disclose a suspected vulnerability in a public issue, discussion, pull
request, recording, transcript, or diagnostic attachment.

Use GitHub's **Report a vulnerability** private reporting flow for this
repository. Include:

- the affected Flowtype version or source commit;
- the relevant macOS version and hardware class;
- a minimal reproduction using synthetic data;
- the expected security or privacy boundary;
- the observed result and practical impact.

Do not include credentials, authentication values, private recordings, real
transcripts, unrelated user data, or destructive proof-of-concept steps.

If private vulnerability reporting is temporarily unavailable, open a public
issue containing no vulnerability details and ask the maintainer to provide a
private reporting channel.

## Scope

Security reports may cover the Swift application, local Qwen helper, model and
runtime management, audio retention, history and diagnostics storage, paste and
Accessibility behaviour, packaging, signing, or update boundaries.

Third-party dependencies should also be reported to their upstream maintainers
when the issue is not specific to Flowtype's integration.
