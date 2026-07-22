# Flowtype

[English](README.en.md) · 简体中文

> **Release status:** 公开源码与 CI 已上线。面向普通用户的 DMG 已完成本地 packaging verification，但在取得 Developer ID signing 与 Apple notarization 前不会冒充无警告的正式安装包。

[GitHub Repository](https://github.com/smgonthebeat/Flowtype) · [Releases](https://github.com/smgonthebeat/Flowtype/releases)

Flowtype 是一款 local-first macOS 听写工具。按住 `Fn` 说话，松开后完成本地转写，并把结果粘贴到刚才使用的 App 中。它重点处理中文、English、technical terms 与 spoken mathematics 混合出现的真实口述场景。

![Flowtype 作者的真实使用界面，展示 4,680 次听写、15 小时 19 分钟口述、24.6 万字和节省 60 小时 37 分钟](website/assets/flowtype-home-real-usage.png)

这不是 mock data。作者明确选择公开这张 2026-07-23 的真实使用截图：Flowtype 已完成 **4,680 次听写**、累计 **15 小时 19 分钟**口述、转写 **24.6 万字**，估算节省 **60 小时 37 分钟**。为保护隐私，下方转写历史已作强模糊处理；上方累计统计保持原始画面。它首先是作者每天在用的工具，然后才成为一个开源项目。

## 为什么做 Flowtype

普通听写工具很容易在中英混说、专业名词和数学表达上打断思路。Flowtype 的目标不是替你写作，而是尽量忠实、快速地把你已经说出来的内容落到光标处。

## 主要能力

- **按住即说，松开即贴：** 在当前 App 中使用 `Fn` 完成录音、转写和粘贴。
- **中英混合与专业词汇：** local Qwen3-ASR 配合可自定义的 terminology context。
- **口述数学：** 可把数学表达转换成 Unicode 或 LaTeX。
- **local-first：** 主引擎在 Apple Silicon 本机运行；不要求 cloud ASR subscription。
- **失败可恢复：** History、最多三条本地 retry recordings、模型状态和 diagnostics 帮助定位问题。
- **原生 macOS 体验：** menu bar、recording capsule、permissions onboarding 与 model management。

## 系统要求

- macOS 14 或以上；
- Apple Silicon Mac；
- Microphone 与 Accessibility permissions；
- Swift 5.9 或以上（仅从源码构建的 developers 需要）；
- 数 GB 可用存储与 unified memory，用于本地模型和 runtime。

首次准备本地模型时，Flowtype 会在取得确认后从 Hugging Face 下载 Qwen3-ASR model files。模型权重不在本仓库中，也不包含在源码 archive 中。

## 开始使用

普通用户不应该为了使用 Flowtype 安装 Swift 或自己编译。预编译 DMG 会在 Developer ID signing、Apple notarization 与 Gatekeeper verification 完成后发布到官方 [GitHub Releases](https://github.com/smgonthebeat/Flowtype/releases)。当前尚未开放可信的 public DMG；不要从非官方镜像下载。

以下命令只面向希望审阅或修改源码的 developers：

```bash
swift test
uv run --project Helpers/qwen-asr-helper --frozen pytest
make build
```

`make build` 会在 `.build/Flowtype.app` 生成本地 ad-hoc signed development bundle；它不等同于官方 distribution build。

## Privacy，不只是一句宣传语

- Qwen3-ASR transcription 通过仅监听 `127.0.0.1` 且带 session token 的本地 helper 完成。
- Apple Speech fallback 只有在设备支持 on-device recognition 时才会运行，并强制 `requiresOnDeviceRecognition`。
- Transcript History 默认在本机保存，默认上限为 100 条，可在 Settings 中关闭或调整。
- 启用 History 时，最近最多三条录音会保留在本机，供手动 retry；清空 History 同时清理这些 retry recordings。
- Model download 是明确的 network operation；website、source build 和日常 local transcription 不是同一件事。

完整说明见 [Privacy & Local Data](docs/PRIVACY.md)。提交 issue 时不要附上真实录音、transcript、credential 或 private diagnostics。

## 文档

- [安装与源码构建](docs/INSTALL.md)
- [Privacy 与本地数据](docs/PRIVACY.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)

产品网站位于 [`website/`](website/)。它没有 build step、analytics、cookies、external scripts 或 runtime package dependencies；GitHub control 已连接官方仓库，DMG control 会在可信 release artifact 完成后启用。

## License

Flowtype software 与 project-provided assets 在项目有权授予的范围内采用 [`GPL-3.0-only`](LICENSE)。Third-party components、assets 与 marks 的例外见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)、[ASSET_PROVENANCE.md](ASSET_PROVENANCE.md) 和 [TRADEMARKS.md](TRADEMARKS.md)。
