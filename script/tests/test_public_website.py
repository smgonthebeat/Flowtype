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

    def test_release_placeholders_fail_safe(self) -> None:
        self.assertNotIn("TODO: replace", self.html)
        self.assertNotIn('href="#"', self.html)
        self.assertNotIn("xattr -cr", self.html)
        self.assertIn("DMG 等待 Developer ID 与 Apple notarization", self.html)
        self.assertIn("DMG 待公证后开放", self.html)

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


if __name__ == "__main__":
    unittest.main()
