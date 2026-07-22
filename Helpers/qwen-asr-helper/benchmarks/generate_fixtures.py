#!/usr/bin/env python3
"""Generate deterministic, non-user Flowtype ASR benchmark fixtures with macOS TTS."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
import wave
from pathlib import Path


def read_cases(path: Path) -> list[dict]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("schema_version") != 1:
        raise ValueError("Unsupported cases schema")
    return payload["cases"]


def convert_to_pcm_wav(source: Path, target: Path) -> None:
    subprocess.run(
        ["/usr/bin/afconvert", "-f", "WAVE", "-d", "LEI16@16000", str(source), str(target)],
        check=True,
        capture_output=True,
    )


def read_pcm(path: Path) -> tuple[wave._wave_params, bytes]:
    with wave.open(str(path), "rb") as handle:
        params = handle.getparams()
        if params.nchannels != 1 or params.sampwidth != 2 or params.framerate != 16_000:
            raise ValueError(f"Unexpected PCM format for {path}: {params}")
        return params, handle.readframes(handle.getnframes())


def build_duration_fixture(base_wav: Path, target: Path, duration_seconds: float) -> dict:
    params, speech = read_pcm(base_wav)
    frame_bytes = params.nchannels * params.sampwidth
    target_frames = round(duration_seconds * params.framerate)
    speech_frames = len(speech) // frame_bytes
    gap_frames = round(0.8 * params.framerate)
    silence = b"\0" * gap_frames * frame_bytes

    output = bytearray()
    repetitions = 0
    truncated = False
    if speech_frames > target_frames:
        output.extend(speech[: target_frames * frame_bytes])
        repetitions = 1
        truncated = True
    while (len(output) // frame_bytes) + speech_frames <= target_frames:
        if output and (len(output) // frame_bytes) + gap_frames + speech_frames <= target_frames:
            output.extend(silence)
        output.extend(speech)
        repetitions += 1
    remaining_frames = target_frames - len(output) // frame_bytes
    output.extend(b"\0" * remaining_frames * frame_bytes)

    with wave.open(str(target), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(16_000)
        handle.writeframes(bytes(output))

    return {
        "duration_seconds": target_frames / params.framerate,
        "repetitions": repetitions,
        "truncated": truncated,
        "sample_rate": params.framerate,
        "channels": params.nchannels,
        "sample_width_bytes": params.sampwidth,
    }


def generate_case(case: dict, output_dir: Path) -> dict:
    with tempfile.TemporaryDirectory(prefix="flowtype-qwen-fixture-") as temp_dir:
        temp = Path(temp_dir)
        aiff = temp / "speech.aiff"
        wav = temp / "speech.wav"
        subprocess.run(
            [
                "/usr/bin/say",
                "-v",
                case["voice"],
                "-r",
                str(case["rate"]),
                "-o",
                str(aiff),
                case["text"],
            ],
            check=True,
            capture_output=True,
        )
        convert_to_pcm_wav(aiff, wav)
        destination = output_dir / f"{case['id']}.wav"
        metadata = build_duration_fixture(wav, destination, case["target_duration_seconds"])
    return {**case, **metadata, "audio_path": str(destination.resolve())}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    for tool in ("/usr/bin/say", "/usr/bin/afconvert"):
        if not Path(tool).is_file():
            raise SystemExit(f"Required macOS tool is missing: {tool}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    manifest = [generate_case(case, args.output_dir) for case in read_cases(args.cases)]
    manifest_path = args.output_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps({"schema_version": 1, "cases": manifest}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(manifest_path)


if __name__ == "__main__":
    main()
