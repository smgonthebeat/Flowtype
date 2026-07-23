#!/usr/bin/env python3
"""Canonical Flowtype app-bundle contract command implementation."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import datetime as _datetime
import fnmatch
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import uuid
from typing import Any, Literal


_SUPPORTED_SCHEMA_VERSION = 1
_REPO_ROOT = Path(__file__).resolve().parent.parent
_CONTRACT_PATH = _REPO_ROOT / "config" / "app-bundle-contract.json"
_ENTRY_KINDS = frozenset({"file", "tree", "input", "generated"})
_SUPPORTED_RUNTIME_SCHEMA_VERSION = 1
_HELPER_ROOT = PurePosixPath("Contents/Resources/Helpers/qwen-asr-helper")
_BUNDLE_MANIFEST_ID = "bundle-manifest"
_APP_BUNDLE_MODE = 0o755


@dataclass(frozen=True)
class _Entry:
    artifact_id: str
    kind: Literal["file", "tree", "input", "generated"]
    destination: PurePosixPath
    source: PurePosixPath | None
    source_input: str | None
    required: bool
    executable: bool
    inspection_group: str
    swiftpm_resource: bool
    include: tuple[str, ...] = ()
    exclude: tuple[str, ...] = ()


@dataclass(frozen=True)
class _ForbiddenRule:
    root: PurePosixPath
    patterns: frozenset[str]


@dataclass(frozen=True)
class _Contract:
    schema_version: int
    manifest_file_name: str
    entries: tuple[_Entry, ...]
    forbidden_patterns: tuple[_ForbiddenRule, ...]


@dataclass(frozen=True)
class _Inspection:
    checked_entries: int


class _ContractError(Exception):
    def __init__(
        self,
        code: str,
        message: str,
        artifact_id: str | None = None,
    ) -> None:
        self.code = code
        self.artifact_id = artifact_id
        prefix = f"{code} [{artifact_id}]" if artifact_id else code
        super().__init__(f"{prefix}: {message}")


def _invalid(message: str, artifact_id: str | None = None) -> _ContractError:
    return _ContractError("contract-invalid", message, artifact_id)


def _require_mapping(value: Any, label: str, artifact_id: str | None = None) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise _invalid(f"{label} must be an object", artifact_id)
    return value


def _required(mapping: dict[str, Any], field: str, artifact_id: str | None = None) -> Any:
    if field not in mapping:
        raise _invalid(f"missing field {field}", artifact_id)
    return mapping[field]


def _required_string(mapping: dict[str, Any], field: str, artifact_id: str | None = None) -> str:
    value = _required(mapping, field, artifact_id)
    if not isinstance(value, str) or not value:
        raise _invalid(f"{field} must be a non-empty string", artifact_id)
    return value


def _required_bool(mapping: dict[str, Any], field: str, artifact_id: str | None = None) -> bool:
    value = _required(mapping, field, artifact_id)
    if not isinstance(value, bool):
        raise _invalid(f"{field} must be a boolean", artifact_id)
    return value


def _string_list(mapping: dict[str, Any], field: str, artifact_id: str) -> tuple[str, ...]:
    value = mapping.get(field, [])
    if not isinstance(value, list) or any(not isinstance(item, str) or not item for item in value):
        raise _invalid(f"{field} must be a list of non-empty strings", artifact_id)
    return tuple(value)


def _safe_relative_path(value: str, field: str, artifact_id: str | None = None) -> PurePosixPath:
    path = PurePosixPath(value)
    if not value or path.is_absolute() or path == PurePosixPath(".") or ".." in path.parts:
        raise _invalid(f"{field} must be a safe relative path", artifact_id)
    return path


def _validate_source_within_repo(source: PurePosixPath, repo_root: Path, artifact_id: str) -> None:
    try:
        resolved_root = repo_root.resolve()
        source_path = resolved_root
        for part in source.parts:
            source_path /= part
            if source_path.is_symlink():
                raise _invalid("source path must not contain symlinks", artifact_id)
        resolved_source = source_path.resolve(strict=False)
    except _ContractError:
        raise
    except (OSError, RuntimeError) as error:
        raise _invalid("source could not be resolved safely", artifact_id) from error
    if not resolved_source.is_relative_to(resolved_root):
        raise _invalid("source resolves outside repository", artifact_id)


def _parse_entry(raw_value: Any, repo_root: Path) -> _Entry:
    raw = _require_mapping(raw_value, "entry")
    artifact_id = _required_string(raw, "id")
    kind = _required_string(raw, "kind", artifact_id)
    if kind not in _ENTRY_KINDS:
        raise _invalid(f"unsupported kind {kind}", artifact_id)

    destination = _safe_relative_path(
        _required_string(raw, "destination", artifact_id),
        "destination",
        artifact_id,
    )
    source_value = raw.get("source")
    source_input_value = raw.get("sourceInput")

    if kind in {"file", "tree"}:
        if not isinstance(source_value, str) or not source_value or source_input_value is not None:
            raise _invalid(f"{kind} entry requires only source", artifact_id)
        source = _safe_relative_path(source_value, "source", artifact_id)
        _validate_source_within_repo(source, repo_root, artifact_id)
        source_input = None
    elif kind == "input":
        if source_value is not None or not isinstance(source_input_value, str) or not source_input_value:
            raise _invalid("input entry requires only sourceInput", artifact_id)
        source = None
        source_input = source_input_value
    else:
        if source_value is not None or source_input_value is not None:
            raise _invalid("generated entry cannot declare a source", artifact_id)
        source = None
        source_input = None

    include = _string_list(raw, "include", artifact_id)
    exclude = _string_list(raw, "exclude", artifact_id)
    if kind != "tree" and (include or exclude):
        raise _invalid("include and exclude are valid only for tree entries", artifact_id)

    return _Entry(
        artifact_id=artifact_id,
        kind=kind,
        destination=destination,
        source=source,
        source_input=source_input,
        required=_required_bool(raw, "required", artifact_id),
        executable=_required_bool(raw, "executable", artifact_id),
        inspection_group=_required_string(raw, "inspectionGroup", artifact_id),
        swiftpm_resource=_required_bool(raw, "swiftPMResource", artifact_id),
        include=include,
        exclude=exclude,
    )


def _validate_unique_entries(entries: tuple[_Entry, ...]) -> None:
    ids: set[str] = set()
    destinations: dict[PurePosixPath, str] = {}
    for entry in entries:
        if entry.artifact_id in ids:
            raise _invalid("duplicate artifact id", entry.artifact_id)
        ids.add(entry.artifact_id)

        if entry.destination in destinations:
            raise _invalid("duplicate destination", entry.artifact_id)
        for destination in destinations:
            if destination in entry.destination.parents or entry.destination in destination.parents:
                raise _invalid("destination prefix collision", entry.artifact_id)
        destinations[entry.destination] = entry.artifact_id


def _parse_forbidden_rule(raw_value: Any) -> _ForbiddenRule:
    raw = _require_mapping(raw_value, "forbidden pattern")
    root = _safe_relative_path(_required_string(raw, "root"), "forbidden root")
    patterns_value = _required(raw, "patterns")
    if (
        not isinstance(patterns_value, list)
        or not patterns_value
        or any(not isinstance(pattern, str) or not pattern for pattern in patterns_value)
    ):
        raise _invalid("forbidden patterns must be a non-empty string list")
    return _ForbiddenRule(root=root, patterns=frozenset(patterns_value))


def _decode_contract(raw_value: Any, repo_root: Path) -> _Contract:
    raw = _require_mapping(raw_value, "contract")
    schema_version = _required(raw, "schemaVersion")
    if not isinstance(schema_version, int) or isinstance(schema_version, bool):
        raise _invalid("schemaVersion must be an integer")
    if schema_version != _SUPPORTED_SCHEMA_VERSION:
        raise _ContractError("unsupported-schema", f"unsupported schema version {schema_version}")

    manifest_file_path = _safe_relative_path(
        _required_string(raw, "manifestFileName"),
        "manifestFileName",
    )

    entries_value = _required(raw, "entries")
    if not isinstance(entries_value, list) or not entries_value:
        raise _invalid("entries must be a non-empty list")
    entries = tuple(_parse_entry(entry, repo_root) for entry in entries_value)
    _validate_unique_entries(entries)
    bundle_manifest_entry = next(
        (entry for entry in entries if entry.artifact_id == "bundle-manifest"),
        None,
    )
    expected_manifest_destination = PurePosixPath("Contents/Resources") / manifest_file_path
    if (
        bundle_manifest_entry is None
        or bundle_manifest_entry.kind != "generated"
        or bundle_manifest_entry.destination != expected_manifest_destination
    ):
        raise _invalid(
            "bundle manifest destination must match manifestFileName",
            "bundle-manifest",
        )

    forbidden_value = _required(raw, "forbiddenPatterns")
    if not isinstance(forbidden_value, list):
        raise _invalid("forbiddenPatterns must be a list")

    return _Contract(
        schema_version=schema_version,
        manifest_file_name=str(manifest_file_path),
        entries=entries,
        forbidden_patterns=tuple(_parse_forbidden_rule(rule) for rule in forbidden_value),
    )


def _load_contract_file(contract_path: Path, repo_root: Path) -> _Contract:
    try:
        raw_value = json.loads(contract_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise _invalid("contract could not be read as JSON") from error
    return _decode_contract(raw_value, repo_root)


def _load_contract() -> _Contract:
    return _load_contract_file(_CONTRACT_PATH, _REPO_ROOT)


def _error(code: str, message: str, artifact_id: str | None = None) -> _ContractError:
    return _ContractError(code, message, artifact_id)


def _contract_hash() -> str:
    try:
        return hashlib.sha256(_CONTRACT_PATH.read_bytes()).hexdigest()
    except OSError as error:
        raise _invalid("contract could not be hashed") from error


def _matches_any(path: PurePosixPath, patterns: tuple[str, ...] | frozenset[str]) -> bool:
    value = path.as_posix()
    return any(
        path.match(pattern)
        or fnmatch.fnmatch(path.name, pattern)
        or any(fnmatch.fnmatch(part, pattern) for part in path.parts)
        or fnmatch.fnmatch(value, pattern)
        for pattern in patterns
    )


def _tree_files(entry: _Entry, repo_root: Path) -> tuple[tuple[Path, PurePosixPath], ...]:
    assert entry.source is not None
    source_root = repo_root / Path(*entry.source.parts)
    if not source_root.exists():
        if entry.required:
            raise _error("source-missing", "required source is missing", entry.artifact_id)
        return ()
    if source_root.is_symlink() or not source_root.is_dir():
        raise _error("source-type-mismatch", "tree source must be a real directory", entry.artifact_id)

    files: list[tuple[Path, PurePosixPath]] = []
    try:
        candidates = sorted(source_root.rglob("*"), key=lambda path: path.as_posix())
    except OSError as error:
        raise _error("copy-failed", "tree source could not be enumerated", entry.artifact_id) from error
    for source_path in candidates:
        relative = PurePosixPath(source_path.relative_to(source_root).as_posix())
        if source_path.is_symlink():
            raise _error("source-type-mismatch", "tree source contains a symlink", entry.artifact_id)
        if source_path.is_dir():
            continue
        if not source_path.is_file():
            raise _error("source-type-mismatch", "tree source contains a non-file", entry.artifact_id)
        if entry.include and not _matches_any(relative, entry.include):
            continue
        if _matches_any(relative, entry.exclude):
            continue
        files.append((source_path, relative))
    if entry.required and not files:
        raise _error("source-missing", "required tree has no matching files", entry.artifact_id)
    return tuple(files)


def _validate_file_source(path: Path, entry: _Entry) -> None:
    if not path.exists():
        if entry.required:
            raise _error("source-missing", "required source is missing", entry.artifact_id)
        return
    if path.is_symlink() or not path.is_file():
        raise _error("source-type-mismatch", "source must be a real regular file", entry.artifact_id)
    if entry.executable and not os.access(path, os.X_OK):
        raise _error("not-executable", "source must be executable", entry.artifact_id)


def _source_for_entry(entry: _Entry, inputs: dict[str, Path]) -> Path | None:
    if entry.source is not None:
        return _REPO_ROOT / Path(*entry.source.parts)
    if entry.source_input is not None:
        source = inputs.get(entry.source_input)
        if source is None:
            raise _error("source-missing", "dynamic input was not supplied", entry.artifact_id)
        return source
    return None


def _runtime_entry(
    entry: _Entry,
    artifact_id: str,
    relative_path: PurePosixPath,
) -> dict[str, Any]:
    value: dict[str, Any] = {
        "artifactID": artifact_id,
        "relativePath": relative_path.as_posix(),
        "kind": "file",
        "executable": entry.executable,
        "inspectionGroup": entry.inspection_group,
    }
    if relative_path == _HELPER_ROOT or _HELPER_ROOT in relative_path.parents:
        value["helperRuntimeRelativePath"] = relative_path.relative_to(_HELPER_ROOT).as_posix()
    return value


def _is_forbidden_destination(destination: PurePosixPath, contract: _Contract) -> bool:
    for rule in contract.forbidden_patterns:
        if destination == rule.root or rule.root not in destination.parents:
            continue
        if _matches_any(destination.relative_to(rule.root), rule.patterns):
            return True
    return False


def _compile_runtime_manifest(contract: _Contract) -> dict[str, Any]:
    entries: list[dict[str, Any]] = []
    for entry in contract.entries:
        if entry.artifact_id == _BUNDLE_MANIFEST_ID:
            continue
        if entry.kind == "tree":
            for _source_path, relative in _tree_files(entry, _REPO_ROOT):
                destination = entry.destination / relative
                if _is_forbidden_destination(destination, contract):
                    continue
                helper_relative = destination.relative_to(_HELPER_ROOT)
                artifact_suffix = helper_relative.as_posix()
                entries.append(
                    _runtime_entry(
                        entry,
                        f"{entry.artifact_id}:{artifact_suffix}",
                        destination,
                    )
                )
        else:
            entries.append(_runtime_entry(entry, entry.artifact_id, entry.destination))
    entries.sort(key=lambda value: value["relativePath"])
    forbidden = [
        {"root": rule.root.as_posix(), "patterns": sorted(rule.patterns)}
        for rule in sorted(contract.forbidden_patterns, key=lambda value: value.root.as_posix())
    ]
    return {
        "runtimeSchemaVersion": _SUPPORTED_RUNTIME_SCHEMA_VERSION,
        "authoringContractSHA256": _contract_hash(),
        "entries": entries,
        "forbiddenContent": forbidden,
    }


def _write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _utc_now() -> str:
    return (
        _datetime.datetime.now(_datetime.timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def _default_source_commit() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=_REPO_ROOT,
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except (OSError, subprocess.SubprocessError):
        return "unknown"


def _default_helper_version(created_at: str) -> str:
    try:
        return _datetime.date.fromisoformat(created_at[:10]).strftime("%Y.%m.%d")
    except ValueError:
        return _datetime.datetime.now(_datetime.timezone.utc).date().strftime("%Y.%m.%d")


def _write_helper_manifest(
    bundle: Path,
    *,
    source_date: str | None,
    source_commit: str | None,
    helper_version: str | None,
) -> None:
    helper_root = bundle / Path(*_HELPER_ROOT.parts)
    uv_lock = helper_root / "uv.lock"
    if not uv_lock.is_file() or uv_lock.is_symlink():
        raise _error("generated-artifact-failed", "bundled uv.lock is missing", "helper-manifest")
    created_at = source_date or _utc_now()
    manifest = {
        "helper_schema": 1,
        "flowtype_helper_version": helper_version or _default_helper_version(created_at),
        "source_commit": source_commit or _default_source_commit(),
        "requires_uv_lock_hash": hashlib.sha256(uv_lock.read_bytes()).hexdigest(),
        "created_at": created_at,
    }
    _write_json(helper_root / "helper_manifest.json", manifest)


def _materialize(
    bundle: Path,
    contract: _Contract,
    inputs: dict[str, Path],
    *,
    source_date: str | None,
    source_commit: str | None,
    helper_version: str | None,
) -> None:
    try:
        for entry in contract.entries:
            if entry.kind == "generated":
                continue
            destination = bundle / Path(*entry.destination.parts)
            if entry.kind == "tree":
                for source_path, relative in _tree_files(entry, _REPO_ROOT):
                    target = destination / Path(*relative.parts)
                    if _is_forbidden_destination(entry.destination / relative, contract):
                        continue
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source_path, target, follow_symlinks=False)
                continue
            source = _source_for_entry(entry, inputs)
            assert source is not None
            _validate_file_source(source, entry)
            if not source.exists() and not entry.required:
                continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination, follow_symlinks=False)
            if entry.executable:
                destination.chmod(destination.stat().st_mode | 0o111)
        _write_helper_manifest(
            bundle,
            source_date=source_date,
            source_commit=source_commit,
            helper_version=helper_version,
        )
        runtime_manifest = _compile_runtime_manifest(contract)
        manifest_destination = bundle / "Contents/Resources" / contract.manifest_file_name
        _write_json(manifest_destination, runtime_manifest)
    except _ContractError:
        raise
    except (OSError, UnicodeError) as error:
        raise _error("copy-failed", "bundle content could not be materialized") from error


def _load_runtime_manifest(bundle: Path, contract: _Contract) -> dict[str, Any]:
    manifest_relative = PurePosixPath("Contents/Resources") / contract.manifest_file_name
    manifest_path = _safe_bundle_file(
        bundle,
        manifest_relative,
        _BUNDLE_MANIFEST_ID,
        "app-binary",
    )
    if not manifest_path.is_file():
        raise _error(
            "bundle-incomplete",
            "runtime manifest is missing group=app-binary",
            _BUNDLE_MANIFEST_ID,
        )
    try:
        value = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise _error(
            "bundle-incomplete",
            "runtime manifest is malformed group=app-binary",
            _BUNDLE_MANIFEST_ID,
        ) from error
    if not isinstance(value, dict):
        raise _error(
            "bundle-incomplete",
            "runtime manifest is malformed group=app-binary",
            _BUNDLE_MANIFEST_ID,
        )
    return value


def _manifest_identity(entry: Any) -> tuple[str | None, str | None]:
    if not isinstance(entry, dict):
        return None, None
    artifact_id = entry.get("artifactID")
    group = entry.get("inspectionGroup")
    return (
        artifact_id if isinstance(artifact_id, str) else None,
        group if isinstance(group, str) else None,
    )


def _require_exact_manifest(actual: dict[str, Any], expected: dict[str, Any]) -> None:
    actual_entries = actual.get("entries")
    expected_entries = expected["entries"]
    if isinstance(actual_entries, list):
        actual_by_id = {
            identity[0]: entry
            for entry in actual_entries
            if (identity := _manifest_identity(entry))[0] is not None
        }
        for expected_entry in expected_entries:
            artifact_id = expected_entry["artifactID"]
            if actual_by_id.get(artifact_id) != expected_entry:
                group = expected_entry["inspectionGroup"]
                raise _error(
                    "bundle-incomplete",
                    f"compiled manifest differs from contract group={group}",
                    artifact_id,
                )
    if actual != expected:
        raise _error("bundle-incomplete", "compiled manifest differs from authoring contract", _BUNDLE_MANIFEST_ID)


def _safe_bundle_file(bundle: Path, relative: PurePosixPath, artifact_id: str, group: str) -> Path:
    path = bundle / Path(*relative.parts)
    component_path = bundle
    for component in relative.parts:
        component_path /= component
        if component_path.is_symlink():
            raise _error("bundle-incomplete", f"unsafe artifact path group={group}", artifact_id)
    try:
        resolved_bundle = bundle.resolve(strict=True)
        resolved = path.resolve(strict=False)
    except (OSError, RuntimeError) as error:
        raise _error("bundle-incomplete", f"unsafe artifact path group={group}", artifact_id) from error
    if not resolved.is_relative_to(resolved_bundle):
        raise _error("bundle-incomplete", f"unsafe artifact path group={group}", artifact_id)
    return path


def _inspect_forbidden(bundle: Path, expected: dict[str, Any]) -> None:
    for rule in expected["forbiddenContent"]:
        root_relative = PurePosixPath(rule["root"])
        root = _safe_bundle_file(bundle, root_relative, "bundle-manifest", "bundled-qwen-helper")
        if not root.is_dir():
            raise _error("bundle-incomplete", "forbidden-content root is missing", "bundle-manifest")
        try:
            candidates = root.rglob("*")
            for path in candidates:
                relative = PurePosixPath(path.relative_to(root).as_posix())
                if _matches_any(relative, tuple(rule["patterns"])):
                    raise _error(
                        "forbidden-content",
                        f"forbidden path in group=bundled-qwen-helper: {relative.as_posix()}",
                        "bundle-manifest",
                    )
                if path.is_symlink():
                    raise _error(
                        "forbidden-content",
                        f"symlink in group=bundled-qwen-helper: {relative.as_posix()}",
                        "bundle-manifest",
                    )
        except OSError as error:
            raise _error("bundle-incomplete", "bundle tree could not be inspected") from error


def _inspect_helper_manifest(bundle: Path) -> None:
    helper_root = bundle / Path(*_HELPER_ROOT.parts)
    manifest_path = helper_root / "helper_manifest.json"
    uv_lock = helper_root / "uv.lock"
    try:
        value = json.loads(manifest_path.read_text(encoding="utf-8"))
        actual_hash = hashlib.sha256(uv_lock.read_bytes()).hexdigest()
    except (OSError, UnicodeError, json.JSONDecodeError, TypeError) as error:
        raise _error("helper-manifest-invalid", "helper manifest could not be validated", "helper-manifest") from error
    if not isinstance(value, dict):
        raise _error("helper-manifest-invalid", "helper manifest must be an object", "helper-manifest")
    if type(value.get("helper_schema")) is not int:
        raise _error("helper-manifest-invalid", "helper_schema must be an integer", "helper-manifest")
    for field in ("flowtype_helper_version", "source_commit", "created_at"):
        field_value = value.get(field)
        if not isinstance(field_value, str) or not field_value:
            raise _error(
                "helper-manifest-invalid",
                f"{field} must be a non-empty string",
                "helper-manifest",
            )
    declared_hash = value.get("requires_uv_lock_hash")
    if not isinstance(declared_hash, str) or re.fullmatch(r"[0-9a-fA-F]{64}", declared_hash) is None:
        raise _error(
            "helper-manifest-invalid",
            "requires_uv_lock_hash must be a 64-character hex string",
            "helper-manifest",
        )
    if declared_hash.lower() != actual_hash:
        raise _error("helper-manifest-invalid", "uv.lock hash mismatch", "helper-manifest")


def _inspect_bundle(bundle: Path, contract: _Contract, expected: dict[str, Any]) -> _Inspection:
    if bundle.is_symlink() or not bundle.is_dir():
        raise _error("destination-unsafe", "app destination must be a real directory")
    try:
        bundle_mode = stat.S_IMODE(bundle.stat().st_mode)
    except OSError as error:
        raise _error("bundle-incomplete", "app bundle permissions could not be inspected") from error
    if bundle_mode != _APP_BUNDLE_MODE:
        raise _error(
            "bundle-incomplete",
            f"app bundle permissions must be {_APP_BUNDLE_MODE:o}",
        )
    actual = _load_runtime_manifest(bundle, contract)
    _require_exact_manifest(actual, expected)
    for raw_entry in expected["entries"]:
        artifact_id = raw_entry["artifactID"]
        group = raw_entry["inspectionGroup"]
        relative = PurePosixPath(raw_entry["relativePath"])
        path = _safe_bundle_file(bundle, relative, artifact_id, group)
        if not path.is_file():
            raise _error("bundle-incomplete", f"required file is missing group={group}", artifact_id)
        if raw_entry["executable"] and not os.access(path, os.X_OK):
            raise _error("not-executable", f"required file is not executable group={group}", artifact_id)
    _inspect_forbidden(bundle, expected)
    _inspect_helper_manifest(bundle)
    return _Inspection(checked_entries=len(expected["entries"]))


def _replace_destination(staging: Path, destination: Path) -> None:
    backup: Path | None = None
    try:
        if destination.exists():
            backup = destination.with_name(
                f".{destination.name}.backup-{uuid.uuid4().hex}"
            )
            os.replace(destination, backup)
        try:
            os.replace(staging, destination)
        except OSError:
            if backup is not None and not destination.exists():
                os.replace(backup, destination)
                backup = None
            raise
        if backup is not None:
            try:
                shutil.rmtree(backup)
            except OSError:
                pass
            backup = None
    except OSError as error:
        raise _error("copy-failed", "atomic destination replacement failed") from error
    finally:
        if backup is not None and backup.exists() and not destination.exists():
            try:
                os.replace(backup, destination)
            except OSError:
                pass


def assemble(
    app: Path | str,
    app_binary: Path | str,
    uv: Path | str,
    *,
    helper_version: str | None = None,
    source_commit: str | None = None,
    source_date: str | None = None,
) -> _Inspection:
    destination = Path(app)
    if destination.is_symlink() or (destination.exists() and not destination.is_dir()):
        raise _error("destination-unsafe", "app destination must be a real directory")
    contract = _load_contract()
    inputs = {"appBinary": Path(app_binary), "uvBinary": Path(uv)}
    for entry in contract.entries:
        if entry.kind in {"file", "input"}:
            source = _source_for_entry(entry, inputs)
            assert source is not None
            _validate_file_source(source, entry)
        elif entry.kind == "tree":
            _tree_files(entry, _REPO_ROOT)
    expected = _compile_runtime_manifest(contract)

    try:
        destination.parent.mkdir(parents=True, exist_ok=True)
        staging = Path(
            tempfile.mkdtemp(
                prefix=f".{destination.name}.staging-",
                dir=destination.parent,
            )
        )
    except OSError as error:
        raise _error("copy-failed", "staging directory could not be created") from error
    try:
        try:
            staging.chmod(_APP_BUNDLE_MODE)
        except OSError as error:
            raise _error("copy-failed", "staging directory permissions could not be normalized") from error
        _materialize(
            staging,
            contract,
            inputs,
            source_date=source_date,
            source_commit=source_commit,
            helper_version=helper_version,
        )
        inspection = _inspect_bundle(staging, contract, expected)
        _replace_destination(staging, destination)
        return inspection
    finally:
        if staging.exists():
            shutil.rmtree(staging, ignore_errors=True)


def verify(app: Path | str) -> _Inspection:
    contract = _load_contract()
    expected = _compile_runtime_manifest(contract)
    return _inspect_bundle(Path(app), contract, expected)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Assemble or verify a Flowtype app bundle.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    assemble_parser = subparsers.add_parser("assemble", help="assemble a fresh app bundle")
    assemble_parser.add_argument("--app", required=True, type=Path)
    assemble_parser.add_argument("--app-binary", required=True, type=Path)
    assemble_parser.add_argument("--uv", required=True, type=Path)
    assemble_parser.add_argument("--helper-version")
    assemble_parser.add_argument("--source-commit")
    assemble_parser.add_argument("--source-date")
    verify_parser = subparsers.add_parser("verify", help="verify an app bundle without modifying it")
    verify_parser.add_argument("--app", required=True, type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    try:
        if arguments.command == "assemble":
            assemble(
                arguments.app,
                arguments.app_binary,
                arguments.uv,
                helper_version=arguments.helper_version,
                source_commit=arguments.source_commit,
                source_date=arguments.source_date,
            )
        else:
            verify(arguments.app)
    except _ContractError as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
