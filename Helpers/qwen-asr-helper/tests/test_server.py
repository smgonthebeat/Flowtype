from pathlib import Path
from types import SimpleNamespace
import math
import struct
import threading
import time
import wave

import pytest
from fastapi.testclient import TestClient

from qwen_asr_helper import server

TEST_HELPER_TOKEN = "test-helper-token"


def authenticated_client() -> TestClient:
    return TestClient(
        server.app,
        headers={"X-VoiceInput-Token": TEST_HELPER_TOKEN},
    )


def write_test_wav(path: Path, parts: list[tuple[float, int]], sample_rate: int = 16_000) -> None:
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        frames = bytearray()
        for duration, amplitude in parts:
            sample_count = int(duration * sample_rate)
            for index in range(sample_count):
                value = int(amplitude * math.sin(index / 8.0)) if amplitude else 0
                frames.extend(struct.pack("<h", value))
        handle.writeframes(bytes(frames))


@pytest.fixture(autouse=True)
def reset_helper_state(monkeypatch):
    monkeypatch.setenv("VOICEINPUT_HELPER_TOKEN", TEST_HELPER_TOKEN)
    monkeypatch.setattr(server, "_session", None)
    monkeypatch.setattr(server, "_session_model_id", None)
    monkeypatch.setattr(server, "_session_loading", False)
    monkeypatch.setattr(server, "_session_loading_model_id", None)
    server._model_downloads.clear()


def test_health():
    client = authenticated_client()

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["ok"] is True


def test_models_status_reports_real_helper_unloaded(monkeypatch, tmp_path):
    monkeypatch.setenv("VOICEINPUT_MODELS_ROOT", str(tmp_path))
    client = authenticated_client()

    response = client.get("/models/status")

    assert response.status_code == 200
    assert response.json()["installed"] is False
    assert response.json()["loaded"] is False
    assert response.json()["loading"] is False
    assert response.json()["downloading"] is False
    assert response.json()["progress"] is None
    assert response.json()["phase"] == "absent"
    assert response.json()["error_code"] is None
    assert response.json()["operation_id"] is None
    assert isinstance(response.json()["updated_at"], float)
    assert response.json()["model_id"] == "Qwen/Qwen3-ASR-0.6B"
    assert response.json()["model_path"] == str(tmp_path / "qwen3-asr-0.6b")


def test_models_status_uses_voiceinput_model_root(monkeypatch, tmp_path):
    monkeypatch.setenv("VOICEINPUT_MODELS_ROOT", str(tmp_path))
    client = authenticated_client()

    response = client.get("/models/status")

    assert response.status_code == 200
    assert response.json()["model_path"] == str(tmp_path / "qwen3-asr-0.6b")


def test_models_status_reports_valid_cached_model_installed(monkeypatch, tmp_path):
    snapshot_dir = (
        tmp_path
        / "qwen3-asr-0.6b"
        / "huggingface"
        / "hub"
        / "models--Qwen--Qwen3-ASR-0.6B"
        / "snapshots"
        / server.MODEL_REVISIONS["Qwen/Qwen3-ASR-0.6B"]
    )
    snapshot_dir.mkdir(parents=True)
    (snapshot_dir / "config.json").write_text("{}", encoding="utf-8")
    (snapshot_dir / "model.safetensors").write_bytes(b"weights")
    monkeypatch.setenv("VOICEINPUT_MODELS_ROOT", str(tmp_path))
    client = authenticated_client()

    response = client.get("/models/status")

    assert response.status_code == 200
    assert response.json()["installed"] is True
    assert response.json()["loaded"] is False


def test_models_status_rejects_partial_cached_snapshot(monkeypatch, tmp_path):
    snapshot_dir = (
        tmp_path
        / "qwen3-asr-0.6b"
        / "huggingface"
        / "hub"
        / "models--Qwen--Qwen3-ASR-0.6B"
        / "snapshots"
        / server.MODEL_REVISIONS["Qwen/Qwen3-ASR-0.6B"]
    )
    snapshot_dir.mkdir(parents=True)
    (snapshot_dir / "config.json").write_text("{}", encoding="utf-8")
    monkeypatch.setenv("VOICEINPUT_MODELS_ROOT", str(tmp_path))
    client = authenticated_client()

    response = client.get("/models/status")

    assert response.status_code == 200
    assert response.json()["installed"] is False
    assert response.json()["loaded"] is False


def test_download_starts_session_load_and_reports_model_path(monkeypatch, tmp_path):
    created = []

    class FakeSession:
        def __init__(self, model: str):
            self.model = model
            created.append(self)

    def immediate_submit(fn, *args, **kwargs):
        fn(*args, **kwargs)

    monkeypatch.setenv("VOICEINPUT_MODELS_ROOT", str(tmp_path))
    monkeypatch.setattr(server, "Session", FakeSession)
    monkeypatch.setattr(server, "submit_mlx", immediate_submit)
    snapshot_path = tmp_path / "qwen3-asr-1.7b" / "huggingface" / "hub" / "snapshot"
    monkeypatch.setattr(server, "local_model_source", lambda model_id: str(snapshot_path))
    client = authenticated_client()

    response = client.post("/models/download", params={"model_id": "Qwen/Qwen3-ASR-1.7B"})

    assert response.status_code == 200
    assert response.json()["installed"] is True
    assert response.json()["loaded"] is True
    assert response.json()["progress"] == 1.0
    assert response.json()["phase"] == "ready"
    assert response.json()["operation_id"] is not None
    assert response.json()["model_path"] == str(tmp_path / "qwen3-asr-1.7b")
    assert created[0].model == str(snapshot_path)


def test_download_requests_are_single_flight_before_worker_starts(monkeypatch, tmp_path):
    submitted = []

    def deferred_submit(fn, *args, **kwargs):
        submitted.append((fn, args, kwargs))

    monkeypatch.setenv("VOICEINPUT_MODELS_ROOT", str(tmp_path))
    monkeypatch.setattr(server, "submit_mlx", deferred_submit)
    client = authenticated_client()

    first = client.post("/models/download")
    second = client.post("/models/download")

    assert first.status_code == 200
    assert second.status_code == 200
    assert len(submitted) == 1
    assert first.json()["operation_id"] == second.json()["operation_id"]
    assert first.json()["phase"] == "loading"


def test_background_preparation_failure_is_visible_as_typed_status(monkeypatch, tmp_path):
    def immediate_submit(fn, *args, **kwargs):
        fn(*args, **kwargs)

    monkeypatch.setenv("VOICEINPUT_MODELS_ROOT", str(tmp_path))
    monkeypatch.setattr(server, "submit_mlx", immediate_submit)
    monkeypatch.setattr(
        server,
        "local_model_source",
        lambda model_id: (_ for _ in ()).throw(ConnectionError("private raw network detail")),
    )
    client = authenticated_client()

    response = client.post("/models/download")

    assert response.status_code == 200
    assert response.json()["phase"] == "failed"
    assert response.json()["error_code"] == "network_unavailable"
    assert "private raw network detail" not in response.text


def test_get_session_imports_lazily_and_reuses_session(monkeypatch):
    created = []

    class FakeSession:
        def __init__(self, model: str):
            self.model = model
            created.append(self)

    monkeypatch.setattr(server, "Session", FakeSession)
    monkeypatch.setattr(server, "local_model_source", lambda model_id: f"/tmp/{model_id}")

    first = server.get_session("Qwen/Qwen3-ASR-0.6B")
    second = server.get_session("Qwen/Qwen3-ASR-0.6B")

    assert first is second
    assert first.model == "/tmp/Qwen/Qwen3-ASR-0.6B"
    assert created == [first]


def test_models_status_reports_download_progress(monkeypatch, tmp_path):
    blobs_dir = (
        tmp_path
        / "qwen3-asr-1.7b"
        / "huggingface"
        / "hub"
        / "models--Qwen--Qwen3-ASR-1.7B"
        / "blobs"
    )
    blobs_dir.mkdir(parents=True)
    (blobs_dir / "partial").write_bytes(b"x" * 25)
    server._model_downloads["Qwen/Qwen3-ASR-1.7B"] = server.DownloadState(
        downloading=True,
        total_bytes=100,
    )
    monkeypatch.setenv("VOICEINPUT_MODELS_ROOT", str(tmp_path))
    client = authenticated_client()

    response = client.get("/models/status", params={"model_id": "Qwen/Qwen3-ASR-1.7B"})

    assert response.status_code == 200
    assert response.json()["downloading"] is True
    assert response.json()["progress"] == 0.25


def test_download_progress_tqdm_updates_state(monkeypatch, tmp_path):
    model_id = "Qwen/Qwen3-ASR-1.7B"
    state = server.download_state(model_id)
    progress_class = server.download_progress_tqdm_class(model_id, state)
    monkeypatch.setenv("VOICEINPUT_MODELS_ROOT", str(tmp_path))

    with progress_class(total=100, unit="B") as progress:
        progress.update(40)

    assert state.total_bytes == 100
    assert state.downloaded_bytes == 40
    assert server.download_progress(model_id, installed=False, loaded=False) == 0.4


def test_download_progress_tqdm_combines_cached_bytes_with_active_file(monkeypatch, tmp_path):
    model_id = "Qwen/Qwen3-ASR-1.7B"
    blobs_dir = (
        tmp_path
        / "qwen3-asr-1.7b"
        / "huggingface"
        / "hub"
        / "models--Qwen--Qwen3-ASR-1.7B"
        / "blobs"
    )
    blobs_dir.mkdir(parents=True)
    (blobs_dir / "completed").write_bytes(b"x" * 30)
    state = server.download_state(model_id)
    state.total_bytes = 100
    progress_class = server.download_progress_tqdm_class(model_id, state)
    monkeypatch.setenv("VOICEINPUT_MODELS_ROOT", str(tmp_path))

    with progress_class(total=100, unit="B") as progress:
        progress.update(40)

    assert state.downloaded_bytes == 70
    assert server.download_progress(model_id, installed=False, loaded=False) == 0.7


def test_download_snapshot_uses_pinned_revision_and_requested_model_cache_dir(monkeypatch, tmp_path):
    captured = {}

    def fake_snapshot_download(repo_id, revision, cache_dir, allow_patterns, tqdm_class):
        captured["repo_id"] = repo_id
        captured["revision"] = revision
        captured["cache_dir"] = cache_dir
        captured["allow_patterns"] = allow_patterns
        captured["tqdm_class"] = tqdm_class
        snapshot_dir = Path(cache_dir) / "models--Qwen--Qwen3-ASR-1.7B" / "snapshots" / "fake"
        snapshot_dir.mkdir(parents=True)
        return str(snapshot_dir)

    monkeypatch.setenv("VOICEINPUT_MODELS_ROOT", str(tmp_path))
    monkeypatch.setattr(server, "expected_model_bytes", lambda model_id: 100)
    monkeypatch.setattr("huggingface_hub.snapshot_download", fake_snapshot_download)

    path = server.download_model_snapshot("Qwen/Qwen3-ASR-1.7B")

    assert path == tmp_path / "qwen3-asr-1.7b" / "huggingface" / "hub" / "models--Qwen--Qwen3-ASR-1.7B" / "snapshots" / "fake"
    assert captured["repo_id"] == "Qwen/Qwen3-ASR-1.7B"
    assert captured["revision"] == server.MODEL_REVISIONS["Qwen/Qwen3-ASR-1.7B"]
    assert captured["cache_dir"] == str(tmp_path / "qwen3-asr-1.7b" / "huggingface" / "hub")
    assert captured["allow_patterns"] == server.MODEL_ALLOW_PATTERNS
    assert captured["tqdm_class"].__name__ == "DownloadProgressTqdm_qwen3-asr-1.7b"


def test_models_status_rejects_unsupported_model_id():
    client = authenticated_client()

    response = client.get("/models/status", params={"model_id": "example/untrusted-model"})

    assert response.status_code == 400
    assert response.json()["detail"] == "Unsupported model ID"


def test_transcribe_wav_uses_session_with_temp_file(monkeypatch, tmp_path):
    client = authenticated_client()
    audio_path = tmp_path / "sample.wav"
    audio_path.write_bytes(b"RIFF")
    seen = {}

    class FakeSession:
        def transcribe(self, path: str, **kwargs):
            temp_path = Path(path)
            seen["suffix"] = temp_path.suffix
            seen["bytes"] = temp_path.read_bytes()
            return SimpleNamespace(text="  real transcript  ")

    monkeypatch.setattr(server, "get_session", lambda model_id=None: FakeSession())

    with audio_path.open("rb") as handle:
        response = client.post(
            "/transcribe",
            files={"audio": ("sample.wav", handle, "audio/wav")},
        )

    assert response.status_code == 200
    assert response.json()["text"] == "real transcript"
    assert seen == {"suffix": ".wav", "bytes": b"RIFF"}


def test_http_preload_and_transcribe_use_same_mlx_worker_thread(monkeypatch, tmp_path):
    created_thread_ids = []
    transcribe_thread_ids = []

    class FakeSession:
        def __init__(self, model: str):
            self.model = model
            created_thread_ids.append(threading.get_ident())

        def transcribe(self, path: str, **kwargs):
            current_thread_id = threading.get_ident()
            transcribe_thread_ids.append(current_thread_id)
            if current_thread_id != created_thread_ids[0]:
                raise RuntimeError("There is no Stream(gpu, 1) in current thread.")
            return SimpleNamespace(text="thread safe transcript")

    monkeypatch.setenv("VOICEINPUT_MODELS_ROOT", str(tmp_path))
    monkeypatch.setattr(server, "Session", FakeSession)
    monkeypatch.setattr(server, "local_model_source", lambda model_id: f"/tmp/{model_id}")
    client = authenticated_client()

    download_response = client.post("/models/download")
    assert download_response.status_code == 200

    deadline = time.monotonic() + 1
    while server._session is None and time.monotonic() < deadline:
        time.sleep(0.01)
    assert server._session is not None

    wav_path = tmp_path / "audio.wav"
    wav_path.write_bytes(b"RIFFfake")
    with wav_path.open("rb") as handle:
        transcribe_response = client.post(
            "/transcribe",
            files={"audio": ("audio.wav", handle, "audio/wav")},
        )

    assert transcribe_response.status_code == 200
    assert transcribe_response.json() == {"text": "thread safe transcript"}
    assert created_thread_ids == transcribe_thread_ids


def test_transcribe_long_wav_splits_on_silence(monkeypatch, tmp_path):
    wav_path = tmp_path / "long.wav"
    write_test_wav(
        wav_path,
        [
            (4.0, 1_000),
            (1.2, 0),
            (4.0, 1_000),
            (4.0, 0),
        ],
    )
    seen_durations = []

    class FakeSession:
        def transcribe(self, path: str, **kwargs):
            with wave.open(path, "rb") as handle:
                seen_durations.append(handle.getnframes() / handle.getframerate())
            return SimpleNamespace(text=f"part{len(seen_durations)}")

    monkeypatch.setattr(server, "get_session", lambda model_id=None: FakeSession())

    text = server.transcribe_file(str(wav_path), "Qwen/Qwen3-ASR-0.6B", strategy="chunked")

    assert text == "part1 part2"
    assert len(seen_durations) == 2
    assert all(duration < 5 for duration in seen_durations)


def test_transcribe_long_wav_defaults_to_full_file(monkeypatch, tmp_path):
    wav_path = tmp_path / "long.wav"
    write_test_wav(wav_path, [(4.0, 1_000), (1.2, 0), (4.0, 1_000), (4.0, 0)])
    seen_durations = []

    class FakeSession:
        def transcribe(self, path: str, **kwargs):
            with wave.open(path, "rb") as handle:
                seen_durations.append(handle.getnframes() / handle.getframerate())
            return SimpleNamespace(text="full transcript")

    monkeypatch.setattr(server, "get_session", lambda model_id=None: FakeSession())

    text = server.transcribe_file(str(wav_path), "Qwen/Qwen3-ASR-0.6B")

    assert text == "full transcript"
    assert len(seen_durations) == 1
    assert seen_durations[0] > 12


def test_join_transcript_segments_uses_soft_chinese_comma_for_cjk_boundary():
    assert server.join_transcript_segments(["我今天讲这个", "请打开 Sheet 1"]) == "我今天讲这个，请打开 Sheet 1"


def test_join_transcript_segments_uses_spaces_for_mixed_cjk_ascii_boundaries():
    assert server.join_transcript_segments(["我今天讲", "DEMO1001"]) == "我今天讲 DEMO1001"
    assert server.join_transcript_segments(["open", "文件"]) == "open 文件"


def test_join_transcript_segments_uses_spaces_for_ascii_word_boundaries():
    assert server.join_transcript_segments(["hello", "world"]) == "hello world"


def test_join_transcript_segments_preserves_existing_sentence_punctuation():
    assert server.join_transcript_segments(["你好。", "请继续"]) == "你好。请继续"
    assert server.join_transcript_segments(["First sentence.", "Second sentence"]) == "First sentence.Second sentence"
    assert server.join_transcript_segments(["3.", "14"]) == "3.14"
    assert server.join_transcript_segments(["v1.", "2"]) == "v1.2"
    assert server.join_transcript_segments(["example.", "com"]) == "example.com"


def test_join_transcript_segments_does_not_synthesize_hard_stop_between_cjk_chunks():
    result = server.join_transcript_segments(["你看", "他自己写了一个 draft"])

    assert result == "你看，他自己写了一个 draft"
    assert "你看。他" not in result


def test_transcribe_passes_context_to_session(monkeypatch, tmp_path):
    client = authenticated_client()
    captured = {}

    class FakeResult:
        text = "Claude Code"

    class FakeSession:
        def transcribe(self, path: str, **kwargs):
            captured["context"] = kwargs.get("context")
            return FakeResult()

    monkeypatch.setattr(server, "get_session", lambda model_id=None: FakeSession())
    wav_path = tmp_path / "audio.wav"
    wav_path.write_bytes(b"RIFFfake")

    with wav_path.open("rb") as handle:
        response = client.post(
            "/transcribe",
            files={"audio": ("audio.wav", handle, "audio/wav")},
            data={
                "model_id": "Qwen/Qwen3-ASR-1.7B",
                "context": "Important terms to preserve exactly: Claude Code."
            },
        )

    assert response.status_code == 200
    assert response.json() == {"text": "Claude Code"}
    assert captured["context"] == "Important terms to preserve exactly: Claude Code."


def test_transcribe_passes_strategy_to_helper(monkeypatch, tmp_path):
    client = authenticated_client()
    captured = {}

    def fake_transcribe_file(path, model_id, context="", strategy="full"):
        captured["strategy"] = strategy
        return "chunked transcript"

    monkeypatch.setattr(server, "transcribe_file", fake_transcribe_file)
    wav_path = tmp_path / "audio.wav"
    wav_path.write_bytes(b"RIFFfake")

    with wav_path.open("rb") as handle:
        response = client.post(
            "/transcribe",
            files={"audio": ("audio.wav", handle, "audio/wav")},
            data={"strategy": "chunked"},
        )

    assert response.status_code == 200
    assert response.json() == {"text": "chunked transcript"}
    assert captured["strategy"] == "chunked"


def test_transcribe_reports_missing_resampler_clearly(monkeypatch, tmp_path):
    client = authenticated_client()
    wav_path = tmp_path / "audio.wav"
    wav_path.write_bytes(b"RIFFfake")

    def fail_transcription(path, model_id, context="", strategy="full"):
        raise RuntimeError("ffmpeg not found on PATH. Install and retry: brew install ffmpeg")

    monkeypatch.setattr(server, "transcribe_file", fail_transcription)

    with wav_path.open("rb") as handle:
        response = client.post(
            "/transcribe",
            files={"audio": ("audio.wav", handle, "audio/wav")},
        )

    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "audio_resampling_unavailable"


def test_transcribe_reports_empty_audio_clearly(monkeypatch, tmp_path):
    client = authenticated_client()
    wav_path = tmp_path / "audio.wav"
    wav_path.write_bytes(b"RIFFfake")

    def fail_transcription(path, model_id, context="", strategy="full"):
        raise ValueError("Cannot compute mel spectrogram of empty audio")

    monkeypatch.setattr(server, "transcribe_file", fail_transcription)

    with wav_path.open("rb") as handle:
        response = client.post(
            "/transcribe",
            files={"audio": ("audio.wav", handle, "audio/wav")},
        )

    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "empty_audio"


def test_transcribe_rejects_non_wav(tmp_path):
    client = authenticated_client()
    audio_path = tmp_path / "sample.mp3"
    audio_path.write_bytes(b"ID3")

    with audio_path.open("rb") as handle:
        response = client.post(
            "/transcribe",
            files={"audio": ("sample.mp3", handle, "audio/mpeg")},
        )

    assert response.status_code == 400


def test_transcribe_rejects_empty_wav(tmp_path):
    client = authenticated_client()
    audio_path = tmp_path / "empty.wav"
    audio_path.write_bytes(b"")

    with audio_path.open("rb") as handle:
        response = client.post(
            "/transcribe",
            files={"audio": ("empty.wav", handle, "audio/wav")},
        )

    assert response.status_code == 400


def test_auth_token_required_when_configured(monkeypatch):
    monkeypatch.setenv("VOICEINPUT_HELPER_TOKEN", "secret-token")
    client = TestClient(server.app)

    unauthorized = client.get("/health")
    authorized = client.get("/health", headers={"X-VoiceInput-Token": "secret-token"})

    assert unauthorized.status_code == 401
    assert authorized.status_code == 200


def test_authentication_fails_closed_when_token_is_not_configured(monkeypatch):
    monkeypatch.delenv("VOICEINPUT_HELPER_TOKEN")
    client = TestClient(server.app)

    response = client.get("/health")

    assert response.status_code == 503
    assert response.json()["detail"] == "Helper authentication is not configured"


def test_main_rejects_startup_without_authentication_token(monkeypatch):
    monkeypatch.delenv("VOICEINPUT_HELPER_TOKEN")

    with pytest.raises(RuntimeError, match="VOICEINPUT_HELPER_TOKEN must be set"):
        server.main()
