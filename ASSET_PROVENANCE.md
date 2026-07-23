# Flowtype Asset Provenance

This document records the known origin of Flowtype-specific visual assets in
this repository. It is intended to make the public source projection
transparent; it is not a representation that generated material is unique or
eligible for copyright protection in every jurisdiction.

## ChatGPT-Generated Project Assets

The Flowtype project owner states that the following assets were generated
using OpenAI's ChatGPT and then selected for use in Flowtype:

- `Resources/Flowtype-button.svg`
- `Resources/Flowtype-logo.svg`
- `Resources/Flowtype-logo.png`
- `Resources/Flowtype.icns`
- `Resources/DMGBackground.svg`
- `Resources/DMGBackground.png`
- `Resources/DMGBackground@2x.png`
- `Resources/DMGBackground.tiff`
- `Resources/HomeCardArtwork-mic.png`
- `Resources/HomeCardArtwork-wave.png`
- `Resources/HomeCardArtwork-docs.png`
- `Resources/HomeCardArtwork-clock.png`
- `website/assets/download-apple-silicon.svg`

The static website embeds the Flowtype logo shape and includes
`website/assets/flowtype-home-real-usage.png`, a macOS screenshot captured by
the project owner from the Flowtype app. The owner explicitly selected its real
aggregate usage figures (4,680 dictations, 15 hours 19 minutes dictated,
246,000 characters, and 60 hours 37 minutes estimated saved) for publication as
evidence of first-party use. Those usage cards remain unchanged from the source
capture. The local transcript-history region is deliberately and heavily
blurred before publication so its text cannot be read.

A metadata audit found no high- or medium-risk image metadata, personal author,
account, GPS, source URL, or local filesystem path. The published derivative
has all ancillary PNG metadata removed and is locked by a SHA-256 contract
test. The blur was applied deterministically to the transcript panel only; the
entire area above that panel is pixel-identical to the source capture. No
generated or substituted UI is present in the published screenshot.

`website/assets/download-apple-silicon.svg` is a project-created static README
download control. It contains only local vector shapes and text, has no script,
remote image, analytics, or runtime dependency, and links to nothing by itself;
the surrounding README link supplies the official GitHub Release DMG URL. The
Apple name and symbol are used only to identify the supported Apple Silicon
platform and do not imply endorsement, as described in
[TRADEMARKS.md](TRADEMARKS.md).

`Resources/DMGBackground.svg`, its exact 1×/2× rendered PNGs, and the combined
multi-resolution TIFF provide the Finder background for the
drag-to-Applications disk image. They contain only local project-created vector
shapes and bilingual installation text, with no script, remote content,
analytics, user data, or personal metadata.

OpenAI's [Terms of Use](https://openai.com/policies/row-terms-of-use/), reviewed
on 2026-07-21, state that, as between a user and OpenAI and to the extent
permitted by applicable law, the user owns Output and OpenAI assigns any right,
title, and interest it may have in that Output to the user. The same terms state
that Output may not be unique and that other users may receive similar Output.

The project makes these files available under `GPL-3.0-only` to the extent it
can grant rights in them. This repository does not promise that the files are
exclusive, that copyright subsists in every jurisdiction, or that their use
cannot implicate third-party rights. The Flowtype name and source-identifying
marks remain subject to [TRADEMARKS.md](TRADEMARKS.md).

## Third-Party Assets

`Resources/Qwen-logo.svg` is not included in the ChatGPT-generated asset list.
Its upstream source, license information, and trademark caveat are recorded in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Provenance Changes

When an asset is added, replaced, or substantially modified, update this file
and the third-party notices before publishing a new release.
