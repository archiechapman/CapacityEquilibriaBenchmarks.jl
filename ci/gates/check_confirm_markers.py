#!/usr/bin/env python3
"""Check that every CONFIRM marker names a ledger entry, and that the entry is exploratory.

The TreeComposedOPF convention made checkable. A CONFIRM marks a fact reconstructed from
partial sources: verify it against the paper or the installed package before building on it.
A CONFIRM with no id is a doubt only its author can resolve, and only while they still
remember it (QUALITY.md, the CONFIRM convention).

Run: after check_findings_ledger.py, whose ledger this gate reads. A failing ledger makes
this gate's answer unreliable rather than wrong.

Usage:
    python check_confirm_markers.py [ROOT] --check [--strict] [--json]

Null signature:
    A repo with no CONFIRM markers returns `inapplicable`. The dangerous false pass here is a
    scan that silently skipped the tree the markers are in — so `passed` reports how many
    markers were found and how many files were scanned, and finding zero markers in zero
    scanned files is `indeterminate`, not `inapplicable`.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from _gatelib import Report, parse_field_block, read_text, run_gate, walk_files

SCAN_SUFFIXES = [
    ".py", ".jl", ".r", ".m", ".md", ".qmd", ".toml", ".yaml", ".yml",
    ".sh", ".ipynb", ".txt", ".tex", ".rst",
]

# Prose files describe the convention rather than carry markers, so a CONFIRM inside a
# code span or a fenced block there is a mention, not a use. Source files are scanned whole.
PROSE_SUFFIXES = {".md", ".qmd", ".rst", ".tex", ".txt"}
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
FENCE_RE = re.compile(r"^\s*(```|~~~)")

# CONFIRM(F-0012): what needs verifying
TAGGED_RE = re.compile(r"\bCONFIRM\s*\(\s*(F-\d{4})\s*\)\s*:?\s*(.*)")
# Any CONFIRM at all, so we can find the untagged ones.
ANY_RE = re.compile(r"\bCONFIRM\b")
ENTRY_RE = re.compile(r"^##\s+(F-\d{4})\s*[-—]{1,2}", re.MULTILINE)


def scannable_lines(path: Path) -> list[tuple[int, str]]:
    """(lineno, line) pairs, with prose mentions of CONFIRM removed from prose files."""
    lines = read_text(path).splitlines()
    if path.suffix.lower() not in PROSE_SUFFIXES:
        return list(enumerate(lines, start=1))
    out: list[tuple[int, str]] = []
    in_fence = False
    for lineno, line in enumerate(lines, start=1):
        if FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        out.append((lineno, INLINE_CODE_RE.sub("", line)))
    return out


def ledger_tiers(root: Path) -> dict[str, str]:
    """id -> tier, for whatever FINDINGS.md holds. Empty dict if there is no ledger."""
    ledger = root / "FINDINGS.md"
    if not ledger.is_file():
        return {}
    text = read_text(ledger)
    tiers: dict[str, str] = {}
    blocks = ENTRY_RE.split(text)
    # blocks = [preamble, id1, body1, id2, body2, ...]
    for i in range(1, len(blocks) - 1, 2):
        fid, body = blocks[i], blocks[i + 1]
        tiers[fid] = parse_field_block(body.splitlines()).get("tier", "")
    return tiers


def check(root: Path, args: argparse.Namespace) -> Report:
    # This gate's own source spells the convention out in regexes; templates are slots, not content.
    scanned, ignored = walk_files(root, SCAN_SUFFIXES)
    files = [
        f for f in scanned
        if f.name != "check_confirm_markers.py" and "templates" not in f.parts
    ]
    skipped = f" ({ignored} ignored by .guardrails-ignore)" if ignored else ""

    if not files:
        return Report.indeterminate(
            "no scannable files found under this root",
            ["nothing was scanned, so 'no unregistered markers' would be an empty claim"],
        )

    tagged: list[tuple[Path, int, str, str]] = []
    untagged: list[tuple[Path, int, str]] = []

    for path in files:
        for lineno, line in scannable_lines(path):
            if not ANY_RE.search(line):
                continue
            m = TAGGED_RE.search(line)
            rel = path.relative_to(root)
            if m:
                tagged.append((rel, lineno, m.group(1), m.group(2).strip()))
            else:
                untagged.append((rel, lineno, line.strip()[:90]))

    if not tagged and not untagged:
        return Report.inapplicable(f"no CONFIRM markers in {len(files)} scanned files{skipped}")

    problems: list[str] = []
    for rel, lineno, snippet in untagged:
        problems.append(
            f"{rel}:{lineno}: bare CONFIRM with no ledger id — use CONFIRM(F-NNNN): what to verify  |  {snippet}"
        )

    tiers = ledger_tiers(root)
    if tagged and not tiers:
        return Report.failed(
            f"{len(tagged)} tagged CONFIRM marker(s) but no FINDINGS.md to resolve them against",
            [f"{rel}:{lineno}: CONFIRM({fid}) — {note}" for rel, lineno, fid, note in tagged[:20]]
            + ([f"...and {len(tagged) - 20} more"] if len(tagged) > 20 else [])
            + problems,
        )

    for rel, lineno, fid, note in tagged:
        if fid not in tiers:
            problems.append(f"{rel}:{lineno}: CONFIRM({fid}) names no entry in FINDINGS.md")
        elif tiers[fid] != "exploratory":
            problems.append(
                f"{rel}:{lineno}: CONFIRM({fid}) points at a {tiers[fid]!r} entry — a confirmed "
                "fact cannot still be reconstructed-and-unverified; either the marker is stale "
                "or the tier is wrong"
            )
        if not note:
            problems.append(f"{rel}:{lineno}: CONFIRM({fid}) says what to verify nowhere on the line")

    return Report.from_problems(
        problems,
        ok_summary=(
            f"{len(tagged)} CONFIRM marker(s) across {len(files)} files{skipped}, "
            "all resolving to exploratory entries"
        ),
        bad_summary="{n} problem(s) with CONFIRM markers",
    )


if __name__ == "__main__":
    run_gate(check, description=__doc__)
