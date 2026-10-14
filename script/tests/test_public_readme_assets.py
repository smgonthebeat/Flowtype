from __future__ import annotations

import hashlib
import struct
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
ASSETS_ROOT = REPO_ROOT / "website" / "assets"


class PublicReadmeAssetTests(unittest.TestCase):
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
            data = (ASSETS_ROOT / name).read_bytes()
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


if __name__ == "__main__":
    unittest.main()
