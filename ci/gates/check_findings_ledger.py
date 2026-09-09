#!/usr/bin/env python3
"""Check that FINDINGS.md entries carry an id, a tier, a boundary and traceable evidence.

Checks paperwork, never science (ARCHITECTURE.md I4). It cannot tell whether a finding is
true; it refuses to let one be stated without the fields that make it checkable by a human.

Run: any time, standalone. No other gate needs to run first.

Usage:
    python check_findings_ledger.py [ROOT] --check [--strict] [--json]

Null signature:
    A repo with no FINDINGS.md returns `inapplicable`, never `passed` — otherwise a repo that
    has never written a finding down would look identical in CI to one whose findings are all
    in good order. A FINDINGS.md that exists but contains no `## F-NNNN` headings is `failed`,
    not `inapplicable`: someone started a ledger and put something else in it.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from _gatelib import (
    Report, is_placeholder, parse_field_block, read_text, run_gate, strip_code_spans,
)

LEDGER_NAMES = ["FINDINGS.md"]

TIERS = {"reproduced", "validated", "exploratory"}
STATUSES = {"open", "settled", "superseded", "dead-end"}
REQUIRED = ["tier", "status", "date", "evidence", "boundary", "supersedes"]

HEADING_RE = re.compile(r"^##\s+(F-\d{4})\s*[-—]{1,2}\s*(.+?)\s*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
ID_REF_RE = re.compile(r"F-\d{4}")


def split_entries(text: str) -> list[tuple[str, str, list[str]]]:
    """(id, claim, body_lines) for each `## F-NNNN - claim` section."""
    entries: list[tuple[str, str, list[str]]] = []
    current: tuple[str, str] | None = None
    body: list[str] = []
    for line in text.splitlines():
        m = HEADING_RE.match(line)
        if m:
            if current:
                entries.append((current[0], current[1], body))
            current = (m.group(1), m.group(2))
            body = []
        elif line.startswith("## ") and current:
            entries.append((current[0], current[1], body))
            current, body = None, []
        elif current is not None:
            body.append(line)
    if current:
        entries.append((current[0], current[1], body))
    return entries


def check(root: Path, args: argparse.Namespace) -> Report:
    ledger = next((root / name for name in LEDGER_NAMES if (root / name).is_file()), None)
    if ledger is None:
        return Report.inapplicable(
            "no FINDINGS.md — this repo has not started a ledger",
            ["create one from research-guardrails/templates/FINDINGS.md.template when it has a finding"],
        )

    text = read_text(ledger)
    # Prose about `{{slots}}` inside a code span is a mention, not an unfilled slot.
    if "{{" in strip_code_spans(text):
        return Report.failed(
            "FINDINGS.md still has unfilled template slots",
            ["fill them in, or wrap the literal in backticks if it is being written about"],
        )

    entries = split_entries(text)
    if not entries:
        return Report.failed(
            "FINDINGS.md exists but has no `## F-NNNN - claim` entries",
            ["a ledger with no entries in the ledger format is not an empty ledger, it is a different file"],
        )

    problems: list[str] = []
    seen: dict[str, int] = {}
    ids = [e[0] for e in entries]

    for index, (fid, claim, body) in enumerate(entries):
        where = f"{fid}"
        if fid in seen:
            problems.append(f"{where}: duplicate id (also entry #{seen[fid] + 1}); ids are never reused")
            continue
        seen[fid] = index

        if not claim or is_placeholder(claim):
            problems.append(f"{where}: heading has no claim after the id")

        fields = parse_field_block(body)
        for key in REQUIRED:
            if key not in fields:
                problems.append(f"{where}: missing required field `{key}`")
            elif is_placeholder(fields[key]):
                problems.append(f"{where}: field `{key}` is a placeholder ({fields[key]!r})")

        tier = fields.get("tier", "")
        if tier and tier not in TIERS and not is_placeholder(tier):
            problems.append(f"{where}: tier {tier!r} is not one of {sorted(TIERS)} (see QUALITY.md)")

        status = fields.get("status", "")
        if status and status not in STATUSES and not is_placeholder(status):
            problems.append(f"{where}: status {status!r} is not one of {sorted(STATUSES)}")

        date = fields.get("date", "")
        if date and not DATE_RE.match(date) and not is_placeholder(date):
            problems.append(f"{where}: date {date!r} is not YYYY-MM-DD")

        boundary = fields.get("boundary", "")
        if boundary and not is_placeholder(boundary) and len(boundary) < 20:
            problems.append(
                f"{where}: boundary {boundary!r} is too short to state a domain, an assumption "
                "and a failure mode (QUALITY.md requires all three)"
            )

        sup = fields.get("supersedes", "")
        if sup and sup.lower() != "none" and not is_placeholder(sup):
            for ref in ID_REF_RE.findall(sup):
                if ref not in ids:
                    problems.append(f"{where}: supersedes {ref}, which is not an entry in this ledger")
                elif ref == fid:
                    problems.append(f"{where}: supersedes itself")
            if not ID_REF_RE.findall(sup):
                problems.append(f"{where}: supersedes {sup!r} is neither `none` nor an F-NNNN id")

        # Invariant I5: a superseded entry keeps the four things.
        if status == "superseded":
            prose = "\n".join(body).lower()
            for phrase, label in [
                ("what was claimed", "what was claimed"),
                ("what is wrong", "what is wrong with it"),
                ("still stands", "what still stands"),
                ("why this is recorded", "why it is recorded"),
            ]:
                if phrase not in prose:
                    problems.append(
                        f"{where}: superseded entry does not say '{label}' (QUALITY.md, being wrong on the record)"
                    )

    # Every superseded entry should be superseded by something.
    superseded_by_someone = {
        ref
        for _, _, body in entries
        for ref in ID_REF_RE.findall(parse_field_block(body).get("supersedes", ""))
    }
    for fid, _, body in entries:
        if parse_field_block(body).get("status") == "superseded" and fid not in superseded_by_someone:
            problems.append(
                f"{fid}: marked superseded, but no entry claims to supersede it — "
                "either the replacement is missing its `supersedes` field, or the status is wrong"
            )

    if "what this does not establish" not in text.lower():
        problems.append(
            "ledger has no 'What this does not establish' section — the negative section is required, "
            "because what a reader wrongly concludes is not visible from the findings alone"
        )

    return Report.from_problems(
        problems,
        ok_summary=f"{len(entries)} entries, all fields present and resolvable",
        bad_summary="{n} problem(s) in FINDINGS.md",
    )


if __name__ == "__main__":
    run_gate(check, description=__doc__)
