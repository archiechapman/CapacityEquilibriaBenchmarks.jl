#!/usr/bin/env python3
"""Fail if this repo's synced guardrails block has been edited in place.

ARCHITECTURE.md contract 2, and the enforcement of invariant I1. Runs **entirely offline**. It
never asks what research-guardrails' current main says, because a sibling repo that needed the
guardrails repo present in order to pass its own CI would be exactly the live dependency I1
forbids.

What it detects is *local* drift: the `<!-- guardrails:begin -->` block in AGENTS.md edited
here rather than upstream, which is how a repo silently forks the portfolio's conventions
while still looking synced. Being several versions behind is not drift and is not reported as
a problem — it is reported as a fact, in the summary line.

Picking up a newer guardrails is always deliberate: fetch one, run `sync/install.py`, review
the diff, commit.

Run: in CI, and after any edit to AGENTS.md.

Usage:
    python check_guardrails_sync.py [ROOT] --check [--strict] [--json]
    python check_guardrails_sync.py [ROOT] --write     # re-pin to the block as it now stands

Null signature:
    A repo with no AGENTS.md returns `inapplicable`. An AGENTS.md whose guardrails block is
    present but which has no .guardrails-pin returns `indeterminate`, not `passed` — with no
    recorded baseline the gate has nothing to compare against, and calling that clean is the
    silent no-op the write/check contract exists to prevent.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "ci" / "gates"))

from _gatelib import Report, hash_text, parse_field_block, read_text, run_gate  # noqa: E402

AGENTS = "AGENTS.md"
PIN = ".guardrails-pin"
BEGIN = "<!-- guardrails:begin -->"
END = "<!-- guardrails:end -->"

BLOCK_RE = re.compile(
    re.escape(BEGIN) + r"(.*?)" + re.escape(END), re.DOTALL
)


def extract_block(text: str) -> tuple[str | None, str | None]:
    """(block_text, error). Exactly one delimited block must be present."""
    starts, ends = text.count(BEGIN), text.count(END)
    if starts == 0 and ends == 0:
        return None, None
    if starts != 1 or ends != 1:
        return None, f"expected exactly one guardrails block, found {starts} begin / {ends} end markers"
    m = BLOCK_RE.search(text)
    if not m:
        return None, "guardrails end marker appears before its begin marker"
    return m.group(1), None


def check(root: Path, args: argparse.Namespace) -> Report:
    agents = root / AGENTS
    pin_file = root / PIN

    if not agents.is_file():
        legacy = root / "CLAUDE.md"
        detail = (
            ["a CLAUDE.md is present; the portfolio uses AGENTS.md (ARCHITECTURE.md, Naming) — "
             "rename it and fill in the per-repo sections from templates/AGENTS.md.template"]
            if legacy.is_file() else
            ["install one with research-guardrails/sync/install.py"]
        )
        return Report.inapplicable(f"no {AGENTS} — this repo has not adopted the guardrails", detail)

    block, err = extract_block(read_text(agents))
    if err:
        return Report.failed(f"{AGENTS}: {err}")
    if block is None:
        return Report.inapplicable(
            f"{AGENTS} exists but carries no guardrails block",
            ["a repo may keep a purely local AGENTS.md; run sync/install.py to adopt the shared block"],
        )

    current_hash = hash_text(block)

    if args.write:
        version = "unknown"
        guardrails_version = Path(__file__).resolve().parent.parent / "VERSION"
        if guardrails_version.is_file():
            version = read_text(guardrails_version).strip()
        pin_file.write_text(
            "\n".join([
                "# Written by research-guardrails/sync/check_guardrails_sync.py --write.",
                "# Records which guardrails version the AGENTS.md block was copied from, and its hash.",
                "# Being behind is fine and is not drift; editing the block in place is drift.",
                f"- guardrails_version: {version}",
                f"- block_sha256: {current_hash}",
                "",
            ]),
            encoding="utf-8",
        )
        return Report.passed(f"pinned to guardrails {version}, block hash {current_hash[:12]}")

    if not pin_file.is_file():
        return Report.indeterminate(
            f"{AGENTS} has a guardrails block but there is no {PIN} to check it against",
            [f"run: python sync/check_guardrails_sync.py {root} --write"],
        )

    pin = parse_field_block(read_text(pin_file).splitlines())
    recorded = pin.get("block_sha256", "")
    version = pin.get("guardrails_version", "unknown")

    if not recorded:
        return Report.indeterminate(f"{PIN} records no block_sha256", [f"run --write to re-pin"])

    if recorded != current_hash:
        return Report.failed(
            f"the guardrails block in {AGENTS} has been edited in place (pinned to {version})",
            [
                f"recorded {recorded[:12]}, found {current_hash[:12]}",
                "this block is shared portfolio-wide; editing it here forks the conventions silently",
                "to change it: change templates/AGENTS.md.template in research-guardrails, then re-run "
                "sync/install.py here",
                "if the change is intended and already upstream, re-pin with --write",
            ],
        )

    return Report.passed(f"guardrails block matches its pin (guardrails {version})")


if __name__ == "__main__":
    run_gate(check, description=__doc__)
