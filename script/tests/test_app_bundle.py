from __future__ import annotations

import copy
import hashlib
import importlib
import json
import os
import shutil
import tempfile
import time
import unittest
from contextlib import contextmanager, redirect_stderr
from io import StringIO
from pathlib import Path, PurePosixPath
from unittest import mock


class ContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.module = importlib.import_module("script.app_bundle")
        cls.repo_root = Path(__file__).resolve().parents[2]

    def setUp(self) -> None:
        self.contract_path = self.repo_root / "config" / "app-bundle-contract.json"
        self.contract_data = json.loads(self.contract_path.read_text(encoding="utf-8"))

    def _load_data(self, data: dict[str, object]):
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "contract.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            return self.module._load_contract_file(path, self.repo_root)

    def _assert_contract_error(
        self,
        data: dict[str, object],
        code: str,
        artifact_id: str | None = None,
    ) -> None:
        with self.assertRaises(self.module._ContractError) as context:
            self._load_data(data)
        self.assertEqual(context.exception.code, code)
        self.assertEqual(context.exception.artifact_id, artifact_id)
        self.assertTrue(str(context.exception).startswith(code))

    def test_repository_contract_loads_supported_schema(self) -> None:
        contract = self.module._load_contract()

        self.assertEqual(contract.schema_version, 1)
        self.assertEqual(contract.manifest_file_name, "FlowtypeBundleManifest.json")

    def test_manifest_file_name_must_be_a_safe_relative_path(self) -> None:
        for value in ("/tmp/FlowtypeBundleManifest.json", "../FlowtypeBundleManifest.json"):
            with self.subTest(value=value):
                data = copy.deepcopy(self.contract_data)
                data["manifestFileName"] = value
                self._assert_contract_error(data, "contract-invalid")

    def test_manifest_file_name_matches_generated_manifest_destination(self) -> None:
        data = copy.deepcopy(self.contract_data)
        data["manifestFileName"] = "OtherBundleManifest.json"

        self._assert_contract_error(data, "contract-invalid", "bundle-manifest")

    def test_artifact_ids_and_destinations_are_unique(self) -> None:
        contract = self.module._load_contract()

        artifact_ids = [entry.artifact_id for entry in contract.entries]
        destinations = [entry.destination for entry in contract.entries]
        self.assertEqual(len(artifact_ids), len(set(artifact_ids)))
        self.assertEqual(len(destinations), len(set(destinations)))

        duplicate_id = copy.deepcopy(self.contract_data)
        duplicate_id["entries"][1]["id"] = duplicate_id["entries"][0]["id"]
        self._assert_contract_error(duplicate_id, "contract-invalid", duplicate_id["entries"][1]["id"])

        duplicate_destination = copy.deepcopy(self.contract_data)
        duplicate_destination["entries"][1]["destination"] = duplicate_destination["entries"][0]["destination"]
        self._assert_contract_error(
            duplicate_destination,
            "contract-invalid",
            duplicate_destination["entries"][1]["id"],
        )

    def test_absolute_and_parent_paths_are_rejected(self) -> None:
        cases = (
            ("source", "/tmp/Info.plist"),
            ("source", "Resources/../Resources/Info.plist"),
            ("destination", "/Contents/Info.plist"),
            ("destination", "Contents/../Info.plist"),
        )

        for field, value in cases:
            with self.subTest(field=field, value=value):
                data = copy.deepcopy(self.contract_data)
                data["entries"][0][field] = value
                self._assert_contract_error(data, "contract-invalid", data["entries"][0]["id"])

    def test_source_symlink_cannot_escape_repository(self) -> None:
        with tempfile.TemporaryDirectory() as repository_directory, tempfile.TemporaryDirectory() as outside_directory:
            repository = Path(repository_directory)
            outside = Path(outside_directory) / "outside.txt"
            outside.write_text("outside", encoding="utf-8")
            (repository / "escape").symlink_to(outside)
            data = {
                "schemaVersion": 1,
                "manifestFileName": "FlowtypeBundleManifest.json",
                "entries": [
                    {
                        "id": "escaped-source",
                        "kind": "file",
                        "source": "escape",
                        "destination": "Contents/Resources/escape",
                        "required": True,
                        "executable": False,
                        "inspectionGroup": "bundled-qwen-helper",
                        "swiftPMResource": False,
                    }
                ],
                "forbiddenPatterns": [],
            }
            path = repository / "contract.json"
            path.write_text(json.dumps(data), encoding="utf-8")

            with self.assertRaises(self.module._ContractError) as context:
                self.module._load_contract_file(path, repository)

        self.assertEqual(context.exception.code, "contract-invalid")
        self.assertEqual(context.exception.artifact_id, "escaped-source")

    def test_source_symlink_within_repository_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as repository_directory:
            repository = Path(repository_directory)
            target = repository / "target.txt"
            target.write_text("target\n", encoding="utf-8")
            (repository / "linked-source").symlink_to(target.name)
            data = {
                "schemaVersion": 1,
                "manifestFileName": "FlowtypeBundleManifest.json",
                "entries": [
                    {
                        "id": "linked-source",
                        "kind": "file",
                        "source": "linked-source",
                        "destination": "Contents/Resources/linked-source",
                        "required": True,
                        "executable": False,
                        "inspectionGroup": "bundled-qwen-helper",
                        "swiftPMResource": False,
                    }
                ],
                "forbiddenPatterns": [],
            }
            path = repository / "contract.json"
            path.write_text(json.dumps(data), encoding="utf-8")

            with self.assertRaises(self.module._ContractError) as context:
                self.module._load_contract_file(path, repository)

        self.assertEqual(context.exception.code, "contract-invalid")
        self.assertEqual(context.exception.artifact_id, "linked-source")
        self.assertIn("must not contain symlinks", str(context.exception))

    def test_source_symlink_loop_has_stable_contract_error(self) -> None:
        with tempfile.TemporaryDirectory() as repository_directory:
            repository = Path(repository_directory)
            (repository / "loop").symlink_to("loop")
            data = {
                "schemaVersion": 1,
                "manifestFileName": "FlowtypeBundleManifest.json",
                "entries": [
                    {
                        "id": "loop-source",
                        "kind": "file",
                        "source": "loop",
                        "destination": "Contents/Resources/loop",
                        "required": True,
                        "executable": False,
                        "inspectionGroup": "bundled-qwen-helper",
                        "swiftPMResource": False,
                    },
                    {
                        "id": "bundle-manifest",
                        "kind": "generated",
                        "destination": "Contents/Resources/FlowtypeBundleManifest.json",
                        "required": True,
                        "executable": False,
                        "inspectionGroup": "app-binary",
                        "swiftPMResource": False,
                    },
                ],
                "forbiddenPatterns": [],
            }
            path = repository / "contract.json"
            path.write_text(json.dumps(data), encoding="utf-8")

            with self.assertRaises(self.module._ContractError) as context:
                self.module._load_contract_file(path, repository)

        self.assertEqual(context.exception.code, "contract-invalid")
        self.assertEqual(context.exception.artifact_id, "loop-source")
        self.assertTrue(str(context.exception).startswith("contract-invalid [loop-source]"))

    def test_destination_prefix_collision_is_rejected(self) -> None:
        data = copy.deepcopy(self.contract_data)
        data["entries"].append(
            {
                "id": "destination-child",
                "kind": "file",
                "source": "Resources/Flowtype-logo.svg",
                "destination": f'{data["entries"][0]["destination"]}/child',
                "required": True,
                "executable": False,
                "inspectionGroup": "flowtype-icon",
                "swiftPMResource": False,
            }
        )

        self._assert_contract_error(data, "contract-invalid", "destination-child")

    def test_unsupported_schema_has_stable_diagnostic(self) -> None:
        data = copy.deepcopy(self.contract_data)
        data["schemaVersion"] = 2

        self._assert_contract_error(data, "unsupported-schema")

    def test_missing_fields_and_invalid_kinds_have_stable_diagnostics(self) -> None:
        missing_top_level = copy.deepcopy(self.contract_data)
        del missing_top_level["entries"]
        self._assert_contract_error(missing_top_level, "contract-invalid")

        missing_entry_field = copy.deepcopy(self.contract_data)
        artifact_id = missing_entry_field["entries"][0]["id"]
        del missing_entry_field["entries"][0]["required"]
        self._assert_contract_error(missing_entry_field, "contract-invalid", artifact_id)

        invalid_kind = copy.deepcopy(self.contract_data)
        invalid_kind["entries"][0]["kind"] = "directory"
        self._assert_contract_error(invalid_kind, "contract-invalid", artifact_id)

    def test_dynamic_inputs_are_declared_by_name(self) -> None:
        contract = self.module._load_contract()
        inputs = {entry.source_input: entry for entry in contract.entries if entry.source_input is not None}

        self.assertEqual(set(inputs), {"appBinary", "uvBinary"})
        self.assertEqual(inputs["appBinary"].destination, PurePosixPath("Contents/MacOS/Flowtype"))
        self.assertEqual(inputs["uvBinary"].destination, PurePosixPath("Contents/Resources/Tools/uv"))
        self.assertIsNone(inputs["appBinary"].source)
        self.assertIsNone(inputs["uvBinary"].source)

    def test_required_resources_and_helper_tree_are_represented(self) -> None:
        contract = self.module._load_contract()
        destinations = {str(entry.destination): entry for entry in contract.entries}

        expected_destinations = {
            "Contents/Info.plist",
            "Contents/MacOS/Flowtype",
            "Contents/Resources/Flowtype-logo.svg",
            "Contents/Resources/Flowtype-logo.png",
            "Contents/Resources/Flowtype.icns",
            "Contents/Resources/DMGBackground.tiff",
            "Contents/Resources/Qwen-logo.svg",
            "Contents/Resources/HomeCardArtwork-mic.png",
            "Contents/Resources/HomeCardArtwork-wave.png",
            "Contents/Resources/HomeCardArtwork-docs.png",
            "Contents/Resources/HomeCardArtwork-clock.png",
            "Contents/Resources/Tools/uv",
            "Contents/Resources/Helpers/qwen-asr-helper/pyproject.toml",
            "Contents/Resources/Helpers/qwen-asr-helper/uv.lock",
            "Contents/Resources/Helpers/qwen-asr-helper/README.md",
            "Contents/Resources/Helpers/qwen-asr-helper/qwen_asr_helper",
            "Contents/Resources/Helpers/qwen-asr-helper/helper_manifest.json",
            "Contents/Resources/FlowtypeBundleManifest.json",
        }
        self.assertTrue(expected_destinations.issubset(destinations))
        self.assertTrue(all(destinations[path].required for path in expected_destinations))
        helper_tree = destinations["Contents/Resources/Helpers/qwen-asr-helper/qwen_asr_helper"]
        self.assertEqual(helper_tree.kind, "tree")
        self.assertEqual(helper_tree.source, PurePosixPath("Helpers/qwen-asr-helper/qwen_asr_helper"))

    def test_swiftpm_resources_match_current_package_resources(self) -> None:
        contract = self.module._load_contract()
        sources = {str(entry.source) for entry in contract.entries if entry.swiftpm_resource}

        self.assertEqual(
            sources,
            {
                "Resources/Info.plist",
                "Resources/Flowtype-logo.svg",
                "Resources/Flowtype-logo.png",
                "Resources/Flowtype.icns",
                "Resources/Qwen-logo.svg",
                "Resources/HomeCardArtwork-mic.png",
                "Resources/HomeCardArtwork-wave.png",
                "Resources/HomeCardArtwork-docs.png",
                "Resources/HomeCardArtwork-clock.png",
            },
        )

    def test_forbidden_helper_patterns_cover_generated_and_test_content(self) -> None:
        contract = self.module._load_contract()

        helper_rule = next(
            rule
            for rule in contract.forbidden_patterns
            if rule.root == PurePosixPath("Contents/Resources/Helpers/qwen-asr-helper")
        )
        self.assertTrue({".venv", "__pycache__", ".pytest_cache", "tests", "*.pyc"}.issubset(helper_rule.patterns))


class _BundleFixture(unittest.TestCase):
    def setUp(self) -> None:
        self.module = importlib.import_module("script.app_bundle")
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.repo_root = Path(self.temporary_directory.name) / "repo"
        self.repo_root.mkdir()
        source_root = Path(__file__).resolve().parents[2]
        contract_data = json.loads(
            (source_root / "config" / "app-bundle-contract.json").read_text(encoding="utf-8")
        )
        self.contract_path = self.repo_root / "config" / "app-bundle-contract.json"
        self.contract_path.parent.mkdir()
        self.contract_path.write_text(json.dumps(contract_data), encoding="utf-8")
        for entry in contract_data["entries"]:
            source = entry.get("source")
            if source is None:
                continue
            path = self.repo_root / source
            if entry["kind"] == "tree":
                path.mkdir(parents=True)
                for name in ("__init__.py", "schemas.py", "server.py"):
                    (path / name).write_text(f"# {name}\n", encoding="utf-8")
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(f"fixture:{entry['id']}\n", encoding="utf-8")
        self.inputs = self.repo_root / "inputs"
        self.inputs.mkdir()
        self.app_binary = self.inputs / "Flowtype"
        self.uv_binary = self.inputs / "uv"
        for path in (self.app_binary, self.uv_binary):
            path.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            path.chmod(0o755)
        self.app = self.repo_root / "dist" / "Flowtype.app"

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    @contextmanager
    def repository_contract(self):
        with (
            mock.patch.object(self.module, "_REPO_ROOT", self.repo_root),
            mock.patch.object(self.module, "_CONTRACT_PATH", self.contract_path),
        ):
            yield

    def assemble(self, **metadata):
        with self.repository_contract():
            return self.module.assemble(
                self.app,
                self.app_binary,
                self.uv_binary,
                **metadata,
            )

    def verify(self):
        with self.repository_contract():
            return self.module.verify(self.app)

    def runtime_manifest(self) -> dict[str, object]:
        return json.loads(
            (self.app / "Contents/Resources/FlowtypeBundleManifest.json").read_text(
                encoding="utf-8"
            )
        )

    def bundle_state(self) -> dict[str, tuple[str, int]]:
        return {
            str(path.relative_to(self.app)): (
                hashlib.sha256(path.read_bytes()).hexdigest(),
                path.stat().st_mtime_ns,
            )
            for path in self.app.rglob("*")
            if path.is_file()
        }


class AssemblyTests(_BundleFixture):
    def test_cli_sanitizes_ordinary_staging_setup_filesystem_errors(self) -> None:
        arguments = [
            "assemble",
            "--app",
            str(self.app),
            "--app-binary",
            str(self.app_binary),
            "--uv",
            str(self.uv_binary),
        ]
        real_mkdir = Path.mkdir

        def fail_destination_parent(path, *args, **kwargs):
            if path == self.app.parent:
                raise PermissionError("/private/secret/destination")
            return real_mkdir(path, *args, **kwargs)

        failures = (
            mock.patch.object(Path, "mkdir", new=fail_destination_parent),
            mock.patch.object(
                self.module.tempfile,
                "mkdtemp",
                side_effect=PermissionError("/private/secret/staging"),
            ),
        )
        for failure in failures:
            with self.subTest(failure=failure):
                stderr = StringIO()
                with self.repository_contract(), failure, redirect_stderr(stderr):
                    status = self.module.main(arguments)
                diagnostic = stderr.getvalue()
                self.assertEqual(status, 1)
                self.assertTrue(diagnostic.startswith("copy-failed:"))
                self.assertNotIn("/private/secret", diagnostic)
                self.assertNotIn("Traceback", diagnostic)

    def test_assemble_produces_fresh_complete_bundle(self) -> None:
        stale = self.app / "Contents/Resources/stale.txt"
        stale.parent.mkdir(parents=True)
        stale.write_text("old", encoding="utf-8")

        inspection = self.assemble()

        self.assertGreater(inspection.checked_entries, 0)
        self.assertFalse(stale.exists())
        self.verify()
        expected = {
            "Contents/Info.plist",
            "Contents/MacOS/Flowtype",
            "Contents/Resources/Flowtype-logo.svg",
            "Contents/Resources/Flowtype-logo.png",
            "Contents/Resources/Flowtype.icns",
            "Contents/Resources/DMGBackground.tiff",
            "Contents/Resources/Qwen-logo.svg",
            "Contents/Resources/HomeCardArtwork-mic.png",
            "Contents/Resources/HomeCardArtwork-wave.png",
            "Contents/Resources/HomeCardArtwork-docs.png",
            "Contents/Resources/HomeCardArtwork-clock.png",
            "Contents/Resources/Tools/uv",
            "Contents/Resources/Helpers/qwen-asr-helper/pyproject.toml",
            "Contents/Resources/Helpers/qwen-asr-helper/uv.lock",
            "Contents/Resources/Helpers/qwen-asr-helper/README.md",
            "Contents/Resources/Helpers/qwen-asr-helper/qwen_asr_helper/__init__.py",
            "Contents/Resources/Helpers/qwen-asr-helper/qwen_asr_helper/schemas.py",
            "Contents/Resources/Helpers/qwen-asr-helper/qwen_asr_helper/server.py",
            "Contents/Resources/Helpers/qwen-asr-helper/helper_manifest.json",
            "Contents/Resources/FlowtypeBundleManifest.json",
        }
        actual = {
            str(path.relative_to(self.app))
            for path in self.app.rglob("*")
            if path.is_file()
        }
        self.assertEqual(actual, expected)
        self.assertTrue(os.access(self.app / "Contents/MacOS/Flowtype", os.X_OK))
        self.assertTrue(os.access(self.app / "Contents/Resources/Tools/uv", os.X_OK))

    def test_helper_tree_excludes_non_runtime_content(self) -> None:
        helper_source = self.repo_root / "Helpers/qwen-asr-helper/qwen_asr_helper"
        (helper_source / ".venv/bin").mkdir(parents=True)
        (helper_source / ".venv/bin/python").write_text("bad", encoding="utf-8")
        (helper_source / "__pycache__").mkdir()
        (helper_source / "__pycache__/server.pyc").write_bytes(b"bad")
        (helper_source / ".pytest_cache").mkdir()
        (helper_source / ".pytest_cache/state").write_text("bad", encoding="utf-8")
        (helper_source / "tests").mkdir()
        (helper_source / "tests/test_server.py").write_text("bad", encoding="utf-8")

        self.assemble()

        bundled = self.app / "Contents/Resources/Helpers/qwen-asr-helper/qwen_asr_helper"
        for forbidden in (".venv", "__pycache__", ".pytest_cache", "tests"):
            self.assertFalse((bundled / forbidden).exists())
        self.assertFalse(any(bundled.rglob("*.pyc")))

    def test_missing_or_non_executable_dynamic_inputs_fail(self) -> None:
        self.app_binary.unlink()
        with self.assertRaises(self.module._ContractError) as missing:
            self.assemble()
        self.assertEqual(missing.exception.code, "source-missing")
        self.assertEqual(missing.exception.artifact_id, "app-binary")

        self.app_binary.write_text("binary", encoding="utf-8")
        self.app_binary.chmod(0o644)
        with self.assertRaises(self.module._ContractError) as non_executable:
            self.assemble()
        self.assertEqual(non_executable.exception.code, "not-executable")
        self.assertEqual(non_executable.exception.artifact_id, "app-binary")

    def test_missing_required_repo_source_fails_and_preserves_destination(self) -> None:
        marker = self.app / "previous.txt"
        marker.parent.mkdir(parents=True)
        marker.write_text("previous", encoding="utf-8")
        (self.repo_root / "Resources/Qwen-logo.svg").unlink()

        with self.assertRaises(self.module._ContractError) as context:
            self.assemble()

        self.assertEqual(context.exception.code, "source-missing")
        self.assertEqual(context.exception.artifact_id, "qwen-logo")
        self.assertEqual(marker.read_text(encoding="utf-8"), "previous")

    def test_missing_info_plist_fails_through_contract_without_fallback(self) -> None:
        (self.repo_root / "Resources/Info.plist").unlink()

        with self.assertRaises(self.module._ContractError) as context:
            self.assemble()

        self.assertEqual(context.exception.code, "source-missing")
        self.assertEqual(context.exception.artifact_id, "app-info-plist")
        self.assertFalse((self.app / "Contents/Info.plist").exists())

    def test_failed_staged_verification_preserves_previous_destination(self) -> None:
        marker = self.app / "previous.txt"
        marker.parent.mkdir(parents=True)
        marker.write_text("previous", encoding="utf-8")
        original_inspect = self.module._inspect_bundle

        def fail_staging(bundle, *args, **kwargs):
            if bundle != self.app:
                raise self.module._ContractError("bundle-incomplete", "forced staged failure")
            return original_inspect(bundle, *args, **kwargs)

        with mock.patch.object(self.module, "_inspect_bundle", side_effect=fail_staging):
            with self.assertRaises(self.module._ContractError):
                self.assemble()

        self.assertEqual(marker.read_text(encoding="utf-8"), "previous")

    def test_failed_atomic_replacement_restores_previous_destination(self) -> None:
        marker = self.app / "previous.txt"
        marker.parent.mkdir(parents=True)
        marker.write_text("previous", encoding="utf-8")
        real_replace = os.replace
        failed_new_bundle = False

        def fail_new_bundle(source, destination):
            nonlocal failed_new_bundle
            source_path = Path(source)
            destination_path = Path(destination)
            if (
                not failed_new_bundle
                and ".staging-" in source_path.name
                and destination_path == self.app
            ):
                failed_new_bundle = True
                raise OSError("forced replacement failure")
            return real_replace(source, destination)

        with mock.patch.object(self.module.os, "replace", side_effect=fail_new_bundle):
            with self.assertRaises(self.module._ContractError) as context:
                self.assemble()

        self.assertTrue(failed_new_bundle)
        self.assertEqual(context.exception.code, "copy-failed")
        self.assertEqual(marker.read_text(encoding="utf-8"), "previous")

    def test_backup_cleanup_failure_does_not_report_committed_replacement_as_failed(self) -> None:
        marker = self.app / "previous.txt"
        marker.parent.mkdir(parents=True)
        marker.write_text("previous", encoding="utf-8")
        real_rmtree = shutil.rmtree

        def fail_backup_cleanup(path, *args, **kwargs):
            if ".backup-" in Path(path).name:
                raise PermissionError("forced backup cleanup failure")
            return real_rmtree(path, *args, **kwargs)

        with mock.patch.object(self.module.shutil, "rmtree", side_effect=fail_backup_cleanup):
            inspection = self.assemble()

        self.assertGreater(inspection.checked_entries, 0)
        self.assertFalse(marker.exists())
        self.verify()
        self.assertEqual(len(list(self.app.parent.glob(".Flowtype.app.backup-*"))), 1)

    def test_destination_symlink_is_rejected_without_touching_target(self) -> None:
        outside = self.repo_root / "outside"
        outside.mkdir()
        marker = outside / "marker"
        marker.write_text("safe", encoding="utf-8")
        self.app.parent.mkdir(parents=True)
        self.app.symlink_to(outside, target_is_directory=True)

        with self.assertRaises(self.module._ContractError) as context:
            self.assemble()

        self.assertEqual(context.exception.code, "destination-unsafe")
        self.assertEqual(marker.read_text(encoding="utf-8"), "safe")

    def test_tree_symlink_escape_cannot_copy_outside_staging(self) -> None:
        outside = self.repo_root / "outside.py"
        outside.write_text("secret", encoding="utf-8")
        helper_source = self.repo_root / "Helpers/qwen-asr-helper/qwen_asr_helper"
        (helper_source / "escape.py").symlink_to(outside)

        with self.assertRaises(self.module._ContractError) as context:
            self.assemble()

        self.assertEqual(context.exception.code, "source-type-mismatch")
        self.assertEqual(context.exception.artifact_id, "helper-python")
        self.assertFalse(self.app.exists())

    def test_generated_manifests_are_deterministic_and_bundle_relative(self) -> None:
        metadata = {
            "source_date": "2026-07-11T12:00:00Z",
            "source_commit": "abc1234",
            "helper_version": "2026.07.11-test",
        }
        self.assemble(**metadata)
        first_helper = (
            self.app / "Contents/Resources/Helpers/qwen-asr-helper/helper_manifest.json"
        ).read_bytes()
        first_runtime = (
            self.app / "Contents/Resources/FlowtypeBundleManifest.json"
        ).read_bytes()
        shutil.rmtree(self.app)

        self.assemble(**metadata)

        self.assertEqual(
            (self.app / "Contents/Resources/Helpers/qwen-asr-helper/helper_manifest.json").read_bytes(),
            first_helper,
        )
        self.assertEqual(
            (self.app / "Contents/Resources/FlowtypeBundleManifest.json").read_bytes(),
            first_runtime,
        )
        helper = json.loads(first_helper)
        uv_lock = self.app / "Contents/Resources/Helpers/qwen-asr-helper/uv.lock"
        self.assertEqual(helper["requires_uv_lock_hash"], hashlib.sha256(uv_lock.read_bytes()).hexdigest())
        self.assertEqual(helper["created_at"], metadata["source_date"])
        self.assertEqual(helper["source_commit"], metadata["source_commit"])
        self.assertEqual(helper["flowtype_helper_version"], metadata["helper_version"])

        runtime = json.loads(first_runtime)
        self.assertEqual(runtime["runtimeSchemaVersion"], 1)
        self.assertRegex(runtime["authoringContractSHA256"], r"^[0-9a-f]{64}$")
        paths = [entry["relativePath"] for entry in runtime["entries"]]
        self.assertEqual(paths, sorted(paths))
        self.assertIn(
            "helper-python:qwen_asr_helper/schemas.py",
            {entry["artifactID"] for entry in runtime["entries"]},
        )
        self.assertFalse(any(str(self.repo_root) in json.dumps(entry) for entry in runtime["entries"]))


class VerificationTests(_BundleFixture):
    def setUp(self) -> None:
        super().setUp()
        self.assemble(
            source_date="2026-07-11T12:00:00Z",
            source_commit="abc1234",
            helper_version="2026.07.11-test",
        )

    def test_verify_rejects_forbidden_content(self) -> None:
        helper = self.app / "Contents/Resources/Helpers/qwen-asr-helper"
        injected = (
            helper / ".venv/file",
            helper / "__pycache__/file",
            helper / ".pytest_cache/file",
            helper / "tests/file",
            helper / "injected.pyc",
        )
        for path in injected:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("bad", encoding="utf-8")
            with self.subTest(path=path):
                with self.assertRaises(self.module._ContractError) as context:
                    self.verify()
                self.assertEqual(context.exception.code, "forbidden-content")
            if path.is_file():
                path.unlink()
            parent = path.parent
            while parent != helper and not any(parent.iterdir()):
                parent.rmdir()
                parent = parent.parent

    def test_deleting_each_required_artifact_reports_stable_identity(self) -> None:
        manifest = self.runtime_manifest()
        for entry in manifest["entries"]:
            artifact_path = self.app / entry["relativePath"]
            saved = artifact_path.read_bytes()
            mode = artifact_path.stat().st_mode
            artifact_path.unlink()
            with self.subTest(artifact=entry["artifactID"]):
                with self.assertRaises(self.module._ContractError) as context:
                    self.verify()
                self.assertEqual(context.exception.artifact_id, entry["artifactID"])
                self.assertIn(entry["inspectionGroup"], str(context.exception))
            artifact_path.write_bytes(saved)
            artifact_path.chmod(mode)

    def test_missing_or_symlinked_runtime_manifest_reports_stable_identity_and_group(self) -> None:
        manifest_path = self.app / "Contents/Resources/FlowtypeBundleManifest.json"
        saved = manifest_path.read_bytes()
        outside = self.repo_root / "outside-runtime-manifest.json"
        outside.write_bytes(saved)
        replacements = (None, outside)
        for replacement in replacements:
            with self.subTest(replacement=replacement):
                manifest_path.unlink(missing_ok=True)
                if replacement is not None:
                    manifest_path.symlink_to(replacement)
                with self.assertRaises(self.module._ContractError) as context:
                    self.verify()
                self.assertEqual(context.exception.code, "bundle-incomplete")
                self.assertEqual(context.exception.artifact_id, "bundle-manifest")
                self.assertIn("app-binary", str(context.exception))
        manifest_path.unlink(missing_ok=True)
        manifest_path.write_bytes(saved)

    def test_verify_rejects_symlinked_bundle_ancestor_even_when_target_stays_inside_bundle(self) -> None:
        resources = self.app / "Contents/Resources"
        relocated = self.app / "Contents/RealResources"
        resources.rename(relocated)
        resources.symlink_to(relocated.name, target_is_directory=True)

        with self.assertRaises(self.module._ContractError) as context:
            self.verify()

        self.assertEqual(context.exception.code, "bundle-incomplete")
        self.assertEqual(context.exception.artifact_id, "bundle-manifest")

    def test_manifest_cannot_authorize_deleted_contract_artifact(self) -> None:
        schemas_id = "helper-python:qwen_asr_helper/schemas.py"
        manifest_path = self.app / "Contents/Resources/FlowtypeBundleManifest.json"
        manifest = self.runtime_manifest()
        manifest["entries"] = [entry for entry in manifest["entries"] if entry["artifactID"] != schemas_id]
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        (self.app / "Contents/Resources/Helpers/qwen-asr-helper/qwen_asr_helper/schemas.py").unlink()

        with self.assertRaises(self.module._ContractError) as context:
            self.verify()

        self.assertEqual(context.exception.code, "bundle-incomplete")
        self.assertEqual(context.exception.artifact_id, schemas_id)

    def test_missing_malformed_or_hash_mismatched_manifest_fails_closed(self) -> None:
        manifest_path = self.app / "Contents/Resources/FlowtypeBundleManifest.json"
        valid = manifest_path.read_bytes()
        cases = (None, b"not-json", valid.replace(b'"runtimeSchemaVersion": 1', b'"runtimeSchemaVersion": 2'))
        for replacement in cases:
            with self.subTest(replacement=replacement):
                if replacement is None:
                    manifest_path.unlink()
                else:
                    manifest_path.write_bytes(replacement)
                with self.assertRaises(self.module._ContractError):
                    self.verify()
                manifest_path.write_bytes(valid)

        manifest = json.loads(valid)
        manifest["authoringContractSHA256"] = "0" * 64
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaises(self.module._ContractError) as mismatch:
            self.verify()
        self.assertEqual(mismatch.exception.code, "bundle-incomplete")

    def test_helper_manifest_hash_mismatch_fails(self) -> None:
        helper_manifest = self.app / "Contents/Resources/Helpers/qwen-asr-helper/helper_manifest.json"
        data = json.loads(helper_manifest.read_text(encoding="utf-8"))
        data["requires_uv_lock_hash"] = "0" * 64
        helper_manifest.write_text(json.dumps(data), encoding="utf-8")

        with self.assertRaises(self.module._ContractError) as context:
            self.verify()

        self.assertEqual(context.exception.code, "helper-manifest-invalid")
        self.assertEqual(context.exception.artifact_id, "helper-manifest")

    def test_helper_manifest_rejects_malformed_schema_fields(self) -> None:
        helper_manifest = self.app / "Contents/Resources/Helpers/qwen-asr-helper/helper_manifest.json"
        valid = json.loads(helper_manifest.read_text(encoding="utf-8"))
        cases = (
            ("helper_schema", "1"),
            ("helper_schema", True),
            ("flowtype_helper_version", ""),
            ("flowtype_helper_version", 1),
            ("source_commit", ""),
            ("source_commit", None),
            ("created_at", ""),
            ("created_at", []),
            ("requires_uv_lock_hash", "f" * 63),
            ("requires_uv_lock_hash", "g" * 64),
        )
        for field, malformed in cases:
            with self.subTest(field=field, malformed=malformed):
                data = copy.deepcopy(valid)
                data[field] = malformed
                helper_manifest.write_text(json.dumps(data), encoding="utf-8")
                with self.assertRaises(self.module._ContractError) as context:
                    self.verify()
                self.assertEqual(context.exception.code, "helper-manifest-invalid")
                self.assertEqual(context.exception.artifact_id, "helper-manifest")

        for field in valid:
            with self.subTest(missing=field):
                data = copy.deepcopy(valid)
                del data[field]
                helper_manifest.write_text(json.dumps(data), encoding="utf-8")
                with self.assertRaises(self.module._ContractError) as context:
                    self.verify()
                self.assertEqual(context.exception.code, "helper-manifest-invalid")

    def test_verify_is_read_only(self) -> None:
        before = self.bundle_state()
        time.sleep(0.01)

        self.verify()

        self.assertEqual(self.bundle_state(), before)


if __name__ == "__main__":
    unittest.main()
