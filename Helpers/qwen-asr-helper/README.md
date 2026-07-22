# Qwen ASR Helper

Local Qwen3-ASR helper service for Flowtype.

## Development

```sh
uv sync --project Helpers/qwen-asr-helper
uv run --project Helpers/qwen-asr-helper pytest
VOICEINPUT_HELPER_TOKEN=flowtype-dev-token \
  uv run --project Helpers/qwen-asr-helper qwen-asr-helper
```

## Smoke Test

In another terminal, check the helper status:

```sh
curl -H 'X-VoiceInput-Token: flowtype-dev-token' http://127.0.0.1:8765/health
curl -H 'X-VoiceInput-Token: flowtype-dev-token' http://127.0.0.1:8765/models/status
```

Expected responses:

```json
{"ok":true,"engine":"qwen3-asr-mlx"}
```

```json
{"installed":true,"loaded":false,"model_id":"Qwen/Qwen3-ASR-0.6B"}
```

Transcribe a local wav file:

```sh
curl -X POST http://127.0.0.1:8765/transcribe \
  -H 'X-VoiceInput-Token: flowtype-dev-token' \
  -F "audio=@/path/to/sample.wav;type=audio/wav"
```

Expected response:

```json
{"text":"..."}
```

The first real transcription may download the Qwen3-ASR model weights and can take a while.
