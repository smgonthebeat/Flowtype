"""Pure, unit-testable metrics for the Qwen A/B benchmark."""

from __future__ import annotations

import hashlib
import math
import re
import statistics
from collections.abc import Sequence


def normalize_transcript(text: str) -> str:
    return re.sub(r"[^\w\u3400-\u9fff]+", "", text.casefold(), flags=re.UNICODE)


def transcript_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def edit_distance(left: Sequence, right: Sequence) -> int:
    if len(left) > len(right):
        left, right = right, left
    previous = list(range(len(left) + 1))
    for row, right_item in enumerate(right, start=1):
        current = [row]
        for column, left_item in enumerate(left, start=1):
            current.append(
                min(
                    current[-1] + 1,
                    previous[column] + 1,
                    previous[column - 1] + (left_item != right_item),
                )
            )
        previous = current
    return previous[-1]


def character_error_rate(reference: str, hypothesis: str) -> float:
    normalized_reference = normalize_transcript(reference)
    normalized_hypothesis = normalize_transcript(hypothesis)
    return edit_distance(normalized_reference, normalized_hypothesis) / max(1, len(normalized_reference))


def percentile(values: Sequence[float], ratio: float) -> float:
    if not values:
        raise ValueError("values must not be empty")
    ordered = sorted(values)
    position = (len(ordered) - 1) * ratio
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return float(ordered[lower])
    weight = position - lower
    return float(ordered[lower] * (1 - weight) + ordered[upper] * weight)


def summarize(values: Sequence[float]) -> dict[str, float]:
    if not values:
        raise ValueError("values must not be empty")
    return {
        "minimum": float(min(values)),
        "median": float(statistics.median(values)),
        "p90": percentile(values, 0.90),
        "maximum": float(max(values)),
    }


def linear_slope(values: Sequence[float]) -> float:
    if len(values) < 2:
        return 0.0
    x_mean = (len(values) - 1) / 2
    y_mean = statistics.mean(values)
    numerator = sum((index - x_mean) * (value - y_mean) for index, value in enumerate(values))
    denominator = sum((index - x_mean) ** 2 for index in range(len(values)))
    return float(numerator / denominator)


def relative_change(control: float, candidate: float) -> float:
    if control == 0:
        return 0.0 if candidate == 0 else math.inf
    return (candidate - control) / control
