#!/usr/bin/env bash
# One land-prs step per call: the fixed gh/git commands for steps 2, 6 and 7.
# Every confirmation gate stays in SKILL.md; this script never asks and never loops over a chain.
# Usage:
#   merge-step.sh wait N [SECONDS]      — poll N's CI checks every 10s until all have finished (default
#                                         cap 540s). Call it with the Bash tool's `timeout: 600000`: a
#                                         wait runs 2-3 minutes or more and the 120000 ms default would
#                                         kill it mid-poll; keep SECONDS <= 540 so it ends inside the
#                                         10-minute tool maximum. Exit 0 all passed (or no check ever
#                                         appeared, after a 60s grace), 1 one failed, 3 cap hit with
#                                         checks still pending, 4 `gh` kept failing so the state is unknown
#   merge-step.sh merge N [HEAD_SHA]    — gh pr merge N --merge --match-head-commit HEAD_SHA (no
#                                         --delete-branch), then print "<state> <sha7>"; exit 1 unless
#                                         the state is MERGED. HEAD_SHA is the full 40-hex `head=` that
#                                         `wait` printed; without it the current head is read first.
#                                         GitHub refuses the merge if the head moved after the checks.
#                                         Exit 5 = the merge command succeeded but the follow-up state
#                                         check failed: the PR probably landed, verify with gh pr view
#   merge-step.sh retarget N            — gh pr edit N --base main, wait 3s, then run `check N`
#   merge-step.sh check N               — print "<base> <mergeable> commits=<K>" for PR N
#   merge-step.sh delete-local B [B...] — git branch -d each B that exists locally (never -D)
#   merge-step.sh remote-heads B [B...] — print which of the B still exist on origin (read-only)
#   merge-step.sh delete-remote B [B...] — git push origin --delete B...; run it as its own Bash call
#   merge-step.sh prune                 — git fetch -q --prune && git branch -a
# PR numbers accept "#N". Branch arguments may not be "main" or start with "-".
# Exit: 0 ok; 1 a step didn't reach its expected result (see output); 2 usage error;
#       3 `wait` hit its cap with checks still pending;
#       4 `wait` could not read the checks: 5 consecutive `gh` failures, or the cap hit while the
#         latest query was failing. Never reported as "pending" (3), because the state is unknown;
#       5 `merge` ran `gh pr merge` successfully but could not read the PR state afterwards.
set -euo pipefail

usage() {
  echo "usage: merge-step.sh {wait N [SECONDS]|merge N [HEAD_SHA]|retarget N|check N|delete-local B...|remote-heads B...|delete-remote B...|prune}" >&2
  exit 2
}

# The two env overrides exist only so the tests can run `wait` in seconds, not minutes.
POLL_SECS="${MERGE_STEP_POLL_SECS:-10}"
NO_CHECKS_GRACE_SECS="${MERGE_STEP_NO_CHECKS_GRACE_SECS:-60}"
MAX_QUERY_FAILURES=5   # consecutive failed `gh` queries before `wait` gives up (exit 4)

# stdin: `gh pr view --json statusCheckRollup`. Prints "pass", "none", "pending <names>" or "fail <names>".
# A CheckRun is pending until COMPLETED; a StatusContext is pending while PENDING/EXPECTED.
# SKIPPED and NEUTRAL count as passing.
rollup_state() {
  jq -r '
    def verdict:
      if .__typename == "StatusContext"
      then (if .state == "SUCCESS" then "pass"
            elif (.state == "PENDING" or .state == "EXPECTED") then "pending"
            else "fail" end)
      else (if .status != "COMPLETED" then "pending"
            elif (.conclusion | IN("SUCCESS", "SKIPPED", "NEUTRAL")) then "pass"
            else "fail" end)
      end;
    [ (.statusCheckRollup // [])[] | {l: (.name // .context), v: verdict} ] as $r
    | if ($r | length) == 0 then "none"
      elif any($r[]; .v == "fail") then "fail " + ([$r[] | select(.v == "fail") | .l] | join(", "))
      elif any($r[]; .v == "pending") then "pending " + ([$r[] | select(.v == "pending") | .l] | join(", "))
      else "pass" end'
}

pr_arg() {
  [[ "${1:-}" =~ ^#?[0-9]+$ ]] || usage
  printf '%s\n' "${1#\#}"
}

branch_args() {
  [ "$#" -gt 0 ] || usage
  local b
  for b in "$@"; do
    if [[ -z "$b" || "$b" == -* || "$b" == main ]]; then
      echo "refusing branch argument: '$b'" >&2
      exit 2
    fi
  done
}

check_pr() {
  gh pr view "$1" --json baseRefName,mergeable,commits \
    --jq '.baseRefName+" "+.mergeable+" commits="+(.commits|length|tostring)'
}

MODE="${1:-}"
if [ "$#" -gt 0 ]; then shift; fi

case "$MODE" in
  wait)
    [ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
    n="$(pr_arg "$1")"
    limit="${2:-540}"
    [[ "$limit" =~ ^[0-9]+$ ]] || usage
    start="$SECONDS"
    last=""
    seen_checks=0   # 1 once any check has been observed in the rollup
    head=""         # the PR head sha seen on the latest good query, printed for `merge`
    failures=0      # consecutive failed (or empty-output) gh queries
    while :; do
      if json="$(gh pr view "$n" --json statusCheckRollup,headRefOid)" \
        && state="$(rollup_state <<<"$json")" && [ -n "$state" ]; then
        failures=0
        head="$(jq -r '.headRefOid // ""' <<<"$json")"
      else
        state="error"
        failures=$((failures + 1))
      fi
      elapsed=$((SECONDS - start))
      case "$state" in
        pass)
          echo "checks passed (${elapsed}s)${head:+ head=$head}"
          exit 0
          ;;
        fail*)
          echo "#$n: failing checks: ${state#fail }" >&2
          exit 1
          ;;
        none)
          if [ "$seen_checks" -eq 1 ]; then
            # Checks were seen earlier, so an empty rollup is a blip (a re-run, a stale API
            # read), not "this repo has no checks". Never treat it as done.
            msg="check rollup went empty after checks were seen, re-checking"
          elif [ "$elapsed" -ge "$NO_CHECKS_GRACE_SECS" ]; then
            echo "no checks reported after ${elapsed}s, nothing to wait for${head:+ head=$head}"
            exit 0
          else
            msg="no checks reported yet"
          fi
          ;;
        pending*)
          seen_checks=1
          msg="waiting on: ${state#pending }"
          ;;
        *) msg="gh query failed (${failures}/${MAX_QUERY_FAILURES}), retrying" ;;
      esac
      if [ "$msg" != "$last" ]; then
        echo "[${elapsed}s] $msg"
        last="$msg"
      fi
      if [ "$state" = error ] && [ "$failures" -ge "$MAX_QUERY_FAILURES" ]; then
        echo "#$n: gh query failed ${failures} times in a row, CI state unknown" >&2
        exit 4
      fi
      if [ "$elapsed" -ge "$limit" ]; then
        if [ "$state" = error ]; then
          echo "#$n: cap hit after ${elapsed}s while the latest gh query was failing, CI state unknown" >&2
          exit 4
        fi
        echo "#$n: still not finished after ${elapsed}s ($msg)" >&2
        exit 3
      fi
      sleep "$POLL_SECS"
    done
    ;;
  merge)
    [ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
    n="$(pr_arg "$1")"
    head="${2:-}"
    if [ -z "$head" ]; then
      head="$(gh pr view "$n" --json headRefOid --jq .headRefOid)" || {
        echo "#$n: could not read the PR head sha, nothing merged" >&2
        exit 1
      }
    fi
    [[ "$head" =~ ^[0-9a-f]{40}$ ]] || { echo "merge: HEAD_SHA must be the full 40-hex sha, got '$head'" >&2; exit 2; }
    if ! gh pr merge "$n" --merge --match-head-commit "$head"; then
      echo "#$n: gh pr merge failed (if the head moved after the checks passed, re-run wait and merge with the new head)" >&2
      exit 1
    fi
    if ! result="$(gh pr view "$n" --json state,mergeCommit --jq '.state+" "+.mergeCommit.oid[0:7]')"; then
      echo "#$n: merged, but state check failed - verify with: gh pr view $n" >&2
      exit 5
    fi
    echo "$result"
    if [[ "$result" != MERGED\ * ]]; then
      echo "#$n: expected MERGED <sha>, got: $result" >&2
      exit 1
    fi
    ;;
  retarget)
    [ "$#" -eq 1 ] || usage
    n="$(pr_arg "$1")"
    gh pr edit "$n" --base main
    sleep 3
    check_pr "$n"
    ;;
  check)
    [ "$#" -eq 1 ] || usage
    n="$(pr_arg "$1")"
    check_pr "$n"
    ;;
  delete-local)
    branch_args "$@"
    refused=0
    for b in "$@"; do
      if [ -z "$(git branch --list "$b")" ]; then
        echo "not local, skipped: $b"
      elif git branch -d "$b"; then
        :
      else
        echo "refused by git branch -d (not escalating to -D): $b"
        refused=1
      fi
    done
    exit "$refused"
    ;;
  remote-heads)
    branch_args "$@"
    heads="$(git ls-remote --heads origin "$@")"
    for b in "$@"; do
      if awk -v ref="refs/heads/$b" '$2 == ref { found = 1 } END { exit !found }' <<<"$heads"; then
        echo "on origin: $b"
      else
        echo "already gone: $b"
      fi
    done
    ;;
  delete-remote)
    branch_args "$@"
    git push origin --delete "$@"
    ;;
  prune)
    [ "$#" -eq 0 ] || usage
    git fetch -q --prune
    git branch -a
    ;;
  *)
    usage
    ;;
esac
