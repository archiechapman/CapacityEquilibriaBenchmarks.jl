#!/usr/bin/env bash
# Publish the emitted upstream test file so a CCOpt.jl maintainer can take it, and print
# the exact command that posts the note.
#
#     bash scripts/share_upstream.sh              # dry run: says what it would do
#     bash scripts/share_upstream.sh --publish    # creates or updates the public gist
#
# Why a gist. This repository is private (DECISIONS.md D-0002 leaves opening it to its
# owner), so a link into it is no use to someone outside. A public gist shares exactly one
# file, needs no decision about the rest of the repository, and gives a `curl`-able raw URL
# that can go straight into the note. If the repository is public by the time you read
# this, link the file in it instead and skip the gist.
#
# Nothing here posts to CCOpt.jl. The last step prints a `gh issue create` command for you
# to run, or not.
#
# Requires: gh, authenticated with the `gist` scope (`gh auth status`).

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$REPO/upstream/test_murphy_smeers_lcp.jl"
NOTE="$REPO/upstream/ISSUE.md"
STATE="$REPO/upstream/.gist-id"
DESC="Murphy-Smeers open-loop capacity equilibria: four small LCPs with independently known solutions, offered to CCOpt.jl"

# The second artifact: the demonstration that the closed-loop first-order conditions have
# roots that are not equilibria, and that those roots are exactly the degenerate ones.
DEMO="$REPO/upstream/closed_loop_demonstration.jl"
DEMO_NOTE="$REPO/upstream/NOTE_first_order_conditions.md"
DEMO_STATE="$REPO/upstream/.gist-id-demo"
DEMO_DESC="Three solutions, one equilibrium: a capacity game where the first-order conditions do not characterise the answer"

# The third artifact: a hard MPCC with two nearly-tied optima far apart.
HARD="$REPO/upstream/hard_case_near_tie.jl"
HARD_STATE="$REPO/upstream/.gist-id-hard"
HARD_DESC="A hard MPCC: two optima a fifth of the domain apart, tied to fourteen significant figures"

PUBLISH=0
[[ "${1:-}" == "--publish" ]] && PUBLISH=1

die() { echo "error: $*" >&2; exit 1; }

[[ -f "$FILE" ]] || die "no emitted file; run: julia --project scripts/emit_upstream_test.jl"
[[ -f "$NOTE" ]] || die "no note at upstream/ISSUE.md"
[[ -f "$DEMO" ]] || die "no demonstration; run: julia --project scripts/emit_closed_loop_demo.jl"
[[ -f "$DEMO_NOTE" ]] || die "no note at upstream/NOTE_first_order_conditions.md"
[[ -f "$HARD" ]] || die "no hard case; run: julia --project scripts/emit_hard_case.jl"
command -v gh >/dev/null || die "gh is not installed"

# Refuse to share a stale artifact. The gate compares the emitted file and its sources
# against the recorded baseline; sharing a copy that no longer matches the model that
# validated it is the exact failure D-0001 exists to prevent.
echo "checking the artifact is not stale..."
if ! python "$REPO/ci/gates/check_stale_generated.py" "$REPO" --check; then
    die "the emitted file is stale against its sources; regenerate and re-record before sharing"
fi

# And refuse to share a copy that does not pass where it is going.
echo
echo "The portability check (scripts/check_upstream_portable.jl) should have been run"
echo "against the current file. It is not run here because it resolves a fresh project"
echo "and takes a minute; run it yourself if the file has changed since you last did."
echo

if [[ $PUBLISH -eq 0 ]]; then
    echo "DRY RUN. With --publish this would:"
    if [[ -f "$STATE" ]]; then
        echo "  update the existing gist $(cat "$STATE") (the open-loop test case)"
    else
        echo "  create a public gist from upstream/test_murphy_smeers_lcp.jl"
    fi
    if [[ -f "$DEMO_STATE" ]]; then
        echo "  update the existing gist $(cat "$DEMO_STATE") (the closed-loop demonstration)"
    else
        echo "  create a public gist from upstream/closed_loop_demonstration.jl"
    fi
    if [[ -f "$HARD_STATE" ]]; then
        echo "  update the existing gist $(cat "$HARD_STATE") (the hard case)"
    else
        echo "  create a public gist from upstream/hard_case_near_tie.jl"
    fi
    echo "  write their ids to upstream/.gist-id, .gist-id-demo and .gist-id-hard"
    echo "  print both raw URLs and the gh commands that post the two notes"
    exit 0
fi

# publish_gist <file> <state-file> <description> -> sets GIST_URL and RAW_URL
publish_gist() {
    local file="$1" state="$2" desc="$3" id url
    if [[ -f "$state" ]]; then
        id="$(cat "$state")"
        echo "updating gist $id"
        gh gist edit "$id" --filename "$(basename "$file")" "$file"
        url="https://gist.github.com/$id"
    else
        echo "creating a public gist for $(basename "$file")"
        url="$(gh gist create --public --desc "$desc" "$file")"
        id="${url##*/}"
        printf '%s\n' "$id" > "$state"
    fi
    GIST_URL="$url"
    RAW_URL="$(gh api "gists/$id" --jq ".files[\"$(basename "$file")\"].raw_url")"
}

publish_gist "$FILE" "$STATE" "$DESC"
TEST_GIST="$GIST_URL"; TEST_RAW="$RAW_URL"
publish_gist "$DEMO" "$DEMO_STATE" "$DEMO_DESC"
DEMO_GIST="$GIST_URL"; DEMO_RAW="$RAW_URL"
publish_gist "$HARD" "$HARD_STATE" "$HARD_DESC"
HARD_GIST="$GIST_URL"; HARD_RAW="$RAW_URL"

echo
echo "open-loop test case   gist: $TEST_GIST"
echo "                      raw:  $TEST_RAW"
echo "closed-loop demo      gist: $DEMO_GIST"
echo "                      raw:  $DEMO_RAW"
echo "hard case             gist: $HARD_GIST"
echo "                      raw:  $HARD_RAW"

# Fill the placeholders in a copy of the note, ready to post. The note itself keeps its
# placeholders so that it stays valid when the gist is recreated.
OUT="$(mktemp -t ccopt-issue-XXXX.md)"
sed -e "s|GIST_RAW_URL|$TEST_RAW|g" -e "s|GIST_URL|$TEST_GIST|g" "$NOTE" \
    | sed -n '/^\*\*Body\*\*$/,$p' | tail -n +2 > "$OUT"

DEMO_OUT="$(mktemp -t ccopt-note-XXXX.md)"
sed -e "s|HARD_RAW_URL|$HARD_RAW|g" -e "s|HARD_URL|$HARD_GIST|g" \
    -e "s|GIST_RAW_URL|$DEMO_RAW|g" -e "s|GIST_URL|$DEMO_GIST|g" "$DEMO_NOTE" > "$DEMO_OUT"

echo
echo "The two notes, with the URLs filled in:"
echo "  $OUT       (the offer of the open-loop test case)"
echo "  $DEMO_OUT  (the first-order-conditions note)"
echo
echo "To post them. These are the only outward-facing steps, and they are yours to run:"
echo
echo "  gh issue create --repo madsuite-org/CCOpt.jl \\"
echo "    --title 'Offer: four small LCPs with independently known solutions, as a regression test' \\"
echo "    --body-file '$OUT'"
echo
echo "  gh issue create --repo madsuite-org/CCOpt.jl \\"
echo "    --title 'A hard MPCC: two optima tied to 14 figures, and CCOpt finds the better one about half the time' \\"
echo "    --body-file '$DEMO_OUT'"
echo
echo "Read both first. They mention @frapac by handle. Consider posting the offer first and"
echo "the note second, or the note alone: it stands on its own and asks for less."
