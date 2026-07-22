# Flowtype Website

This directory contains Flowtype's static product website. It has no build step,
analytics, cookies, external scripts, or runtime package dependencies.

Preview it locally from the repository root:

```bash
python3 -m http.server 8000 --directory website
```

Then open `http://localhost:8000/`. Add `?static` to force animations into a
finished state for deterministic screenshots.

## Release Links

The GitHub and download controls intentionally remain non-interactive until the
first public repository and validated release artifact exist. Before deploying
the site:

1. Replace the pending controls with the real public repository and release
   URLs.
2. Verify the released DMG, SHA-256, signing/notarization status, Gatekeeper
   behaviour, and installation instructions.
3. Run the public website audit tests and inspect the rendered desktop and
   mobile layouts.

Do not add analytics, third-party scripts, personal contact details, or a
download URL without an explicit release review.
