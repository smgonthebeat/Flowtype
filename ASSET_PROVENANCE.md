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

## First-Launch Guide Screenshots

The GitHub README uses three dated screenshots to explain the supported macOS
first-launch flow for the unnotarized Preview:

- `website/assets/first-launch-1-blocked.png` is a project-owner capture of the
  macOS dialog shown when Flowtype is first opened. Its reviewed SHA-256 is
  `e66519936bced2d4ae4e7a1208a19ac1080ed423b552c6e7c0a16c4022021f1b`.
- `website/assets/first-launch-2-open-anyway.png` is a project-owner capture of
  the Flowtype-specific Open Anyway control in macOS Privacy & Security. Its
  reviewed SHA-256 is
  `f2240eee602ebf5537b163b5b5eb8884fb7a33348e6fd0089533d5b00236f8e0`.
- `website/assets/first-launch-3-apple-guide.png` is a 2026-07-25 capture of
  Apple's Chinese-language Mac User Guide page, [Open a Mac app from an unknown
  developer](https://support.apple.com/zh-cn/guide/mac-help/mh40616/mac). Its
  reviewed SHA-256 is
  `97323658ca0f57c6c87a59b08939fecb6ce63ad9c593e25c99f1d4c221817af1`.

The project owner explicitly selected all three captures for publication. The
published PNGs retain the source pixels exactly while removing ancillary image
metadata. Automated tests lock their dimensions and content hashes and reject
text, EXIF, timestamp, or XMP chunks. No account name, transcript, recording,
credential, local path, or other user content is visible in the captures.

Apple owns the macOS interface, system icons, support-page content, Apple marks,
and any other Apple-provided material visible in these screenshots. The images
are reproduced only as a dated documentary aid and linked back to Apple's live
instructions. They are not offered under Flowtype's GPL license, and their use
does not imply Apple affiliation, sponsorship, notarization, or endorsement.

`Resources/DMGBackground.svg`, its exact 1×/2× rendered PNGs, and the combined
multi-resolution TIFF provide the Finder background for the
drag-to-Applications disk image. They contain only local project-created vector
shapes and bilingual installation text, with no script, remote content,
analytics, user data, or personal metadata.

## Promotional Motion Assets

`website/assets/flowtype-workflow.gif` is a deterministic palette-optimized
derivative of the owner-approved Flowtype launch animatic v3. The frozen source
is a 37-second, 1920×1080, native-60fps H.264 render with SHA-256
`dae857b5932ec40558d3556ecc68ad4a15c0af5f60347c249769196470434d23`.
The README derivative is 960×540 at 25fps with a 160-color adaptive palette.
It contains 925 frames, lasts 37.000 seconds, and is 11,987,401 bytes. Its
reviewed SHA-256 is
`74e04814e12652dc0244b1e99b9ebf6078f4c7017f8b918dec4351a1f26e3edf`.

The opening uses `macbook-fn-extraction-concept-v1.png`, SHA-256
`6716332d0ecbe0e12a57f6c59f01bf6a3702ec8033c42f97f6a6970b5942a7f4`.
On 2026-07-26 the owner explicitly attested that they own or have the right to
publish this asset and authorized its use in the Flowtype GitHub README. The
remaining film is rendered from local, editable Flowtype animation and product
UI sources. The public GIF contains no real transcript history, recording,
account identifier, private local path, or user data.

`website/assets/flowtype-workflow-quick.gif` preserves the earlier quick workflow
preview as a separate second README asset. It is a deterministic 1200×675, 25fps
derivative of the corrected 1920×1080, native-60fps silent master with SHA-256
`1493ad58c200c33ba012dd60250129bd077af83ccde67fcf4580e4f31d6826c7`.
It uses a fully synthetic recreation of
the public Codex `New chat` empty state as an ordinary third-party text target,
a synthetic demonstration sentence, and a Flowtype-branded closing frame that
references the canonical local app icon extracted from `Resources/Flowtype.icns`.
The complete icon preserves its white rounded tile and optically inset
microphone-waveform-speech-bubble mark. The GIF does not embed a screenshot,
real conversation, History text, Hotwords, recording, account identifier, or
local filesystem path. The Codex name and product mark identify the demonstrated
target app only; they do not imply an OpenAI integration, affiliation,
sponsorship, or endorsement. The GIF is 250 frames, lasts 10.000 seconds, and is
380,462 bytes. Its reviewed SHA-256 is
`2d439697850f80fb031e6d5dce291267bd6aa8a83502fdbeb552bad34a04fd75`.

The sound-on `Flowtype-GitHub-Promo.mp4` is published only as a GitHub Release
asset and is intentionally excluded from the source projection. It is a
10-second 1920×1080, native-60fps H.264/AAC rendering of the earlier reviewed
v4 visual source. It was intentionally not regenerated or replaced during the
later GIF-only app-icon fidelity correction requested by the owner. Its
soundtrack is generated procedurally from deterministic
FFmpeg sine and seeded pink-noise sources, with cues aligned to the `Fn` press,
local-transcription release, atomic paste, and closing resolve. It contains no
imported music, recording, or third-party SFX file. Input metadata and chapters
are stripped from the final container. The MP4 is 430,113 bytes. Its reviewed
SHA-256 is
`f971700db08fae1565f1741bddb3862c2fa05c504004747eb49547290fd392fb`.
This historical Release asset is no longer linked from either README and was
not changed, deleted, or used to derive the 37-second launch-film GIF.

The motion-design workflow and deterministic seek-render approach were adapted
from [Huashu Design](https://github.com/alchaincyf/huashu-design), distributed
under the MIT License. The visual includes a small `Created by Huashu-Design`
attribution after the completed workflow. Huashu source code, Node/Python
environments, browser binaries, FFmpeg binaries, music, and SFX are not included
in the public repository or the Flowtype app bundle.

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
