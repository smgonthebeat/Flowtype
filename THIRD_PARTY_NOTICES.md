# Third-Party Notices

Flowtype uses and interoperates with third-party software, model weights, and
assets. The authoritative upstream license files control if this summary differs
from them.

## Bundled Or Referenced Components

| Component | Role | License | Distribution note |
| --- | --- | --- | --- |
| [Qwen3-ASR](https://github.com/QwenLM/Qwen3-ASR), [Qwen3-ASR-0.6B](https://huggingface.co/Qwen/Qwen3-ASR-0.6B/commit/5eb144179a02acc5e5ba31e748d22b0cf3e303b0), and [Qwen3-ASR-1.7B](https://huggingface.co/Qwen/Qwen3-ASR-1.7B/commit/7278e1e70fe206f11671096ffdd38061171dd6e5) | Local ASR models | Apache-2.0 | Model weights are downloaded separately at the pinned revisions linked here and are not stored in this repository. |
| [mlx-qwen3-asr](https://github.com/moona3k/mlx-qwen3-asr) | Apple Silicon Qwen3-ASR runtime | Apache-2.0 | Installed from the locked Python environment during local setup. |
| [MLX](https://github.com/ml-explore/mlx) | Apple Silicon array and Metal runtime | MIT | Installed as a Python dependency. |
| [uv](https://github.com/astral-sh/uv) | Reproducible Python environment manager | MIT OR Apache-2.0 | A release app bundle may include the uv executable; distributors must preserve its license notices. |
| [Qwen logo](https://commons.wikimedia.org/wiki/File:Qwen_Logo.svg) | Model-provider identification in the UI | Apache-2.0 | Copyright Alibaba Cloud; the mark may also be protected as a trademark. The bundled SVG is an icon-only crop derived from this source. |
| [Huashu Design](https://github.com/alchaincyf/huashu-design) | Motion-design method and deterministic render tooling used to produce the README workflow preview | MIT | No Huashu source, runtime, music, or SFX is bundled. The public GIF contains visible attribution, and the Release MP4 soundtrack is project-generated. |

Apple system frameworks linked by Flowtype are supplied by macOS and are not
included as third-party source in this repository.

## Locked Python Runtime Dependencies

The Qwen helper lockfile currently resolves the following packages. These are
normally installed on the user's Mac and are not committed as a `.venv` or
vendored into this source repository.

| Package | Locked version | Declared license metadata |
| --- | ---: | --- |
| annotated-doc | 0.0.4 | MIT |
| annotated-types | 0.7.0 | MIT |
| anyio | 4.13.0 | MIT |
| certifi | 2026.4.22 | MPL-2.0 |
| click | 8.3.3 | BSD-3-Clause |
| colorama | 0.4.6 | BSD-3-Clause |
| fastapi | 0.139.2 | MIT |
| filelock | 3.29.0 | MIT |
| fsspec | 2026.4.0 | BSD-3-Clause |
| h11 | 0.16.0 | MIT |
| hf-xet | 1.4.3 | Apache-2.0 |
| httpcore | 1.0.9 | BSD-3-Clause |
| httpx | 0.28.1 | BSD-3-Clause |
| huggingface-hub | 1.13.0 | Apache-2.0 |
| idna | 3.18 | BSD-3-Clause |
| iniconfig | 2.3.0 | MIT |
| markdown-it-py | 4.0.0 | MIT |
| mdurl | 0.1.2 | MIT |
| mlx | 0.31.2 | MIT |
| mlx-metal | 0.31.2 | MIT |
| mlx-qwen3-asr | 0.3.5 | Apache-2.0 |
| numpy | 2.4.4 | BSD-3-Clause AND 0BSD AND MIT AND Zlib AND CC0-1.0 |
| packaging | 26.2 | Apache-2.0 OR BSD-2-Clause |
| pluggy | 1.6.0 | MIT |
| pydantic | 2.13.3 | MIT |
| pydantic-core | 2.46.3 | MIT |
| Pygments | 2.20.0 | BSD-2-Clause |
| pytest | 9.0.3 | MIT |
| python-multipart | 0.0.32 | Apache-2.0 |
| PyYAML | 6.0.3 | MIT |
| regex | 2026.4.4 | Apache-2.0 AND CNRI-Python |
| rich | 15.0.0 | MIT |
| shellingham | 1.5.4 | ISC |
| starlette | 1.3.1 | BSD-3-Clause |
| tqdm | 4.67.3 | MPL-2.0 AND MIT |
| typer | 0.25.1 | MIT |
| typing-inspection | 0.4.2 | MIT |
| typing-extensions | 4.15.0 | PSF-2.0 |
| uvicorn | 0.46.0 | BSD-3-Clause |

This inventory was generated from the environment resolved by
`Helpers/qwen-asr-helper/uv.lock`. Dev/test-only packages are included because
they may be installed by contributors. Review the upstream license and notice
files again whenever the lockfile changes and before distributing a bundled
Python environment.
