#!/usr/bin/env python3
"""Check that DECISIONS.md entries state a question, options, evidence and a revisit condition.

Refuses silence, not judgement (ARCHITECTURE.md I4). It does not care whether a decision was
right. It cares that `revisit_if` is not blank, because a decision with no reopening condition
is either permanent — in which case say so — or one nobody has thought about since.

`evidence: judgement, no measurement` is an accepted value and deliberately so: it records
that the call was a judgement, which is what a future reader most needs before overturning it.

Run: any time, standalone.

Usage:
    python check_decision_log.py [ROOT] --check [--strict] [--json]

Null signature:
    No DECISIONS.md returns `inapplicable`. The false pass to watch for is a `revisit_if` that
    is present but vacuous ("when it becomes a problem"), which no script can catch — so the
    gate reports the count of entries whose revisit_if is a bare `none` without a stated reason,
    and fails those, leaving the vacuous-but-worded ones to human review in CONTRIBUTING.md.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from _gatelib import (
    Report, is_placeholder, parse_field_block, read_text, run_gate, strip_code_spans,
)

REQUIRED = ["date", "status", "question", "options", "decision", "evidence", "cost_of_change", "revisit_if"]
STATUSES = {"active", "superseded", "withdrawn"}

HEADING_RE = re.compile(r"^##\s+(D-\d{4})\s*[-—]{1,2}\s*(.+?)\s*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
ID_REF_RE = re.compile(r"D-\d{4}")
# `none - permanent because <reason>` is the only accepted form of "no revisit condition".
PERMANENT_RE = re.compile(r"^none\s*[-—:]{1,2}\s*permanent because\s+\S+", re.IGNORECASE)


def split_entries(text: str) -> list[tuple[str, str, list[str]]]:
    entries: list[tuple[str, str, list[str]]] = []
    current: tuple[str, str] | None = None
    body: list[str] = []
    for line in text.splitlines():
        m = HEADING_RE.match(line)
        if m:
            if current:
                entries.append((current[0], current[1], body))
            current, body = (m.group(1), m.group(2)), []
        elif line.startswith("## ") and current:
            entries.append((current[0], current[1], body))
            current, body = None, []
        elif current is not None:
            body.append(line)
    if current:
        entries.append((current[0], current[1], body))
    return entries


def check(root: Path, args: argparse.Namespace) -> Report:
    log = root / "DECISIONS.md"
    if not log.is_file():
        return Report.inapplicable(
            "no DECISIONS.md — this repo has not recorded a decision",
            ["create one from research-guardrails/templates/DECISIONS.md.template"],
        )

    text = read_text(log)
    # Prose about `{{slots}}` inside a code span is a mention, not an unfilled slot.
    if "{{" in strip_code_spans(text):
        return Report.failed(
            "DECISIONS.md still has unfilled template slots",
            ["fill them in, or wrap the literal in backticks if it is being written about"],
        )

    entries = split_entries(text)
    if not entries:
        return Report.failed("DECISIONS.md exists but has no `## D-NNNN - title` entries")

    problems: list[str] = []
    seen: set[str] = set()
    ids = [e[0] for e in entries]

    for did, title, body in entries:
        if did in seen:
            problems.append(f"{did}: duplicate id; ids are never reused")
            continue
        seen.add(did)

        if not title or is_placeholder(title):
            problems.append(f"{did}: heading has no title after the id")

        fields = parse_field_block(body)
        for key in REQUIRED:
            if key not in fields:
                problems.append(f"{did}: missing required field `{key}`")
            elif is_placeholder(fields[key]):
                problems.append(f"{did}: field `{key}` is a placeholder ({fields[key]!r})")

        status = fields.get("status", "")
        if status and status not in STATUSES and not is_placeholder(status):
            problems.append(f"{did}: status {status!r} is not one of {sorted(STATUSES)}")

        date = fields.get("date", "")
        if date and not DATE_RE.match(date) and not is_placeholder(date):
            problems.append(f"{did}: date {date!r} is not YYYY-MM-DD")

        revisit = fields.get("revisit_if", "")
        if revisit and not is_placeholder(revisit):
            if revisit.strip().lower() in {"none", "n/a", "never"}:
                problems.append(
                    f"{did}: revisit_if is a bare {revisit!r} — write "
                    "'none — permanent because <reason>' so the claim of permanence is itself on the record"
                )
            elif revisit.strip().lower().startswith("none") and not PERMANENT_RE.match(revisit.strip()):
                problems.append(
                    f"{did}: revisit_if starts with 'none' but does not give a reason "
                    "('none — permanent because <reason>')"
                )

        options = fields.get("options", "")
        if options and not is_placeholder(options) and ";" not in options and "," not in options:
            problems.append(
                f"{did}: options names only one alternative — a decision with one option is not a decision"
            )

        if status == "superseded":
            by = fields.get("superseded_by", "")
            if not by or is_placeholder(by):
                problems.append(f"{did}: marked superseded but has no `superseded_by` field")
            else:
                for ref in ID_REF_RE.findall(by):
                    if ref not in ids:
                        problems.append(f"{did}: superseded_by {ref}, which is not an entry in this log")

    return Report.from_problems(
        problems,
        ok_summary=f"{len(entries)} decisions, all fields present and every revisit condition stated",
        bad_summary="{n} problem(s) in DECISIONS.md",
    )


if __name__ == "__main__":
    run_gate(check, description=__doc__)
