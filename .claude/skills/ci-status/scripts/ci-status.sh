#!/usr/bin/env bash
# ci-status.sh — Resolve, watch, and report on a GitHub Actions "flake check" run.
#
# Usage: ci-status.sh [branch|commit-sha|run-id|title-substring]
# With no argument, uses the newest run. Read-only: gh run list/watch/view
# never mutate anything — safe to run anytime.
#
# Prints the resolved run id/status, watches it to completion if still
# in_progress/queued, and on failure prints the last 40 lines of the failed
# step's log. Exits 0 on success, 1 on failure/no-match, mirroring the run.
set -uo pipefail

REPO="CommanderBosko/NixOS"
WORKFLOW="flake check"
FILTER="${1:-}"

RUN_LIST_JSON=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit 10 \
  --json databaseId,status,conclusion,headBranch,headSha,displayTitle)

if [ -z "$RUN_LIST_JSON" ] || [ "$RUN_LIST_JSON" = "[]" ]; then
  echo "No runs found for workflow '$WORKFLOW' in $REPO."
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
    echo "$RUN_LIST_JSON" | jq -r '.[] | "\(.databaseId)\t\(.status)/\(.conclusion)\t\(.headBranch)\t\(.displayTitle)"'
    exit 1
  fi
else
  RUN_ID=$(echo "$RUN_LIST_JSON" | jq -r '.[0].databaseId')
fi

RUN_META=$(echo "$RUN_LIST_JSON" | jq -r --arg id "$RUN_ID" '.[] | select((.databaseId|tostring)==$id)')
STATUS=$(echo "$RUN_META" | jq -r '.status')
BRANCH=$(echo "$RUN_META" | jq -r '.headBranch')
TITLE=$(echo "$RUN_META" | jq -r '.displayTitle')

echo "==> Run $RUN_ID — $BRANCH — $TITLE (status: $STATUS)"

if [ "$STATUS" = "in_progress" ] || [ "$STATUS" = "queued" ]; then
  gh run watch "$RUN_ID" --repo "$REPO" --exit-status --interval 20
  EXIT_CODE=$?
else
  CONCLUSION=$(gh run view "$RUN_ID" --repo "$REPO" --json conclusion --jq '.conclusion')
  echo "Conclusion: $CONCLUSION"
  [ "$CONCLUSION" = "success" ]
  EXIT_CODE=$?
fi

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "--- failure log tail ---"
  gh run view "$RUN_ID" --repo "$REPO" --log-failed | tail -40
fi

exit "$EXIT_CODE"
