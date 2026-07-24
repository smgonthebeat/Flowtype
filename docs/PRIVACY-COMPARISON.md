# Local And Cloud Dictation Comparison

Last reviewed: 2026-07-25

This document compares processing location and disclosed retention behaviour. It is not a security ranking, legal opinion, or allegation that another product uploads every keystroke. Product behaviour and policies can change; follow the dated sources and verify the current settings before handling sensitive material.

## 中文摘要

很多语音输入工具会把录音发送到云端完成识别，再通过加密、即时删除、Privacy Mode 或 zero-retention policy 降低风险。这些措施有价值，但它们仍然要求远端服务在处理时接触语音，部分产品还会处理当前应用或相关文本上下文。

Flowtype 采用不同的 trust boundary：默认 Qwen3-ASR 在 Apple Silicon 本机运行，录音只发送到 `127.0.0.1` local helper。普通临时 WAV 在转写任务结束后删除；开启 History 时，仅为手动重试在本机滚动保留最近最多 3 条录音，清空 History 会同时清除这些录音。

因此，更准确的区别是：**部分产品通过云端处理后的删除与控制来保护隐私；Flowtype 让日常转写从一开始就不需要进入云端 ASR。**

## At A Glance

| Product / reviewed scope | Where reviewed voice transcription runs | Retention or control described by the product | Evidence boundary |
| --- | --- | --- | --- |
| Flowtype `v0.1.0-preview.4` and current public source | Local Qwen3-ASR through a loopback-only helper; Apple fallback requires on-device recognition | Temporary WAV removed after the task; at most three local retry recordings when History is enabled; local History can be disabled, limited, or cleared | Open source and project tests; model download/repair still uses the network |
| Qianwen IME privacy policy, published 2026-06-26 | Voice is encrypted and sent to servers for ASR and LLM processing | Server audio is described as deleted within a “reasonable period”; ordinary keyboard input is described as local by default | Policy statement; it does not prove that every typed character is uploaded |
| Doubao IME for macOS `0.9.0`, inspected 2026-05-12 | Static bundle evidence showed cloud streaming ASR endpoints and cloud/context request APIs | Retention was not established by the static inspection | Architecture/capability evidence, not a packet-level claim about every runtime event |
| [Typeless, policy reviewed 2026-07-25](https://www.typeless.com/privacy) | Audio and limited contextual information are processed on cloud servers | Officially described zero-retention path: content is discarded after the result returns | Cloud processing with a stated retention control; not on-device transcription |
| [Wispr Flow, FAQ reviewed 2026-07-25](https://docs.wisprflow.ai/articles/3467817258-security-and-compliance-faq) | Audio is processed server-side; the provider must decrypt it for transcription | Privacy Mode governs model training; Cloud Sync governs server storage; both controls together provide its strongest zero-data-retention configuration | Settings and defaults vary by plan; current documentation says standard/trial data may be used for improvement when Privacy Mode is off |
| [Shandianshuo, privacy page reviewed 2026-07-25](https://shandianshuo.cn/privacy-first) | A local SenseVoice path can run offline; optional self-hosted or membership model paths may use external services | Local knowledge, memory, dictionary, and configuration are described as device-resident; cloud paths depend on the selected provider | Local-capable peer, not a cloud-only product |

The Qianwen IME policy referenced above is the product-specific document titled *Qianwen IME Privacy Policy* (`千问输入法隐私政策`), publication date 2026-06-26. The broader official [Qianwen product privacy policy](https://terms.alicdn.com/legal-agreement/terms/privacy_policy_full/20231011201849846/20231011201849846.html) also describes encrypted server processing for AI text and voice inputs, but it is not a substitute for the IME-specific policy.

The Doubao row comes from a dated static inspection of the macOS `0.9.0` application bundle. The current official [Doubao privacy policy](https://www.doubao.com/legal/privacy) covers the wider Doubao service and may not describe every IME-specific code path. The comparison therefore labels the evidence type instead of presenting static capability as proof of every network event.

## Why “Deleted After Processing” Is Not The Same As Local

Encryption in transit and immediate deletion can materially reduce risk. They do not remove the processing trust boundary: a cloud transcription service still receives and decrypts audio long enough to produce text. A local ASR path avoids exposing routine recordings to that remote processor.

This distinction should not be exaggerated:

- cloud processing is not the same as indefinite cloud storage;
- zero retention is not the same as zero processing;
- the presence of an input-method capability is not proof that all typed text is uploaded;
- local processing does not eliminate risks from malware, local backups, other user accounts, or deliberately retained local history;
- Flowtype is not universally offline because model download and repair require network access.

## Flowtype's Current Data Lifecycle

1. Flowtype records a temporary WAV on the Mac.
2. The app sends it to an authenticated helper bound to `127.0.0.1`.
3. Qwen3-ASR runs locally through MLX on Apple Silicon.
4. The helper's temporary upload file is removed when inference finishes.
5. The app's ordinary temporary WAV is removed when the transcription task ends.
6. If History is enabled, Flowtype may copy a recording into the local retry store. That store is continuously pruned to at most three recordings.
7. Clearing History removes transcript History and all retained retry recordings.

See [Privacy & Local Data](PRIVACY.md) and [Architecture](ARCHITECTURE.md) for the source-level boundaries.

## Trademark And Independence Notice

Wispr Flow, Typeless, Qianwen, Doubao, Shandianshuo, Apple, macOS, Qwen, and all other third-party names and marks belong to their respective owners. They are used only for truthful product identification. No comparison implies affiliation, sponsorship, or endorsement.
