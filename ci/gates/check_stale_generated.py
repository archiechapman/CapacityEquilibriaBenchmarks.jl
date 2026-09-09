#!/usr/bin/env python3
"""The write/check pinning engine: fail if a generated artifact is stale against its sources.

ARCHITECTURE.md contract 2. `--write` records the current hash of each source and artifact
listed in `generated.toml`; `--check` recomputes and fails on drift. The baseline is committed,
so the check is a comparison against something a human deliberately wrote down (I3) and never
against something inferred.

This is the generic engine. `sync/check_guardrails_sync.py` is one application of it; a book
repo's corpus check is another.

`generated.toml` lives at the repo root:

    [[artifact]]
    path = "docs/RULE_CATALOG.md"
    sources = ["src/rules/", "src/registry.py"]
    regenerate = "python scripts/gen_catalog.py"
    source_hash = "<written by --write>"
    artifact_hash = "<written by --write>"

Run: after the generators, before commit.

Usage:
    python check_stale_generated.py [ROOT] --check [--strict] [--json]
    python check_stale_generated.py [ROOT] --write

Null signature:
    No generated.toml returns `inapplicable`. A generated.toml listing artifacts whose
    `source_hash` was never written returns `indeterminate`, not `passed` — an unrecorded
    baseline means the gate has nothing to compare against, and reporting that as clean is
    exactly the silent no-op this contract exists to prevent.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # Python < 3.11
    tomllib = None  # type: ignore

from _gatelib import Report, hash_text, read_text, run_gate, SKIP_DIRS

MANIFEST = "generated.toml"
UNSET = {"", "<written by --write>", "TBD", "TODO"}


def hash_paths(root: Path, patterns: list[str]) -> tuple[str, list[str]]:
    """Stable hash over every file named by `patterns` (a file or a directory each).

    The hash covers repo-relative paths as well as contents, so that adding or renaming a
    source file is drift even when no existing file changed."""
    files: list[Path] = []
    missing: list[str] = []
    for pattern in patterns:
        target = root / pattern
        if target.is_file():
            files.append(target)
        elif target.is_dir():
            files.extend(
                p for p in target.rglob("*")
                if p.is_file() and not any(part in SKIP_DIRS for part in p.parts)
            )
        else:
            missing.append(pattern)
    digest = hashlib.sha256()
    for path in sorted(files, key=lambda p: p.relative_to(root).as_posix()):
        digest.update(path.relative_to(root).as_posix().encode("utf-8"))
        digest.update(hash_text(read_text(path)).encode("utf-8"))
    return digest.hexdigest(), missing


def load_manifest(path: Path) -> tuple[list[dict], str | None]:
    if tomllib is None:
        return [], "Python 3.11+ required to read generated.toml (no tomllib)"
    try:
        data = tomllib.loads(read_text(path))
    except Exception as exc:  # malformed TOML is indeterminate, not a content failure
        return [], f"could not parse {MANIFEST}: {exc}"
    return list(data.get("artifact", [])), None


def write_baseline(root: Path, manifest: Path, artifacts: list[dict]) -> Report:
    """Record the current state. Rewrites generated.toml in a fixed, readable shape."""
    lines = [
        "# Generated artifacts and the sources they are generated from.",
        "# Hashes are written by `check_stale_generated.py --write` and checked by `--check`.",
        "# Do not hand-edit the hash fields; rerun --write after regenerating.",
        "",
    ]
    problems: list[str] = []
    for art in artifacts:
        path = art.get("path", "")
        sources = list(art.get("sources", []))
        if not path or not sources:
            problems.append(f"entry {art!r} needs both `path` and `sources`")
            continue
        src_hash, missing = hash_paths(root, sources)
        for m in missing:
            problems.append(f"{path}: source {m!r} does not exist")
        target = root / path
        art_hash = hash_text(read_text(target)) if target.is_file() else ""
        if not target.is_file():
            problems.append(f"{path}: artifact does not exist; generate it before --write")
        lines += [
            "[[artifact]]",
            f'path = "{path}"',
            "sources = [" + ", ".join(f'"{s}"' for s in sources) + "]",
            f'regenerate = "{art.get("regenerate", "")}"',
            f'source_hash = "{src_hash}"',
            f'artifact_hash = "{art_hash}"',
            "",
        ]
    if problems:
        return Report.failed("{n} problem(s); baseline not written".format(n=len(problems)), problems)
    manifest.write_text("\n".join(lines), encoding="utf-8")
    return Report.passed(f"baseline recorded for {len(artifacts)} artifact(s) in {MANIFEST}")


def check(root: Path, args: argparse.Namespace) -> Report:
    manifest = root / MANIFEST
    if not manifest.is_file():
        return Report.inapplicable(f"no {MANIFEST} — this repo declares no generated artifacts")

    artifacts, err = load_manifest(manifest)
    if err:
        return Report.indeterminate(err)
    if not artifacts:
        return Report.inapplicable(f"{MANIFEST} declares no artifacts")

    if args.write:
        return write_baseline(root, manifest, artifacts)

    problems: list[str] = []
    unrecorded: list[str] = []

    for art in artifacts:
        path = art.get("path", "")
        sources = list(art.get("sources", []))
        if not path or not sources:
            problems.append(f"entry {art!r} needs both `path` and `sources`")
            continue
        regenerate = art.get("regenerate", "") or "(no regenerate command recorded)"

        recorded_src = str(art.get("source_hash", ""))
        recorded_art = str(art.get("artifact_hash", ""))
        if recorded_src in UNSET or recorded_art in UNSET:
            unrecorded.append(f"{path}: no baseline recorded; run --write")
            continue

        target = root / path
        if not target.is_file():
            problems.append(f"{path}: generated artifact is missing — run: {regenerate}")
            continue

        src_hash, missing = hash_paths(root, sources)
        for m in missing:
            problems.append(f"{path}: source {m!r} does not exist")
        if src_hash != recorded_src:
            problems.append(f"{path}: sources changed since the baseline — run: {regenerate}, then --write")
        if hash_text(read_text(target)) != recorded_art:
            problems.append(
                f"{path}: the artifact was hand-edited (its hash moved while the baseline did not) "
                "— generated files are never hand-edited; change the source"
            )

    if unrecorded and not problems:
        return Report.indeterminate(
            f"{len(unrecorded)} artifact(s) have no recorded baseline", unrecorded
        )
    problems += unrecorded
    return Report.from_problems(
        problems,
        ok_summary=f"{len(artifacts)} generated artifact(s) match their recorded baselines",
        bad_summary="{n} stale or unrecorded artifact(s)",
    )


if __name__ == "__main__":
    run_gate(check, description=__doc__)
