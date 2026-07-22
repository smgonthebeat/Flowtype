import os
import secrets
import sys
import time
import uuid
import wave
from array import array
import asyncio
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from fnmatch import fnmatch
import gc
from functools import partial
from pathlib import Path
from tempfile import NamedTemporaryFile
from threading import Lock
from typing import Any

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, Query, UploadFile
import uvicorn

from qwen_asr_helper.schemas import (
    HealthResponse,
    ModelStatusResponse,
    TranscribeResponse,
)


DEFAULT_MODEL_ID = "Qwen/Qwen3-ASR-0.6B"
MODEL_REVISIONS = {
    "Qwen/Qwen3-ASR-0.6B": "5eb144179a02acc5e5ba31e748d22b0cf3e303b0",
    "Qwen/Qwen3-ASR-1.7B": "7278e1e70fe206f11671096ffdd38061171dd6e5",
}
MODEL_ALLOW_PATTERNS = ["*.json", "*.safetensors", "*.txt", "*.model"]
CHUNKED_TRANSCRIPTION_MIN_SECONDS = 12.0
SILENCE_WINDOW_SECONDS = 0.1
SILENCE_MERGE_SECONDS = 0.7
SEGMENT_PADDING_SECONDS = 0.25
MIN_SEGMENT_SECONDS = 0.35
MAX_SEGMENT_SECONDS = 10.0

app = FastAPI(title="Flowtype Qwen ASR Helper")
_session: Any | None = None
_session_model_id: str | None = None
_session_loading = False
_session_loading_model_id: str | None = None
_session_lock = Lock()
_transcribe_lock = Lock()
_download_lock = Lock()
_mlx_executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="flowtype-mlx")
Session: Any | None = None


@dataclass
class DownloadState:
    preparing: bool = False
    downloading: bool = False
    total_bytes: int | None = None
    downloaded_bytes: int = 0
    error: str | None = None
    error_code: str | None = None
    operation_id: str | None = None
    updated_at: float = 0.0
    snapshot_path: str | None = None


_model_downloads: dict[str, DownloadState] = {}


def submit_mlx(fn, *args, **kwargs):
    return _mlx_executor.submit(partial(fn, *args, **kwargs))


async def run_mlx(fn, *args, **kwargs):
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_mlx_executor, partial(fn, *args, **kwargs))


@dataclass(frozen=True)
class AudioSegment:
    start: float
    end: float


def requested_model_id(model_id: str | None = None) -> str:
    if model_id:
        return model_id
    return os.environ.get("VOICEINPUT_MODEL_ID", DEFAULT_MODEL_ID)


def model_revision(model_id: str) -> str:
    try:
        return MODEL_REVISIONS[model_id]
    except KeyError as exc:
        raise ValueError(f"Unsupported model ID: {model_id}") from exc


def require_supported_model_id(model_id: str) -> None:
    if model_id not in MODEL_REVISIONS:
        raise HTTPException(status_code=400, detail="Unsupported model ID")


def model_directory_name(model_id: str) -> str:
    known = {
        "Qwen/Qwen3-ASR-0.6B": "qwen3-asr-0.6b",
        "Qwen/Qwen3-ASR-1.7B": "qwen3-asr-1.7b",
    }
    if model_id in known:
        return known[model_id]
    return model_id.lower().replace("/", "--")


def model_root(model_id: str | None = None) -> Path:
    configured_root = os.environ.get("VOICEINPUT_MODEL_ROOT")
    if configured_root and requested_model_id(model_id) == os.environ.get("VOICEINPUT_MODEL_ID", DEFAULT_MODEL_ID):
        return Path(configured_root).expanduser()

    models_root = os.environ.get("VOICEINPUT_MODELS_ROOT")
    if models_root:
        return Path(models_root).expanduser() / model_directory_name(requested_model_id(model_id))
    return Path(os.environ.get("HF_HOME", Path.home() / ".cache" / "huggingface")).expanduser()


def huggingface_home(model_id: str | None = None) -> Path:
    if os.environ.get("VOICEINPUT_MODELS_ROOT") or os.environ.get("VOICEINPUT_MODEL_ROOT"):
        return model_root(model_id) / "huggingface"
    return Path(os.environ.get("HF_HOME", model_root(model_id))).expanduser()


def cached_model_directory(model_id: str | None = None) -> Path:
    effective_model_id = requested_model_id(model_id)
    cache_name = f"models--{effective_model_id.replace('/', '--')}"
    return huggingface_home(effective_model_id) / "hub" / cache_name


def cached_snapshot_directory(model_id: str | None = None) -> Path | None:
    effective_model_id = requested_model_id(model_id)
    snapshot_dir = cached_model_directory(effective_model_id) / "snapshots" / model_revision(effective_model_id)
    if not snapshot_dir.is_dir() or not is_valid_snapshot_directory(snapshot_dir):
        return None
    return snapshot_dir


def is_cached_model_installed(model_id: str | None = None) -> bool:
    return cached_snapshot_directory(model_id) is not None


def is_valid_snapshot_directory(snapshot_dir: Path) -> bool:
    has_weights = False
    has_config = False
    for path in snapshot_dir.rglob("*"):
        try:
            if not path.is_file():
                continue
        except OSError:
            continue

        suffix = path.suffix.lower()
        if suffix == ".safetensors":
            has_weights = True
        elif suffix == ".json":
            has_config = True

        if has_weights and has_config:
            return True
    return False


def configure_model_environment(model_id: str | None = None) -> Path:
    effective_model_id = requested_model_id(model_id)
    root = model_root(effective_model_id)
    root.mkdir(parents=True, exist_ok=True)
    os.environ["HF_HOME"] = str(huggingface_home(effective_model_id))
    os.environ["TRANSFORMERS_CACHE"] = str(huggingface_home(effective_model_id) / "transformers")
    Path(os.environ["HF_HOME"]).mkdir(parents=True, exist_ok=True)
    Path(os.environ["TRANSFORMERS_CACHE"]).mkdir(parents=True, exist_ok=True)
    return root


def model_cache_dir(model_id: str | None = None) -> Path:
    return huggingface_home(model_id) / "hub"


def is_allowed_model_file(path: str) -> bool:
    return any(fnmatch(path, pattern) for pattern in MODEL_ALLOW_PATTERNS)


def expected_model_bytes(model_id: str) -> int | None:
    try:
        from huggingface_hub import HfApi

        info = HfApi().model_info(
            model_id,
            revision=model_revision(model_id),
            files_metadata=True,
        )
    except Exception:
        return None

    total = 0
    for sibling in getattr(info, "siblings", []):
        filename = getattr(sibling, "rfilename", "")
        size = getattr(sibling, "size", None)
        if size is not None and is_allowed_model_file(filename):
            total += int(size)
    return total or None


def cached_model_bytes(model_id: str) -> int:
    blobs_dir = cached_model_directory(model_id) / "blobs"
    if not blobs_dir.is_dir():
        return 0

    total = 0
    for path in blobs_dir.rglob("*"):
        try:
            if path.is_file() and not path.is_symlink():
                total += path.stat().st_size
        except OSError:
            continue
    return total


def download_state(model_id: str) -> DownloadState:
    with _download_lock:
        state = _model_downloads.get(model_id)
        if state is None:
            state = DownloadState(updated_at=time.time())
            _model_downloads[model_id] = state
        return state


def download_progress(model_id: str, installed: bool, loaded: bool) -> float | None:
    if loaded or installed:
        return 1.0

    state = download_state(model_id)
    if state.total_bytes is None:
        return None

    downloaded = max(state.downloaded_bytes, cached_model_bytes(model_id))
    if downloaded <= 0:
        return 0.0

    progress = downloaded / max(state.total_bytes, 1)
    if state.downloading:
        return min(progress, 0.99)
    return min(progress, 1.0)


def download_progress_tqdm_class(model_id: str, state: DownloadState):
    import io

    from tqdm.auto import tqdm as base_tqdm

    class DownloadProgressTqdm(base_tqdm):
        def __init__(self, *args, **kwargs):
            self._flowtype_track_bytes = kwargs.get("unit") == "B"
            kwargs.setdefault("file", io.StringIO())
            kwargs["disable"] = False
            super().__init__(*args, **kwargs)
            self._flowtype_record()

        def update(self, n: int | float | None = 1):
            result = super().update(n)
            self._flowtype_record()
            return result

        def refresh(self, *args, **kwargs):
            result = super().refresh(*args, **kwargs)
            self._flowtype_record()
            return result

        def close(self):
            self._flowtype_record()
            return super().close()

        def _flowtype_record(self) -> None:
            if not getattr(self, "_flowtype_track_bytes", False):
                return

            total = getattr(self, "total", None)
            current = getattr(self, "n", 0) or 0
            cached = cached_model_bytes(model_id)
            with _download_lock:
                if total and state.total_bytes is None:
                    state.total_bytes = cached + int(total)
                state.downloaded_bytes = max(state.downloaded_bytes, cached + int(current))
                state.updated_at = time.time()

    DownloadProgressTqdm.__name__ = f"DownloadProgressTqdm_{model_directory_name(model_id)}"
    return DownloadProgressTqdm


def download_model_snapshot(model_id: str) -> Path:
    state = download_state(model_id)
    with _download_lock:
        if state.total_bytes is None:
            state.total_bytes = expected_model_bytes(model_id)
        state.downloaded_bytes = min(cached_model_bytes(model_id), state.total_bytes or 0)
        state.downloading = True
        state.error = None
        state.error_code = None
        state.updated_at = time.time()

    try:
        configure_model_environment(model_id)
        cache_dir = model_cache_dir(model_id)
        cache_dir.mkdir(parents=True, exist_ok=True)

        from huggingface_hub import snapshot_download

        path = snapshot_download(
            repo_id=model_id,
            revision=model_revision(model_id),
            cache_dir=str(cache_dir),
            allow_patterns=MODEL_ALLOW_PATTERNS,
            tqdm_class=download_progress_tqdm_class(model_id, state),
        )
        with _download_lock:
            state.snapshot_path = str(path)
            state.downloading = False
            state.updated_at = time.time()
        return Path(path)
    except Exception as exc:
        with _download_lock:
            state.downloading = False
            state.error = str(exc)
            state.error_code = preparation_error_code(exc)
            state.updated_at = time.time()
        raise


def preparation_error_code(error: Exception) -> str:
    if isinstance(error, ConnectionError):
        return "network_unavailable"
    if isinstance(error, OSError) and getattr(error, "errno", None) == 28:
        return "insufficient_disk_space"
    return "model_preparation_failed"


def local_model_source(model_id: str) -> str:
    snapshot_dir = cached_snapshot_directory(model_id)
    if snapshot_dir is not None:
        return str(snapshot_dir)
    return str(download_model_snapshot(model_id))


def verify_token(x_voiceinput_token: str | None = Header(default=None)) -> None:
    expected_token = os.environ.get("VOICEINPUT_HELPER_TOKEN")
    if not expected_token:
        raise HTTPException(status_code=503, detail="Helper authentication is not configured")
    if not secrets.compare_digest(x_voiceinput_token or "", expected_token):
        raise HTTPException(status_code=401, detail="Unauthorized")


def clear_mlx_cache() -> None:
    try:
        import mlx.core as mx

        mx.clear_cache()
    except Exception:
        pass


def unload_session() -> None:
    global _session, _session_model_id

    _session = None
    _session_model_id = None
    gc.collect()
    clear_mlx_cache()


def get_session(model_id: str | None = None) -> Any:
    global Session, _session, _session_loading, _session_loading_model_id, _session_model_id

    effective_model_id = requested_model_id(model_id)

    if _session is None or _session_model_id != effective_model_id:
        with _session_lock:
            if _session is None or _session_model_id != effective_model_id:
                if _session is not None:
                    unload_session()
                _session_loading = True
                _session_loading_model_id = effective_model_id
                try:
                    configure_model_environment(effective_model_id)
                    model_source = local_model_source(effective_model_id)
                    if Session is None:
                        from mlx_qwen3_asr import Session as QwenSession

                        Session = QwenSession
                    _session = Session(model=model_source)
                    _session_model_id = effective_model_id
                finally:
                    _session_loading = False
                    _session_loading_model_id = None
    return _session


def wav_duration_seconds(path: str) -> float:
    with wave.open(path, "rb") as handle:
        return handle.getnframes() / handle.getframerate()


def rms_int16(frames: bytes) -> float:
    if not frames:
        return 0.0
    samples = array("h")
    samples.frombytes(frames)
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples:
        return 0.0
    return (sum(sample * sample for sample in samples) / len(samples)) ** 0.5


def percentile(values: list[float], ratio: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int(round((len(ordered) - 1) * ratio))))
    return ordered[index]


def speech_segments_for_wav(path: str) -> list[AudioSegment]:
    try:
        with wave.open(path, "rb") as handle:
            frame_rate = handle.getframerate()
            frame_count = handle.getnframes()
            duration = frame_count / frame_rate
            if duration < CHUNKED_TRANSCRIPTION_MIN_SECONDS or handle.getsampwidth() != 2:
                return [AudioSegment(0.0, duration)]

            window_frames = max(1, int(frame_rate * SILENCE_WINDOW_SECONDS))
            rms_values: list[float] = []
            window_starts: list[float] = []
            while True:
                start = handle.tell() / frame_rate
                frames = handle.readframes(window_frames)
                if not frames:
                    break
                window_starts.append(start)
                rms_values.append(rms_int16(frames))
    except (EOFError, wave.Error):
        return [AudioSegment(0.0, 0.0)]

    if not rms_values:
        return [AudioSegment(0.0, duration)]

    noise_floor = percentile(rms_values, 0.2)
    speech_level = percentile(rms_values, 0.9)
    threshold = max(160.0, noise_floor * 3.0, speech_level * 0.18)

    raw_segments: list[AudioSegment] = []
    current_start: float | None = None
    for start, rms in zip(window_starts, rms_values):
        window_end = min(duration, start + SILENCE_WINDOW_SECONDS)
        if rms >= threshold:
            if current_start is None:
                current_start = start
        elif current_start is not None:
            raw_segments.append(AudioSegment(current_start, start))
            current_start = None
    if current_start is not None:
        raw_segments.append(AudioSegment(current_start, duration))

    if not raw_segments:
        return [AudioSegment(0.0, duration)]

    merged: list[AudioSegment] = []
    for segment in raw_segments:
        if not merged or segment.start - merged[-1].end > SILENCE_MERGE_SECONDS:
            merged.append(segment)
        else:
            merged[-1] = AudioSegment(merged[-1].start, segment.end)

    padded = [
        AudioSegment(
            max(0.0, segment.start - SEGMENT_PADDING_SECONDS),
            min(duration, segment.end + SEGMENT_PADDING_SECONDS),
        )
        for segment in merged
        if segment.end - segment.start >= MIN_SEGMENT_SECONDS
    ]
    if not padded:
        return [AudioSegment(0.0, duration)]

    split_segments: list[AudioSegment] = []
    for segment in padded:
        start = segment.start
        while segment.end - start > MAX_SEGMENT_SECONDS:
            end = start + MAX_SEGMENT_SECONDS
            split_segments.append(AudioSegment(start, end))
            start = end
        split_segments.append(AudioSegment(start, segment.end))

    return split_segments or [AudioSegment(0.0, duration)]


def write_wav_segment(source_path: str, segment: AudioSegment) -> str:
    with wave.open(source_path, "rb") as source:
        frame_rate = source.getframerate()
        start_frame = max(0, int(segment.start * frame_rate))
        end_frame = min(source.getnframes(), int(segment.end * frame_rate))
        source.setpos(start_frame)
        frames = source.readframes(max(0, end_frame - start_frame))

        temp_file = NamedTemporaryFile(suffix=".wav", delete=False)
        temp_path = temp_file.name
        temp_file.close()
        with wave.open(temp_path, "wb") as target:
            target.setparams(source.getparams())
            target.writeframes(frames)
    return temp_path


def join_transcript_segments(parts: list[str]) -> str:
    text = ""
    for part in [part.strip() for part in parts if part.strip()]:
        if not text:
            text = part
            continue
        text += transcript_segment_separator(text, part[0]) + part
    return text


def transcript_segment_separator(previous: str, next_character: str) -> str:
    if not previous or not next_character:
        return ""

    previous_character = previous[-1]
    if previous_character in "。！？；，、":
        return ""
    if previous_character in ".!?;,":
        return ""

    previous_is_cjk = is_cjk(previous_character)
    next_is_cjk = is_cjk(next_character)
    previous_is_ascii_word = previous_character.isascii() and previous_character.isalnum()
    next_is_ascii_word = next_character.isascii() and next_character.isalnum()

    if previous_is_cjk and next_is_cjk:
        return "，"
    if (previous_is_cjk and next_is_ascii_word) or (previous_is_ascii_word and next_is_cjk):
        return " "
    if previous_is_ascii_word and next_is_ascii_word:
        return " "
    return ""


def is_cjk(character: str) -> bool:
    return any(
        start <= ord(character) <= end
        for start, end in [
            (0x3400, 0x4DBF),
            (0x4E00, 0x9FFF),
            (0xF900, 0xFAFF),
        ]
    )


def load_session_background(model_id: str | None = None) -> None:
    effective_model_id = requested_model_id(model_id)
    state = download_state(effective_model_id)
    try:
        get_session(effective_model_id)
        with _download_lock:
            state.error = None
            state.error_code = None
    except Exception as exc:
        # Keep the helper process alive so the app can retry from the Models page.
        with _download_lock:
            state.error = str(exc)
            state.error_code = preparation_error_code(exc)
    finally:
        with _download_lock:
            state.preparing = False
            state.updated_at = time.time()


def transcribe_file(path: str, model_id: str, context: str = "", strategy: str = "full") -> str:
    with _transcribe_lock:
        try:
            session = get_session(model_id)
            if strategy == "chunked":
                return transcribe_file_in_chunks(path, session, context)

            result = session.transcribe(path, context=context)
        finally:
            clear_mlx_cache()
    return result.text.strip()


def transcribe_file_in_chunks(path: str, session: Any, context: str = "") -> str:
    segments = speech_segments_for_wav(path)
    if len(segments) <= 1:
        result = session.transcribe(path, context=context)
        return result.text.strip()

    texts: list[str] = []
    for segment in segments:
        segment_path = write_wav_segment(path, segment)
        try:
            result = session.transcribe(segment_path, context=context)
            text = result.text.strip()
            if text:
                texts.append(text)
        finally:
            clear_mlx_cache()
            try:
                os.unlink(segment_path)
            except FileNotFoundError:
                pass
    return join_transcript_segments(texts)


def transcription_http_error(exc: Exception) -> HTTPException:
    message = str(exc)
    normalized = message.lower()
    if "ffmpeg not found" in normalized:
        return HTTPException(
            status_code=503,
            detail={
                "code": "audio_resampling_unavailable",
                "message": "Audio resampling is unavailable. Flowtype should send 16 kHz mono PCM WAV audio.",
            },
        )
    if "empty audio" in normalized or "mel spectrogram of empty audio" in normalized:
        return HTTPException(
            status_code=400,
            detail={
                "code": "empty_audio",
                "message": "No usable speech was captured. Hold Fn a little longer and check the microphone input.",
            },
        )
    return HTTPException(
        status_code=500,
        detail={
            "code": "transcription_failed",
            "message": message or exc.__class__.__name__,
        },
    )


@app.get("/health", response_model=HealthResponse, dependencies=[Depends(verify_token)])
def health() -> HealthResponse:
    return HealthResponse(ok=True, engine="qwen3-asr-mlx")


@app.get("/models/status", response_model=ModelStatusResponse, dependencies=[Depends(verify_token)])
def models_status(model_id: str = Query(default=DEFAULT_MODEL_ID)) -> ModelStatusResponse:
    require_supported_model_id(model_id)
    is_loaded = _session is not None and _session_model_id == model_id
    is_installed = is_loaded or is_cached_model_installed(model_id)
    is_loading = _session_loading and _session_loading_model_id == model_id
    state = download_state(model_id)
    with _download_lock:
        operation_id = state.operation_id
        updated_at = state.updated_at or time.time()
        error_code = state.error_code
        is_preparing = state.preparing
        is_downloading = state.downloading

    if is_loaded:
        phase = "ready"
    elif error_code is not None:
        phase = "failed"
    elif is_downloading:
        phase = "downloading"
    elif is_loading or is_preparing:
        phase = "loading"
    elif is_installed:
        phase = "installed"
    else:
        phase = "absent"

    return ModelStatusResponse(
        installed=is_installed,
        loaded=is_loaded,
        loading=is_loading,
        downloading=is_downloading,
        progress=download_progress(model_id, installed=is_installed, loaded=is_loaded),
        phase=phase,
        error_code=error_code,
        operation_id=operation_id,
        updated_at=updated_at,
        model_id=model_id,
        model_path=str(model_root(model_id)),
    )


@app.post("/models/download", response_model=ModelStatusResponse, dependencies=[Depends(verify_token)])
def models_download(model_id: str = Query(default=DEFAULT_MODEL_ID)) -> ModelStatusResponse:
    require_supported_model_id(model_id)
    state = download_state(model_id)
    is_loading = _session_loading and _session_loading_model_id == model_id
    should_submit = False
    with _download_lock:
        if (
            (_session is None or _session_model_id != model_id)
            and not is_loading
            and not state.preparing
            and not state.downloading
        ):
            state.preparing = True
            state.error = None
            state.error_code = None
            state.operation_id = str(uuid.uuid4())
            state.updated_at = time.time()
            should_submit = True
    if should_submit:
        submit_mlx(load_session_background, model_id)
    return models_status(model_id=model_id)


@app.post("/transcribe", response_model=TranscribeResponse, dependencies=[Depends(verify_token)])
async def transcribe(
    audio: UploadFile = File(...),
    model_id: str = Form(default=DEFAULT_MODEL_ID),
    context: str = Form(default=""),
    strategy: str = Form(default="full"),
) -> TranscribeResponse:
    require_supported_model_id(model_id)
    suffix = Path(audio.filename or "").suffix.lower()
    if suffix != ".wav":
        raise HTTPException(status_code=400, detail="Only .wav uploads are supported")

    contents = await audio.read()
    if not contents:
        raise HTTPException(status_code=400, detail="Uploaded .wav file is empty")

    with NamedTemporaryFile(suffix=".wav") as temp_file:
        temp_file.write(contents)
        temp_file.flush()
        try:
            text = await run_mlx(transcribe_file, temp_file.name, model_id, context, strategy)
        except Exception as exc:
            raise transcription_http_error(exc) from exc

    return TranscribeResponse(text=text)


def main() -> None:
    if not os.environ.get("VOICEINPUT_HELPER_TOKEN"):
        raise RuntimeError("VOICEINPUT_HELPER_TOKEN must be set before starting the helper")
    port = int(os.environ.get("VOICEINPUT_HELPER_PORT", "8765"))
    uvicorn.run(app, host="127.0.0.1", port=port)


if __name__ == "__main__":
    main()
