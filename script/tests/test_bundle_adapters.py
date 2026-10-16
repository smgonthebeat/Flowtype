from __future__ import annotations

import hashlib
import os
import re
import struct
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


class BundleAdapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.repo_root = Path(__file__).resolve().parents[2]
        cls.makefile = (cls.repo_root / "Makefile").read_text(encoding="utf-8")
        cls.build_script_path = cls.repo_root / "script/build_and_run.sh"
        cls.build_script = cls.build_script_path.read_text(encoding="utf-8")
        cls.verify_script = (cls.repo_root / "script/verify_package.sh").read_text(
            encoding="utf-8"
        )
        cls.dmg_script_path = cls.repo_root / "script/create_dmg.sh"

    @staticmethod
    def _logical_lines(source: str) -> str:
        return re.sub(r"\\\n\s*", " ", source)

    @staticmethod
    def _function_body(source: str, name: str) -> str:
        match = re.search(rf"^{name}\(\) \{{\n(?P<body>.*?)^\}}", source, re.MULTILINE | re.DOTALL)
        if match is None:
            raise AssertionError(f"missing shell function: {name}")
        return match.group("body")

    def test_dev_and_release_delegate_only_dynamic_inputs_to_canonical_assembly(self) -> None:
        expected_flags = {
            "dev": {"--app", "--app-binary", "--uv"},
            "release": {
                "--app",
                "--app-binary",
                "--uv",
                "--helper-version",
                "--source-commit",
            },
        }
        sources = {
            "dev": self._logical_lines(self.build_script),
            "release": self._logical_lines(self.makefile),
        }

        for adapter, source in sources.items():
            with self.subTest(adapter=adapter):
                commands = [
                    line
                    for line in source.splitlines()
                    if "app_bundle.py" in line and "assemble" in line
                ]
                self.assertEqual(len(commands), 1)
                flags = set(re.findall(r"--[a-z-]+", commands[0]))
                self.assertEqual(flags, expected_flags[adapter])

    def test_build_adapters_do_not_repeat_static_bundle_inventory(self) -> None:
        forbidden_inventory = (
            "Flowtype-logo.svg",
            "Flowtype-logo.png",
            "Flowtype.icns",
            "Qwen-logo.svg",
            "HomeCardArtwork-mic.png",
            "HomeCardArtwork-wave.png",
            "HomeCardArtwork-docs.png",
            "HomeCardArtwork-clock.png",
            "HomeCardArtwork-mic-light.png",
            "HomeCardArtwork-wave-light.png",
            "HomeCardArtwork-docs-light.png",
            "HomeCardArtwork-clock-light.png",
            "FlowtypeBackdrop-topLeading.png",
            "FlowtypeBackdrop-bottomTrailing.png",
            "qwen_asr_helper",
            "write_helper_manifest.py",
            "rsync",
        )
        for adapter, source in (("dev", self.build_script), ("release", self.makefile)):
            with self.subTest(adapter=adapter):
                for item in forbidden_inventory:
                    self.assertNotIn(item, source)

    def test_release_signing_stays_after_successful_canonical_assembly(self) -> None:
        source = self._logical_lines(self.makefile)
        assembly = source.index("script/app_bundle.py assemble")
        signing = source.index(
            'codesign --force --deep --sign "$(CODESIGN_IDENTITY)" "$(APP_DIR)"'
        )

        self.assertLess(assembly, signing)
        self.assertIn("CODESIGN_IDENTITY ?= -", self.makefile)

    def test_install_archives_previous_app_before_replacement(self) -> None:
        install_target = self.makefile.split("install: build", 1)[1].split("\ndmg:", 1)[0]

        self.assertIn('archive_root="$(CURDIR)/.trash"', install_target)
        self.assertIn('mv "/Applications/$(APP_NAME).app" "$$archive_path"', install_target)
        self.assertIn('ditto "$(APP_DIR)" "/Applications/$(APP_NAME).app"', install_target)
        self.assertNotIn("rm -rf", install_target)

    def test_package_verifier_delegates_inventory_then_retains_trust_checks(self) -> None:
        source = self._logical_lines(self.verify_script)
        checks = (
            "app_bundle.py",
            'plutil -lint "$APP_PATH/Contents/Info.plist"',
            'codesign --verify --deep --strict --verbose=2 "$APP_PATH"',
            'hdiutil verify "$DMG_PATH"',
        )
        positions = [source.index(check) for check in checks]

        self.assertEqual(positions, sorted(positions))
        self.assertRegex(source, r'app_bundle\.py"? verify --app "\$APP_PATH"')
        for duplicate_detail in (
            "helper_manifest.json",
            "qwen_asr_helper/server.py",
            "requires_uv_lock_hash",
            "__pycache__",
        ):
            self.assertNotIn(duplicate_detail, self.verify_script)

    def test_dmg_adapter_uses_a_reviewed_compact_finder_layout(self) -> None:
        self.assertTrue(self.dmg_script_path.is_file())
        dmg_script = self.dmg_script_path.read_text(encoding="utf-8")
        logical_makefile = self._logical_lines(self.makefile)

        self.assertIn(
            './script/create_dmg.sh "$(APP_DIR)" "$(DMG_PATH)" en',
            logical_makefile,
        )
        self.assertIn(
            './script/create_dmg.sh "$(APP_DIR)" "$(DMG_ZH_PATH)" zh-CN',
            logical_makefile,
        )
        for expected in (
            'VOLUME_NAME="Flowtype Installer"',
            'ICON_SIZE="144"',
            'WINDOW_WIDTH="660"',
            'WINDOW_HEIGHT="435"',
            'set position of item "Flowtype.app"',
            'set position of item "Applications"',
            'BACKGROUND_NAME="DMGBackground.tiff"',
            'BACKGROUND_NAME="DMGBackground-zh-CN.tiff"',
            'set backgroundFile to file ("Flowtype.app:Contents:Resources:" & backgroundName)',
            "set background picture to backgroundFile",
            'mv "$generatedItem" "$archivePath"',
            'hdiutil convert',
            '-format UDZO',
        ):
            self.assertIn(expected, dmg_script)
        self.assertNotIn("rm -rf", dmg_script)

        # One Flowtype Dawn window background per installer language: SVG source, 1x and 2x PNG, and
        # the combined TIFF Finder shows (built by public-release/marketing/dmg-background/build.py).
        reviewed = {
            "DMGBackground": (
                "f7267a5e68bfc188049a535a0600a4813bb2a2a8fe55fe98cb9128234b2b59b7",
                "7f3c1dd1d29db91af840cf74eb593f7951b5ad328817930620e16770f1e8c599",
                "682bd66f1161006d7e233959678c45110c12ae47f5b4fda711ad2fe869ad25d7",
            ),
            "DMGBackground-zh-CN": (
                "1348d00413c0776a915995eafbfa955b4fb7fd37034f9800ab248464988a067d",
                "037a19beb1d1e7aeb0cab3637c56244316f5c07d4f12c46cf0e47e17bee8681c",
                "2052e152946a0cc43d9a4bca98b0f6bc851e7fe219f63956f59a34616cc13efd",
            ),
        }
        for name, (png_hash, png_2x_hash, tiff_hash) in reviewed.items():
            source = self.repo_root / f"Resources/{name}.svg"
            self.assertTrue(source.is_file(), name)
            png = (self.repo_root / f"Resources/{name}.png").read_bytes()
            png_2x = (self.repo_root / f"Resources/{name}@2x.png").read_bytes()
            tiff = (self.repo_root / f"Resources/{name}.tiff").read_bytes()
            self.assertEqual(png[:8], b"\x89PNG\r\n\x1a\n", name)
            self.assertEqual(png_2x[:8], b"\x89PNG\r\n\x1a\n", name)
            self.assertEqual(struct.unpack(">II", png[16:24]), (660, 400), name)
            self.assertEqual(struct.unpack(">II", png_2x[16:24]), (1320, 800), name)
            self.assertEqual(hashlib.sha256(png).hexdigest(), png_hash, name)
            self.assertEqual(hashlib.sha256(png_2x).hexdigest(), png_2x_hash, name)
            self.assertEqual(hashlib.sha256(tiff).hexdigest(), tiff_hash, name)

    def test_build_only_executes_compile_and_assembly_without_outer_actions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary = Path(temporary_directory)
            stub_directory = temporary / "bin"
            build_directory = temporary / "swift-bin"
            stub_directory.mkdir()
            build_directory.mkdir()
            (build_directory / "Flowtype").write_text("stub app\n", encoding="utf-8")
            (build_directory / "Flowtype").chmod(0o755)
            uv_binary = temporary / "uv"
            uv_binary.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            uv_binary.chmod(0o755)
            sentinel_log = temporary / "sentinel.log"

            self._write_stub(
                stub_directory / "swift",
                f"""
                printf 'swift:%s\\n' "$*" >>"$SENTINEL_LOG"
                if [ "$*" = "build --show-bin-path" ]; then
                  printf '%s\\n' "{build_directory}"
                fi
                """,
            )
            self._write_stub(
                stub_directory / "python3",
                f"""
                if [ "${{1:-}}" = "-c" ]; then
                  exec "{sys.executable}" "$@"
                fi
                printf 'python3:%s\\n' "$*" >>"$SENTINEL_LOG"
                """,
            )
            for command in ("pkill", "open", "lldb", "log"):
                self._write_stub(
                    stub_directory / command,
                    f"printf 'FORBIDDEN:{command}:%s\\n' \"$*\" >>\"$SENTINEL_LOG\"\n",
                )

            environment = os.environ.copy()
            environment.update(
                {
                    "PATH": f"{stub_directory}:{environment['PATH']}",
                    "PYTHON_BINARY": str(stub_directory / "python3"),
                    "SENTINEL_LOG": str(sentinel_log),
                    "UV_BINARY": str(uv_binary),
                }
            )
            result = subprocess.run(
                ["bash", str(self.build_script_path), "--build-only"],
                cwd=self.repo_root,
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            events = sentinel_log.read_text(encoding="utf-8").splitlines()
            self.assertEqual(events[0:2], ["swift:build", "swift:build --show-bin-path"])
            self.assertEqual(len([event for event in events if "app_bundle.py assemble" in event]), 1)
            self.assertFalse(any(event.startswith("FORBIDDEN:") for event in events), events)

    def test_build_function_is_process_independent_and_modes_keep_outer_actions(self) -> None:
        build_body = self._function_body(self.build_script, "build_app")
        for forbidden in ("pkill", "open_app", "lldb", "show_logs", "show_telemetry", "verify_run"):
            self.assertNotIn(forbidden, build_body)

        expected_branches = (
            r'run\|""\)\s+stop_app\s+build_app\s+open_app',
            r'--debug\|debug\)\s+stop_app\s+build_app\s+lldb -- "\$APP_BINARY"',
            r'--logs\|logs\)\s+stop_app\s+build_app\s+open_app\s+show_logs',
            r'--telemetry\|telemetry\)\s+stop_app\s+build_app\s+open_app\s+show_telemetry',
            r'--verify\|verify\)\s+stop_app\s+build_app\s+verify_run',
            r'--build-only\)\s+build_app\s+;;',
        )
        for pattern in expected_branches:
            self.assertRegex(self.build_script, pattern)

        stop_body = self._function_body(self.build_script, "stop_app")
        self.assertIn('pkill -x "$APP_NAME" || true', stop_body)

    def test_unknown_mode_exits_two_and_usage_advertises_build_only(self) -> None:
        result = subprocess.run(
            ["bash", str(self.build_script_path), "--not-a-mode"],
            cwd=self.repo_root,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 2)
        self.assertIn("Unknown mode: --not-a-mode", result.stderr)
        self.assertIn("--build-only", result.stderr)

    def test_root_pytest_discovery_is_scoped_to_qwen_helper_tests(self) -> None:
        config_path = self.repo_root / "pytest.ini"
        self.assertTrue(config_path.is_file(), "missing root pytest discovery config")
        pytest_config = config_path.read_text(encoding="utf-8")

        self.assertIn("testpaths = Helpers/qwen-asr-helper/tests", pytest_config)

    @staticmethod
    def _write_stub(path: Path, body: str) -> None:
        path.write_text(
            "#!/usr/bin/env bash\nset -euo pipefail\n"
            + textwrap.dedent(body).lstrip(),
            encoding="utf-8",
        )
        path.chmod(0o755)


if __name__ == "__main__":
    unittest.main()
