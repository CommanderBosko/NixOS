#!/usr/bin/env bash
# ci-status.sh — Resolve, watch, and report on a GitHub Actions "flake check" run.
#
# Usage: ci-status.sh [branch|commit-sha|run-id|title-substring]
# With no argument, uses the newest run. Read-only: gh run list/watch/view
# never mutate anything — safe to run anytime.
#
# Prints the resolved run id/branch/commit SHA/status, watches it to completion
# if still in_progress/queued, and on failure prints the last 40 lines of the
# failed step's log.
#
# Exit codes:
#   0  the run succeeded
#   1  the run failed, was cancelled, or no run matched (a real CI answer)
#   2  `gh` itself failed (auth, network, rate limit, unknown workflow) — says
#      nothing about CI; do NOT report it as "the workflow never fired"
set -uo pipefail

REPO="CommanderBosko/NixOS"
WORKFLOW="flake check"
FILTER="${1:-}"

GH_ERR="$(mktemp)"
trap 'rm -f "$GH_ERR"' EXIT

# gh_failed <what> <exit-code> — report a gh failure (with gh's own stderr) and exit 2.
gh_failed() {
  echo "ERROR: $1 failed (gh exit $2) — a gh/auth/network problem, NOT evidence about CI." >&2
  echo "       Do not read this as 'the workflow never ran'. gh said:" >&2
  sed 's/^/       /' "$GH_ERR" >&2
  exit 2
}

RUN_LIST_JSON=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit 10 \
  --json databaseId,status,conclusion,headBranch,headSha,displayTitle 2>"$GH_ERR")
GH_STATUS=$?
[ "$GH_STATUS" -ne 0 ] && gh_failed "'gh run list'" "$GH_STATUS"

if [ -z "$RUN_LIST_JSON" ] || [ "$RUN_LIST_JSON" = "[]" ]; then
  echo "No runs found for workflow '$WORKFLOW' in $REPO (gh succeeded; the workflow has no runs)."
  exit 1
fi

if [ -n "$FILTER" ]; then
  RUN_ID=$(echo "$RUN_LIST_JSON" | jq -r --arg f "$FILTER" '
    map(select(
      .headBranch == $f
      or (.headSha | startswith($f))
      or ((.databaseId | tostring) == $f)
      or (.displayTitle | contains($f))
    )) | .[0].databaseId // empty')
  if [ -z "$RUN_ID" ]; then
    echo "No run matched filter '$FILTER'. Recent runs:"
    echo "$RUN_LIST_JSON" | jq -r '.[] | "\(.databaseId)\t\(.status)/\(.conclusion)\t\(.headBranch)\t\(.headSha[0:7])\t\(.displayTitle)"'
    exit 1
  fi
else
  RUN_ID=$(echo "$RUN_LIST_JSON" | jq -r '.[0].databaseId')
fi

RUN_META=$(echo "$RUN_LIST_JSON" | jq -r --arg id "$RUN_ID" '.[] | select((.databaseId|tostring)==$id)')
STATUS=$(echo "$RUN_META" | jq -r '.status')
BRANCH=$(echo "$RUN_META" | jq -r '.headBranch')
TITLE=$(echo "$RUN_META" | jq -r '.displayTitle')
SHA=$(echo "$RUN_META" | jq -r '.headSha')

echo "==> Run $RUN_ID — $BRANCH @ ${SHA:0:7} — $TITLE (status: $STATUS)"
echo "Commit: $SHA"

if [ "$STATUS" = "in_progress" ] || [ "$STATUS" = "queued" ]; then
  gh run watch "$RUN_ID" --repo "$REPO" --exit-status --interval 20
  EXIT_CODE=$?
else
  CONCLUSION=$(gh run view "$RUN_ID" --repo "$REPO" --json conclusion --jq '.conclusion' 2>"$GH_ERR")
  GH_STATUS=$?
  [ "$GH_STATUS" -ne 0 ] && gh_failed "'gh run view'" "$GH_STATUS"
  echo "Conclusion: $CONCLUSION"
  [ "$CONCLUSION" = "success" ]
  EXIT_CODE=$?
fi

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "--- failure log tail ---"
  gh run view "$RUN_ID" --repo "$REPO" --log-failed | tail -40
fi

exit "$EXIT_CODE"
