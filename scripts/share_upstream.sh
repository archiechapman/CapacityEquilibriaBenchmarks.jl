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

PUBLISH=0
[[ "${1:-}" == "--publish" ]] && PUBLISH=1

die() { echo "error: $*" >&2; exit 1; }

[[ -f "$FILE" ]] || die "no emitted file; run: julia --project scripts/emit_upstream_test.jl"
[[ -f "$NOTE" ]] || die "no note at upstream/ISSUE.md"
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
        echo "  update the existing gist $(cat "$STATE")"
    else
        echo "  create a new public gist from upstream/test_murphy_smeers_lcp.jl"
    fi
    echo "  write its id to upstream/.gist-id"
    echo "  print the raw URL and the gh command that posts upstream/ISSUE.md"
    exit 0
fi

if [[ -f "$STATE" ]]; then
    GIST_ID="$(cat "$STATE")"
    echo "updating gist $GIST_ID"
    gh gist edit "$GIST_ID" --filename "test_murphy_smeers_lcp.jl" "$FILE"
    GIST_URL="https://gist.github.com/$GIST_ID"
else
    echo "creating a public gist"
    GIST_URL="$(gh gist create --public --desc "$DESC" "$FILE")"
    GIST_ID="${GIST_URL##*/}"
    printf '%s\n' "$GIST_ID" > "$STATE"
    echo "gist id recorded in upstream/.gist-id"
fi

RAW_URL="$(gh api "gists/$GIST_ID" --jq '.files["test_murphy_smeers_lcp.jl"].raw_url')"

echo
echo "gist:  $GIST_URL"
echo "raw:   $RAW_URL"

# Fill the placeholders in a copy of the note, ready to post. The note itself keeps its
# placeholders so that it stays valid when the gist is recreated.
OUT="$(mktemp -t ccopt-issue-XXXX.md)"
sed -e "s|GIST_RAW_URL|$RAW_URL|g" -e "s|GIST_URL|$GIST_URL|g" "$NOTE" \
    | sed -n '/^\*\*Body\*\*$/,$p' | tail -n +2 > "$OUT"

echo
echo "The note, with the URLs filled in, is at:"
echo "  $OUT"
echo
echo "To post it (this is the only outward-facing step, and it is yours to run):"
echo
echo "  gh issue create --repo madsuite-org/CCOpt.jl \\"
echo "    --title 'Offer: four small LCPs with independently known solutions, as a regression test' \\"
echo "    --body-file '$OUT'"
echo
echo "Read $OUT first. It mentions @frapac by handle."
