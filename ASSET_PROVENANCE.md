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
- `Resources/DMGBackground.svg`
- `Resources/DMGBackground.png`
- `Resources/DMGBackground@2x.png`
- `Resources/DMGBackground.tiff`
- `Resources/HomeCardArtwork-mic.png`
- `Resources/HomeCardArtwork-wave.png`
- `Resources/HomeCardArtwork-docs.png`
- `Resources/HomeCardArtwork-clock.png`
- `website/assets/download-apple-silicon.svg`

## Flowtype Dawn Theme Images

`Resources/FlowtypeBackdrop-topLeading.png` and
`Resources/FlowtypeBackdrop-bottomTrailing.png` are the corner light of the
Flowtype Dawn window background. They were cut from the colour field of the
same owner-created image-generation reference used for the app icon (see
below), with its line work removed; the reference image itself is not shipped.
`Resources/HomeCardArtwork-mic-light.png`, `-wave-light.png`, `-docs-light.png`
and `-clock-light.png` are light glass versions of the ChatGPT-generated Home
card artwork listed above, produced from those originals by a local
image-processing script without adding new generated content.

## README Images

The `website/assets/readme/*.webp` images shown in `README.md` and
`README.zh-CN.md` were produced locally from project-owned material only. The page
screenshots (`dictionary`, `models`, `onboarding`) are offscreen
renders of the Flowtype interface made by the project's own test harness, with
synthetic demo history, hotwords and statistics. The composed cards (`hero`,
`video`, `flow`, `stats`, `math`) are local HTML layouts rendered to images; they
combine the app icon, the Flowtype Dawn backdrop and Home card artwork above,
renders of the recording capsule and onboarding welcome picture, and text. The
`stats` cards carry the project owner's real aggregate usage as of 2026-10-12
(21,578 dictations, 63 hours 9 minutes dictated, 1,005,000 characters and words,
251 hours 37 minutes estimated saved), which the owner chose to publish; no
transcript content is shown. No new generated imagery was added.

The launch films linked near the top of both READMEs (English and Chinese, 57 s
each) are hosted as GitHub attachments, not stored in this repository. Their
picture was rendered entirely in code by the project owner's motion-graphics
pipeline (WebGL and Canvas2D in headless Chrome, ffmpeg) from the same
project-owned material: the Flowtype Dawn backdrop, app icon, interface
screenshots and the real usage figures above. No stock footage, generated video or
voice is used. The music is the opening of "Launch Impact", a track the project
owner generated with Suno on a paid plan; it is used unedited and is not part of
this repository or of its GPL-3.0 grant.

## App Icon

Since October 2026, `Resources/Flowtype.icns` is a new app icon. It was rendered
in Blender from the unchanged Flowtype glyph (`Resources/Flowtype-logo.svg`, see
above), a frosted glass body and a soft colour field. Its look was matched by
measurement to a reference image that the project owner created with an
image-generation tool and selected; the reference image itself is not shipped.
`website/assets/flowtype-app-icon.png` is a resized copy of the same 1024 px
render, used in the README images. The earlier app icon, a white rounded
tile carrying the black glyph, was also generated using ChatGPT.

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
not changed or deleted.

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
