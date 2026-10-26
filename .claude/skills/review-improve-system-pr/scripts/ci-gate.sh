#!/usr/bin/env bash
# ci-gate.sh — Gate a merge on CI: wait for the PR's checks, and require that the PR head is
# still exactly the commit that was guardrail-checked and reviewed.
#
# Usage: ci-gate.sh <pr-number> <head-sha>
#   <head-sha> is the PR_HEAD_SHA printed by find-and-check-pr.sh (never re-read it from
#   GitHub — that would pin to whatever is there now).
# Run it as its own Bash call with timeout 600000: it waits internally for up to
# CI_GATE_TIMEOUT seconds (default 570) so it ends before the Bash tool's limit.
# Read-only: only `gh pr view` / `gh pr checks`, never mutates anything.
#
# Exit codes (only 0 permits the merge):
#   0 — every check passed (skipped counts as passed) AND the head still equals <head-sha>
#   1 — checks failed, none were reported, or gh checks errored
#   2 — usage error
#   3 — could not evaluate (gh failure reading the head, or the watch could not run)
#   4 — the PR head moved away from <head-sha> (before or after the wait): re-run the review
#   8 — checks still pending when the wait ended
set -uo pipefail

REPO="CommanderBosko/NixOS"

die3() {
  echo "ERROR: $1"
  echo "CI_GATE: NOT EVALUATED"
  exit 3
}

[ $# -eq 2 ] || { echo "usage: ci-gate.sh <pr-number> <head-sha>" >&2; exit 2; }
PR=$1
SHA=$2
[[ "$PR" =~ ^[0-9]+$ ]] || { echo "usage: <pr-number> must be digits, got '$PR'" >&2; exit 2; }
[[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || { echo "usage: <head-sha> must be a full 40-hex commit, got '$SHA'" >&2; exit 2; }

head_now() {
  local oid
  oid=$(gh pr view "$PR" --repo "$REPO" --json headRefOid --jq '.headRefOid') || return 1
  [[ "$oid" =~ ^[0-9a-f]{40}$ ]] || return 1
  printf '%s' "$oid"
}

now=$(head_now) || die3 "could not read PR #$PR head commit (auth/network?)"
if [ "$now" != "$SHA" ]; then
  echo "CI_GATE: HEAD MOVED - PR #$PR head is $now, reviewed commit was $SHA"
  exit 4
fi

timeout "${CI_GATE_TIMEOUT:-570}" gh pr checks "$PR" --repo "$REPO" --watch --fail-fast
rc=$?
case $rc in
  0) ;;
  1)
    echo "CI_GATE: FAILED - a check failed, no checks were reported, or gh errored (PR #$PR)"
    exit 1
    ;;
  8 | 124)
    echo "CI_GATE: PENDING - checks had not finished when the wait ended (PR #$PR)"
    exit 8
    ;;
  *) die3 "gh pr checks exited $rc (not run, or unexpected failure)" ;;
esac

now=$(head_now) || die3 "could not re-read PR #$PR head commit after the checks finished"
if [ "$now" != "$SHA" ]; then
  echo "CI_GATE: HEAD MOVED - PR #$PR head is now $now after CI; reviewed commit was $SHA"
  exit 4
fi

echo "CI_GATE: PASS - PR #$PR checks green at $SHA"
exit 0
