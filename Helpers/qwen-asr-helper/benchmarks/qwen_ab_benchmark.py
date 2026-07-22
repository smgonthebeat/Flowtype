#!/usr/bin/env python3
"""Run or compare local Qwen3-ASR benchmarks without committing transcript text."""

from __future__ import annotations

import argparse
import importlib.metadata
import json
import os
import platform
import secrets
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

from metrics import character_error_rate, linear_slope, relative_change, summarize, transcript_hash


HELPER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HELPER_ROOT))


def package_version(name: str) -> str:
    try:
        return importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        return "missing"


def current_rss_bytes(pid: int | None = None) -> int:
    target = pid or os.getpid()
    result = subprocess.run(
        ["/bin/ps", "-o", "rss=", "-p", str(target)],
        check=True,
        capture_output=True,
        text=True,
    )
    return int(result.stdout.strip()) * 1024


def mlx_memory() -> dict[str, int]:
    import mlx.core as mx

    return {
        "active_bytes": int(mx.get_active_memory()),
        "cache_bytes": int(mx.get_cache_memory()),
        "peak_bytes": int(mx.get_peak_memory()),
    }


def reset_mlx_peak() -> None:
    import mlx.core as mx

    mx.reset_peak_memory()


def environment_metadata(label: str) -> dict:
    return {
        "label": label,
        "python": platform.python_version(),
        "python_executable_name": Path(sys.executable).name,
        "macos": platform.mac_ver()[0],
        "machine": platform.machine(),
        "mlx_qwen3_asr": package_version("mlx-qwen3-asr"),
        "mlx": package_version("mlx"),
        "qwen_asr_helper": package_version("qwen-asr-helper"),
        "model_id": os.environ.get("VOICEINPUT_MODEL_ID", "Qwen/Qwen3-ASR-0.6B"),
    }


def run_suite(args: argparse.Namespace) -> None:
    from qwen_asr_helper import server

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))["cases"]
    metadata = environment_metadata(args.label)
    started = time.perf_counter()
    load_started = time.perf_counter()
    session = server.get_session(metadata["model_id"])
    load_seconds = time.perf_counter() - load_started
    load_memory = {**mlx_memory(), "rss_bytes": current_rss_bytes()}

    cases = []
    for case in manifest:
        audio_path = Path(case["audio_path"])
        if not audio_path.is_file():
            raise FileNotFoundError(audio_path)
        runs = []
        for iteration in range(case["iterations"]):
            reset_mlx_peak()
            before_rss = current_rss_bytes()
            run_started = time.perf_counter()
            transcript = server.transcribe_file(
                str(audio_path),
                metadata["model_id"],
                context="Flowtype local benchmark; preserve mixed Chinese and English terms.",
                strategy=case["strategy"],
            )
            latency_seconds = time.perf_counter() - run_started
            memory = mlx_memory()
            runs.append(
                {
                    "iteration": iteration + 1,
                    "latency_seconds": latency_seconds,
                    "realtime_factor": latency_seconds / case["duration_seconds"],
                    "rss_before_bytes": before_rss,
                    "rss_after_bytes": current_rss_bytes(),
                    **memory,
                    "transcript": transcript,
                    "transcript_hash": transcript_hash(transcript),
                    "reference_cer": (
                        None
                        if case.get("truncated")
                        else character_error_rate(case["text"] * case["repetitions"], transcript)
                    ),
                }
            )
        cases.append(
            {
                "id": case["id"],
                "strategy": case["strategy"],
                "duration_seconds": case["duration_seconds"],
                "iterations": case["iterations"],
                "runs": runs,
            }
        )

    payload = {
        "schema_version": 1,
        "environment": metadata,
        "load_seconds": load_seconds,
        "load_memory": load_memory,
        "elapsed_seconds": time.perf_counter() - started,
        "cases": cases,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(args.output)


def summarize_case(control: dict, candidate: dict) -> dict:
    control_latency = [run["latency_seconds"] for run in control["runs"]]
    candidate_latency = [run["latency_seconds"] for run in candidate["runs"]]
    control_peak = [run["peak_bytes"] for run in control["runs"]]
    candidate_peak = [run["peak_bytes"] for run in candidate["runs"]]
    control_rss = [run["rss_after_bytes"] for run in control["runs"]]
    candidate_rss = [run["rss_after_bytes"] for run in candidate["runs"]]
    parity = [
        left["transcript"] == right["transcript"]
        for left, right in zip(control["runs"], candidate["runs"], strict=True)
    ]
    normalized_parity = [
        character_error_rate(left["transcript"], right["transcript"]) == 0
        for left, right in zip(control["runs"], candidate["runs"], strict=True)
    ]
    control_latency_summary = summarize(control_latency)
    candidate_latency_summary = summarize(candidate_latency)
    control_peak_summary = summarize(control_peak)
    candidate_peak_summary = summarize(candidate_peak)
    control_rss_summary = summarize(control_rss)
    candidate_rss_summary = summarize(candidate_rss)
    return {
        "id": control["id"],
        "strategy": control["strategy"],
        "duration_seconds": control["duration_seconds"],
        "raw_transcript_parity": all(parity),
        "normalized_transcript_parity": all(normalized_parity),
        "control_transcript_hashes": [run["transcript_hash"] for run in control["runs"]],
        "candidate_transcript_hashes": [run["transcript_hash"] for run in candidate["runs"]],
        "latency_seconds": {
            "control": control_latency_summary,
            "candidate": candidate_latency_summary,
            "median_relative_change": relative_change(
                control_latency_summary["median"], candidate_latency_summary["median"]
            ),
        },
        "mlx_peak_bytes": {
            "control": control_peak_summary,
            "candidate": candidate_peak_summary,
            "median_relative_change": relative_change(
                control_peak_summary["median"], candidate_peak_summary["median"]
            ),
        },
        "rss_after_bytes": {
            "control": control_rss_summary,
            "candidate": candidate_rss_summary,
            "median_relative_change": relative_change(
                control_rss_summary["median"], candidate_rss_summary["median"]
            ),
        },
    }


def classify(summary_cases: list[dict]) -> tuple[str, list[str]]:
    reasons: list[str] = []
    if not all(case["raw_transcript_parity"] for case in summary_cases):
        reasons.append("Raw transcript parity failed.")
        return "NO-GO", reasons
    if any(case["latency_seconds"]["median_relative_change"] > 0.05 for case in summary_cases):
        reasons.append("At least one warm median latency regressed by more than 5%.")
        return "NO-GO", reasons
    if any(case["mlx_peak_bytes"]["median_relative_change"] > 0.10 for case in summary_cases):
        reasons.append("At least one median MLX peak regressed by more than 10%.")
        return "NO-GO", reasons

    pressure = next(case for case in summary_cases if case["id"] == "full_pressure_55s")
    if pressure["mlx_peak_bytes"]["median_relative_change"] <= -0.15:
        reasons.append("The 55-second full path improved median MLX peak memory by at least 15%.")
        return "GO — material improvement", reasons

    reasons.append("Correctness and regression gates passed, but no material production gain was measured.")
    return "GO — maintenance upgrade", reasons


def compare_results(args: argparse.Namespace) -> None:
    control = json.loads(args.control.read_text(encoding="utf-8"))
    candidate = json.loads(args.candidate.read_text(encoding="utf-8"))
    if [case["id"] for case in control["cases"]] != [case["id"] for case in candidate["cases"]]:
        raise ValueError("Control and candidate case sets differ")
    cases = [summarize_case(left, right) for left, right in zip(control["cases"], candidate["cases"], strict=True)]
    decision, reasons = classify(cases)
    def public_environment(environment: dict) -> dict:
        return {
            key: value
            for key, value in environment.items()
            if key not in {"python_executable", "python_executable_name", "label"}
        }

    http_summary = None
    if args.control_http and args.candidate_http:
        control_http = json.loads(args.control_http.read_text(encoding="utf-8"))
        candidate_http = json.loads(args.candidate_http.read_text(encoding="utf-8"))
        http_summary = {
            "control_status": control_http["status"],
            "candidate_status": candidate_http["status"],
            "transcript_parity": control_http["transcript_hash"] == candidate_http["transcript_hash"],
            "control_latency_seconds": control_http["latency_seconds"],
            "candidate_latency_seconds": candidate_http["latency_seconds"],
        }
        if (
            http_summary["control_status"] != 200
            or http_summary["candidate_status"] != 200
            or not http_summary["transcript_parity"]
        ):
            decision = "NO-GO"
            reasons = ["HTTP helper status or transcript parity failed."]

    stability_summary = None
    if args.control_stability and args.candidate_stability:
        control_stability = json.loads(args.control_stability.read_text(encoding="utf-8"))["cases"][0]
        candidate_stability = json.loads(args.candidate_stability.read_text(encoding="utf-8"))["cases"][0]
        control_settled_rss = [run["rss_after_bytes"] for run in control_stability["runs"]][1:]
        candidate_settled_rss = [run["rss_after_bytes"] for run in candidate_stability["runs"]][1:]
        stability_parity = [
            left["transcript"] == right["transcript"]
            for left, right in zip(control_stability["runs"], candidate_stability["runs"], strict=True)
        ]
        stability_summary = {
            "case_id": control_stability["id"],
            "iterations_per_version": len(control_stability["runs"]),
            "raw_transcript_parity": all(stability_parity),
            "control_settled_rss_slope_bytes_per_run": linear_slope(control_settled_rss),
            "candidate_settled_rss_slope_bytes_per_run": linear_slope(candidate_settled_rss),
            "control_settled_rss_bytes": summarize(control_settled_rss),
            "candidate_settled_rss_bytes": summarize(candidate_settled_rss),
        }
        if (
            not stability_summary["raw_transcript_parity"]
            or stability_summary["candidate_settled_rss_slope_bytes_per_run"] > 8 * 1024 * 1024
        ):
            decision = "NO-GO"
            reasons = ["Repeated 55-second stability transcript or RSS growth gate failed."]

    summary = {
        "schema_version": 1,
        "control_environment": public_environment(control["environment"]),
        "candidate_environment": public_environment(candidate["environment"]),
        "control_load_seconds": control["load_seconds"],
        "candidate_load_seconds": candidate["load_seconds"],
        "decision": decision,
        "reasons": reasons,
        "http_smoke": http_summary,
        "stability": stability_summary,
        "cases": cases,
    }
    args.summary_json.parent.mkdir(parents=True, exist_ok=True)
    args.summary_json.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    rows = []
    for case in cases:
        rows.append(
            "| {id} | {strategy} | {parity} | {control:.3f} | {candidate:.3f} | {latency:+.1%} | {memory:+.1%} | {rss:+.1%} |".format(
                id=case["id"],
                strategy=case["strategy"],
                parity="PASS" if case["raw_transcript_parity"] else "FAIL",
                control=case["latency_seconds"]["control"]["median"],
                candidate=case["latency_seconds"]["candidate"]["median"],
                latency=case["latency_seconds"]["median_relative_change"],
                memory=case["mlx_peak_bytes"]["median_relative_change"],
                rss=case["rss_after_bytes"]["median_relative_change"],
            )
        )
    report = "\n".join(
        [
            "# mlx-qwen3-asr 0.3.3 vs 0.3.5 A/B Report",
            "",
            f"Decision: **{decision}**",
            "",
            *[f"- {reason}" for reason in reasons],
            "",
            f"- Control cold load: {control['load_seconds']:.3f}s",
            f"- Candidate cold load: {candidate['load_seconds']:.3f}s",
            "- Cold-load timings are descriptive only because filesystem/Metal cache order cannot be neutralized on a live host.",
            "- Corpus: generated macOS TTS only; no user recordings.",
            "- Privacy: raw transcripts remain in ignored `.build`; this report contains no transcript text.",
            *(
                [
                    f"- HTTP smoke: control {http_summary['control_status']}, candidate {http_summary['candidate_status']}, transcript parity {'PASS' if http_summary['transcript_parity'] else 'FAIL'}.",
                ]
                if http_summary
                else []
            ),
            *(
                [
                    "- Repeated 55-second stability: {iterations} runs/version, transcript parity {parity}; settled RSS slope control {control:+.2f} MiB/run, candidate {candidate:+.2f} MiB/run.".format(
                        iterations=stability_summary["iterations_per_version"],
                        parity="PASS" if stability_summary["raw_transcript_parity"] else "FAIL",
                        control=stability_summary["control_settled_rss_slope_bytes_per_run"] / (1024 * 1024),
                        candidate=stability_summary["candidate_settled_rss_slope_bytes_per_run"] / (1024 * 1024),
                    )
                ]
                if stability_summary
                else []
            ),
            "",
            "| Case | Strategy | Raw parity | Control median (s) | Candidate median (s) | Latency delta | MLX peak delta | RSS delta |",
            "|---|---|---:|---:|---:|---:|---:|---:|",
            *rows,
            "",
        ]
    )
    args.report.write_text(report, encoding="utf-8")
    print(args.summary_json)
    print(args.report)


def reserve_port() -> int:
    with socket.socket() as handle:
        handle.bind(("127.0.0.1", 0))
        return int(handle.getsockname()[1])


def multipart_body(audio_path: Path, model_id: str, strategy: str, boundary: str) -> bytes:
    fields = [("model_id", model_id), ("context", "Flowtype HTTP benchmark"), ("strategy", strategy)]
    parts = bytearray()
    for name, value in fields:
        parts.extend(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n".encode())
    parts.extend(
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"fixture.wav\"\r\nContent-Type: audio/wav\r\n\r\n".encode()
    )
    parts.extend(audio_path.read_bytes())
    parts.extend(f"\r\n--{boundary}--\r\n".encode())
    return bytes(parts)


def http_smoke(args: argparse.Namespace) -> None:
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))["cases"]
    case = next(item for item in manifest if item["id"] == "short_mixed_6s")
    port = reserve_port()
    token = secrets.token_urlsafe(32)
    env = os.environ.copy()
    env.update(
        {
            "PYTHONPATH": str(HELPER_ROOT),
            "VOICEINPUT_HELPER_PORT": str(port),
            "VOICEINPUT_HELPER_TOKEN": token,
        }
    )
    log_path = args.output.with_suffix(".server.log")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("wb") as log:
        process = subprocess.Popen(
            [sys.executable, "-m", "qwen_asr_helper.server"],
            env=env,
            stdout=log,
            stderr=subprocess.STDOUT,
        )
        try:
            health_url = f"http://127.0.0.1:{port}/health"
            deadline = time.monotonic() + 30
            while True:
                if process.poll() is not None:
                    raise RuntimeError(f"HTTP helper exited early with code {process.returncode}")
                try:
                    request = urllib.request.Request(health_url, headers={"X-Voiceinput-Token": token})
                    with urllib.request.urlopen(request, timeout=1) as response:
                        if response.status == 200:
                            break
                except Exception:
                    if time.monotonic() >= deadline:
                        raise TimeoutError("HTTP helper health check timed out")
                    time.sleep(0.1)

            boundary = "FlowtypeQwenBenchmarkBoundary"
            body = multipart_body(Path(case["audio_path"]), env["VOICEINPUT_MODEL_ID"], case["strategy"], boundary)
            request = urllib.request.Request(
                f"http://127.0.0.1:{port}/transcribe",
                data=body,
                method="POST",
                headers={
                    "Content-Type": f"multipart/form-data; boundary={boundary}",
                    "X-Voiceinput-Token": token,
                },
            )
            started = time.perf_counter()
            with urllib.request.urlopen(request, timeout=300) as response:
                response_payload = json.loads(response.read())
            payload = {
                "environment": environment_metadata(args.label),
                "status": response.status,
                "latency_seconds": time.perf_counter() - started,
                "transcript_hash": transcript_hash(response_payload["text"]),
                "server_pid": process.pid,
            }
            args.output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
    print(args.output)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    run = subparsers.add_parser("run")
    run.add_argument("--label", required=True)
    run.add_argument("--manifest", type=Path, required=True)
    run.add_argument("--output", type=Path, required=True)
    run.set_defaults(handler=run_suite)

    compare = subparsers.add_parser("compare")
    compare.add_argument("--control", type=Path, required=True)
    compare.add_argument("--candidate", type=Path, required=True)
    compare.add_argument("--summary-json", type=Path, required=True)
    compare.add_argument("--report", type=Path, required=True)
    compare.add_argument("--control-http", type=Path)
    compare.add_argument("--candidate-http", type=Path)
    compare.add_argument("--control-stability", type=Path)
    compare.add_argument("--candidate-stability", type=Path)
    compare.set_defaults(handler=compare_results)

    http = subparsers.add_parser("http-smoke")
    http.add_argument("--label", required=True)
    http.add_argument("--manifest", type=Path, required=True)
    http.add_argument("--output", type=Path, required=True)
    http.set_defaults(handler=http_smoke)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.handler(args)


if __name__ == "__main__":
    main()
