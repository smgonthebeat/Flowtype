from __future__ import annotations

import struct
import hashlib
import unittest
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse


REPO_ROOT = Path(__file__).resolve().parents[2]
WEBSITE_ROOT = REPO_ROOT / "website"


class AssetParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.asset_urls: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if tag in {"img", "script"} and values.get("src"):
            self.asset_urls.append(values["src"] or "")
        if tag == "link" and values.get("href"):
            relationships = set((values.get("rel") or "").split())
            if relationships.intersection({"stylesheet", "icon", "preload"}):
                self.asset_urls.append(values["href"] or "")


class PublicWebsiteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.index_path = WEBSITE_ROOT / "index.html"
        self.html = self.index_path.read_text(encoding="utf-8")

    def test_preview_release_links_and_safety_copy(self) -> None:
        self.assertNotIn("TODO: replace", self.html)
        self.assertNotIn('href="#"', self.html)
        self.assertNotIn("xattr -cr", self.html)
        self.assertNotIn("spctl --master-disable", self.html)
        self.assertIn("v0.1.0-preview.4", self.html)
        self.assertIn("releases/download/v0.1.0-preview.4/Flowtype.dmg", self.html)
        self.assertNotIn("releases/download/v0.1.0-preview.3/Flowtype.dmg", self.html)
        self.assertIn("未经过 Apple notarization", self.html)
        self.assertIn("Open Anyway", self.html)
        self.assertIn("自动下载约 1.9 GB 的默认模型", self.html)
        self.assertIn("显示下载与准备进度", self.html)
        self.assertIn("本地临时录音，转写即删", self.html)
        self.assertIn("日常转写不必把录音发送到云端 ASR", self.html)
        self.assertIn("docs/PRIVACY-COMPARISON.md", self.html)

    def test_runtime_assets_are_local_and_present(self) -> None:
        parser = AssetParser()
        parser.feed(self.html)
        self.assertTrue(parser.asset_urls)
        for raw_url in parser.asset_urls:
            parsed = urlparse(raw_url)
            if parsed.scheme == "data":
                self.assertTrue(raw_url.startswith("data:image/"), raw_url)
                continue
            self.assertFalse(parsed.scheme, raw_url)
            self.assertFalse(parsed.netloc, raw_url)
            self.assertTrue((WEBSITE_ROOT / parsed.path).is_file(), raw_url)

    def test_screenshot_png_matches_reviewed_metadata_contract(self) -> None:
        data = (WEBSITE_ROOT / "assets/flowtype-home-real-usage.png").read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(
            hashlib.sha256(data).hexdigest(),
            "0f27e5928ac66dd1cca10f973359c77cfb1f4da9fc5b8032d255aaea5a5fe59e",
        )
        offset = 8
        chunk_types: set[bytes] = set()
        metadata_payloads: list[bytes] = []
        while offset < len(data):
            length = struct.unpack(">I", data[offset : offset + 4])[0]
            chunk_type = data[offset + 4 : offset + 8]
            chunk_types.add(chunk_type)
            if chunk_type in {b"tEXt", b"zTXt", b"iTXt", b"eXIf"}:
                metadata_payloads.append(data[offset + 8 : offset + 8 + length])
            offset += 12 + length
        self.assertFalse(chunk_types.intersection({b"tEXt", b"zTXt", b"iTXt", b"eXIf", b"tIME"}))
        metadata = b"\n".join(metadata_payloads).lower()
        for forbidden in (b"/users/", b"gps", b"author", b"creator", b"email"):
            self.assertNotIn(forbidden, metadata)

    def test_screenshot_copy_discloses_owner_approved_real_usage(self) -> None:
        self.assertIn("4,680 次听写", self.html)
        self.assertIn("60 小时 37 分钟", self.html)
        self.assertIn("flowtype-home-real-usage.png", self.html)
        self.assertIn("下方转写历史已作强模糊处理", self.html)
        self.assertNotIn("synthetic demo data", self.html)
        self.assertNotIn("flowtype-home-sanitized.png", self.html)

    def test_first_launch_guide_pngs_match_reviewed_binary_contracts(self) -> None:
        contracts = {
            "first-launch-1-blocked.png": (
                (512, 686),
                "e66519936bced2d4ae4e7a1208a19ac1080ed423b552c6e7c0a16c4022021f1b",
            ),
            "first-launch-2-open-anyway.png": (
                (1412, 1958),
                "f2240eee602ebf5537b163b5b5eb8884fb7a33348e6fd0089533d5b00236f8e0",
            ),
            "first-launch-3-apple-guide.png": (
                (1730, 1048),
                "97323658ca0f57c6c87a59b08939fecb6ce63ad9c593e25c99f1d4c221817af1",
            ),
        }

        for name, (dimensions, expected_hash) in contracts.items():
            data = (WEBSITE_ROOT / f"assets/{name}").read_bytes()
            self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n", name)
            self.assertEqual(struct.unpack(">II", data[16:24]), dimensions, name)
            self.assertEqual(hashlib.sha256(data).hexdigest(), expected_hash, name)

            offset = 8
            chunk_types: set[bytes] = set()
            while offset < len(data):
                length = struct.unpack(">I", data[offset : offset + 4])[0]
                chunk_types.add(data[offset + 4 : offset + 8])
                offset += 12 + length
            self.assertFalse(
                chunk_types.intersection({b"tEXt", b"zTXt", b"iTXt", b"eXIf", b"tIME"}),
                name,
            )

    def test_workflow_gif_matches_reviewed_binary_contract(self) -> None:
        data = (WEBSITE_ROOT / "assets/flowtype-workflow.gif").read_bytes()
        self.assertIn(data[:6], {b"GIF87a", b"GIF89a"})
        self.assertEqual(struct.unpack("<HH", data[6:10]), (960, 540))
        self.assertLess(len(data), 15 * 1024 * 1024)
        self.assertEqual(
            hashlib.sha256(data).hexdigest(),
            "74e04814e12652dc0244b1e99b9ebf6078f4c7017f8b918dec4351a1f26e3edf",
        )

    def test_quick_workflow_gif_matches_reviewed_binary_contract(self) -> None:
        data = (WEBSITE_ROOT / "assets/flowtype-workflow-quick.gif").read_bytes()
        self.assertIn(data[:6], {b"GIF87a", b"GIF89a"})
        self.assertEqual(struct.unpack("<HH", data[6:10]), (1200, 675))
        self.assertLess(len(data), 8 * 1024 * 1024)
        self.assertEqual(
            hashlib.sha256(data).hexdigest(),
            "4b8973ce61b5d359024303513438c83d35c7c2f4a33c9f844921ec69d9461656",
        )


if __name__ == "__main__":
    unittest.main()
