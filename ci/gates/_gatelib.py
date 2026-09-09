#!/usr/bin/env python3
"""Shared spine for the guardrails gates.

Implements the four-outcome reporting contract from ARCHITECTURE.md, once, so that
no gate re-implements it and no gate can quietly collapse a refusal into a pass.

    passed         0   in scope, checked, conforms
    failed         1   in scope, checked, does not conform
    inapplicable   2   nothing in scope to check
    indeterminate  3   in scope, but a required input is missing

`inapplicable` and `indeterminate` are successful refusal behaviour (invariant I2).
`--strict` promotes `indeterminate` to a failure. Nothing promotes `inapplicable`:
"this repo has no findings ledger yet" is a fact about its stage, not a defect.

Every gate module must define, in its docstring, a section headed `Null signature:`
saying what a false pass would look like for that gate specifically.

Usage (from a gate module):

    from _gatelib import Report, run_gate

    def check(root, args):
        ...
        return Report.passed("42 entries, all fields present")

    if __name__ == "__main__":
        run_gate(check, description=__doc__)
"""

from __future__ import annotations

import argparse
import dataclasses
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Callable, Iterable, Sequence

PASSED = "passed"
FAILED = "failed"
INAPPLICABLE = "inapplicable"
INDETERMINATE = "indeterminate"

EXIT_CODES = {PASSED: 0, FAILED: 1, INAPPLICABLE: 2, INDETERMINATE: 3}


@dataclasses.dataclass
class Report:
    """The result of one gate run. Outcome is one of the four; nothing else."""

    outcome: str
    summary: str
    details: list[str] = dataclasses.field(default_factory=list)
    gate: str = ""

    @classmethod
    def passed(cls, summary: str, details: Iterable[str] = ()) -> "Report":
        return cls(PASSED, summary, list(details))

    @classmethod
    def failed(cls, summary: str, details: Iterable[str] = ()) -> "Report":
        return cls(FAILED, summary, list(details))

    @classmethod
    def inapplicable(cls, summary: str, details: Iterable[str] = ()) -> "Report":
        return cls(INAPPLICABLE, summary, list(details))

    @classmethod
    def indeterminate(cls, summary: str, details: Iterable[str] = ()) -> "Report":
        return cls(INDETERMINATE, summary, list(details))

    @classmethod
    def from_problems(
        cls, problems: Sequence[str], ok_summary: str, bad_summary: str
    ) -> "Report":
        """Passed if `problems` is empty, failed otherwise. The common shape."""
        if problems:
            return cls.failed(bad_summary.format(n=len(problems)), problems)
        return cls.passed(ok_summary)

    def exit_code(self, strict: bool = False) -> int:
        if strict and self.outcome == INDETERMINATE:
            return EXIT_CODES[FAILED]
        return EXIT_CODES[self.outcome]

    def as_dict(self) -> dict:
        return {
            "gate": self.gate,
            "outcome": self.outcome,
            "summary": self.summary,
            "details": self.details,
        }

    def render(self) -> str:
        mark = {PASSED: "ok", FAILED: "FAIL", INAPPLICABLE: "n/a", INDETERMINATE: "??"}
        head = f"[{mark[self.outcome]:>4}] {self.gate}: {self.summary}"
        if not self.details:
            return head
        return head + "\n" + "\n".join(f"       - {d}" for d in self.details)


def run_gate(check: Callable[[Path, argparse.Namespace], Report], description: str = "") -> None:
    """Argument parsing, dispatch, rendering and exit code. Gates call this and nothing else."""
    gate_name = Path(sys.argv[0]).stem
    parser = argparse.ArgumentParser(
        prog=gate_name,
        description=(description or "").strip().splitlines()[0] if description else None,
    )
    parser.add_argument("root", nargs="?", default=".", help="repo root to check (default: .)")
    parser.add_argument("--check", action="store_true", help="check against the recorded baseline")
    parser.add_argument("--write", action="store_true", help="record the current state as the baseline")
    parser.add_argument("--json", action="store_true", help="emit the report as JSON")
    parser.add_argument("--strict", action="store_true", help="treat indeterminate as a failure")
    parser.add_argument("--base-ref", default=None, help="git ref to diff against, where relevant")
    args = parser.parse_args()

    # Windows consoles default to cp1252 and would mangle the em-dashes in gate messages.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
        except (AttributeError, OSError):
            pass

    root = Path(args.root).resolve()
    if not root.is_dir():
        report = Report.indeterminate(f"not a directory: {root}")
    else:
        report = check(root, args)
    report.gate = gate_name

    if args.json:
        print(json.dumps(report.as_dict(), indent=2))
    else:
        print(report.render())
    sys.exit(report.exit_code(strict=args.strict))


# --- helpers shared by more than one gate -------------------------------------

SKIP_DIRS = {
    ".git", ".venv", "venv", "node_modules", "__pycache__", ".pytest_cache",
    "site-packages", "_freeze", ".julia", "build", "dist", ".quarto",
    # Test fixtures are deliberately malformed content. A gate that read them would report
    # its own test data as defects in the repo.
    "fixtures",
}

IGNORE_FILE = ".guardrails-ignore"


def ignore_prefixes(root: Path) -> list[str]:
    """Repo-relative path prefixes this repo has asked the gates to skip.

    An escape hatch is also a way to make a gate pass by hiding things, so every gate that
    honours this reports how many files it skipped. Silence about an exclusion would be the
    exact failure mode invariant I2 exists to prevent."""
    decl = root / IGNORE_FILE
    if not decl.is_file():
        return []
    return [
        line.strip().replace("\\", "/").rstrip("/")
        for line in decl.read_text(encoding="utf-8", errors="replace").splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]


def walk_files(root: Path, suffixes: Iterable[str]) -> tuple[list[Path], int]:
    """(files, n_ignored) for files under `root` with one of `suffixes`.

    Skips vendored and build trees silently — nobody means those — and skips whatever
    `.guardrails-ignore` names, counted so the caller can say so out loud."""
    wanted = {s.lower() for s in suffixes}
    prefixes = ignore_prefixes(root)
    found: list[Path] = []
    ignored = 0
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in wanted:
            continue
        relative = path.relative_to(root)
        # Only parts *below* the root are skipped. Checking the absolute path would make a
        # gate pointed straight at a fixtures or build directory scan nothing and say so.
        if any(part in SKIP_DIRS for part in relative.parts):
            continue
        rel = relative.as_posix()
        if any(rel == p or rel.startswith(p + "/") for p in prefixes):
            ignored += 1
            continue
        found.append(path)
    return found, ignored


def hash_text(text: str) -> str:
    """Hash of text with line endings normalised, so CRLF/LF churn is not drift."""
    normalised = text.replace("\r\n", "\n").replace("\r", "\n")
    return hashlib.sha256(normalised.encode("utf-8")).hexdigest()


def hash_file(path: Path) -> str:
    return hash_text(path.read_text(encoding="utf-8", errors="replace"))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


FIELD_RE = re.compile(r"^\s*[-*]\s*([a-z_][a-z0-9_]*)\s*:\s*(.*?)\s*$")


def parse_field_block(lines: Iterable[str]) -> dict[str, str]:
    """Parse `- key: value` bullets into a dict. The record format used everywhere here."""
    fields: dict[str, str] = {}
    for line in lines:
        m = FIELD_RE.match(line)
        if m:
            fields[m.group(1)] = m.group(2).strip()
    return fields


PLACEHOLDERS = {
    "", "tbd", "todo", "xxx", "n/a", "...", "fixme", "<sha>", "<name>",
    "<short slug>", "<fill in>", "none yet",
}


def is_placeholder(value: str) -> bool:
    return value.strip().strip("`").lower() in PLACEHOLDERS


INLINE_CODE_RE = re.compile(r"`[^`\n]*`")


def strip_code_spans(text: str) -> str:
    """Remove inline-code spans, so that prose *about* a convention is not read as a use of it.

    A document is allowed to write about `{{slots}}` or about a marker without being accused of
    containing one. This is the same distinction check_confirm_markers.py draws between a
    mention and a use, and it is applied wherever a gate greps prose for a literal."""
    return INLINE_CODE_RE.sub("", text)


def git(root: Path, *args: str) -> tuple[int, str]:
    """Run git in `root`. Returns (returncode, stdout). Never raises."""
    try:
        proc = subprocess.run(
            ["git", "-C", str(root), *args],
            capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.SubprocessError) as exc:  # git absent, or hung
        return 1, str(exc)
    return proc.returncode, proc.stdout.strip()


def is_git_repo(root: Path) -> bool:
    code, out = git(root, "rev-parse", "--is-inside-work-tree")
    return code == 0 and out == "true"


def resolve_base_ref(root: Path, requested: str | None) -> str | None:
    """The ref to diff against, or None if there is not one — which means indeterminate,
    never a pass. A gate that cannot see the diff must not report that nothing changed."""
    candidates = [requested] if requested else ["origin/main", "origin/master", "main", "master"]
    for ref in candidates:
        if ref and git(root, "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}")[0] == 0:
            return ref
    return None


def changed_files(root: Path, base_ref: str) -> list[str]:
    """Repo-relative paths changed since `base_ref`, including uncommitted and untracked work.

    Untracked files are included deliberately: a promotion record being added alongside the
    content it accompanies is a new file, and a gate that only looked at tracked changes would
    tell an author their record was missing while they were looking straight at it."""
    collected: list[str] = []
    for args in (
        ("diff", "--name-only", base_ref),
        ("diff", "--name-only"),
        ("diff", "--name-only", "--cached"),
        ("ls-files", "--others", "--exclude-standard"),
    ):
        code, out = git(root, *args)
        if code == 0:
            collected += out.splitlines()
    return sorted({p for p in collected if p})
