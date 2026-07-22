from pathlib import Path
import sys

import pytest


BENCHMARKS = Path(__file__).resolve().parents[1] / "benchmarks"
sys.path.insert(0, str(BENCHMARKS))

from metrics import (  # noqa: E402
    character_error_rate,
    edit_distance,
    linear_slope,
    normalize_transcript,
    percentile,
    relative_change,
    summarize,
    transcript_hash,
)


def test_normalize_transcript_preserves_words_numbers_and_cjk():
    assert normalize_transcript("Flowtype, Qwen-3：你好！") == "flowtypeqwen3你好"


def test_edit_distance_and_character_error_rate():
    assert edit_distance("kitten", "sitting") == 3
    assert character_error_rate("你好 Flowtype", "你好 Flow type") == 0
    assert character_error_rate("你好", "你们") == 0.5


def test_percentile_and_summary_are_interpolated():
    assert percentile([1, 2, 3, 4], 0.5) == 2.5
    assert summarize([1, 2, 3])["median"] == 2
    assert summarize([1, 2, 3])["p90"] == pytest.approx(2.8)


def test_linear_slope_and_relative_change():
    assert linear_slope([10, 12, 14, 16]) == 2
    assert relative_change(100, 90) == -0.1


def test_transcript_hash_is_stable_and_does_not_expose_text():
    value = transcript_hash("private transcript")
    assert value == transcript_hash("private transcript")
    assert "private" not in value
