from __future__ import annotations

import struct
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
        self.assertIn("首个公开版本正在准备", self.html)
        self.assertIn("下载尚未开放", self.html)

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

    def test_screenshot_png_contains_no_text_metadata_chunks(self) -> None:
        data = (WEBSITE_ROOT / "assets/flowtype-home-sanitized.png").read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        offset = 8
        chunk_types: set[bytes] = set()
        while offset < len(data):
            length = struct.unpack(">I", data[offset : offset + 4])[0]
            chunk_type = data[offset + 4 : offset + 8]
            chunk_types.add(chunk_type)
            offset += 12 + length
        self.assertFalse(chunk_types.intersection({b"tEXt", b"zTXt", b"iTXt", b"eXIf"}))

    def test_screenshot_copy_uses_only_synthetic_usage_statistics(self) -> None:
        self.assertIn("synthetic demo data", self.html)
        self.assertIn("flowtype-home-sanitized.png", self.html)
        self.assertNotIn("flowtype-home.png", self.html)
        private_copy = "开发者本机的" + "真实主页"
        self.assertNotIn(private_copy, self.html)


if __name__ == "__main__":
    unittest.main()
