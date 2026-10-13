#!/usr/bin/env bash
# One land-prs step per call: the fixed gh/git commands for steps 2, 6 and 7.
# Every confirmation gate stays in SKILL.md; this script never asks and never loops over a chain.
# Usage:
#   merge-step.sh merge N               — gh pr merge N --merge (no --delete-branch), then print
#                                         "<state> <sha7>"; exit 1 unless the state is MERGED
#   merge-step.sh retarget N            — gh pr edit N --base main, wait 3s, then run `check N`
#   merge-step.sh check N               — print "<base> <mergeable> commits=<K>" for PR N
#   merge-step.sh delete-local B [B...] — git branch -d each B that exists locally (never -D)
#   merge-step.sh remote-heads B [B...] — print which of the B still exist on origin (read-only)
#   merge-step.sh delete-remote B [B...] — git push origin --delete B...; run it as its own Bash call
#   merge-step.sh prune                 — git fetch -q --prune && git branch -a
# PR numbers accept "#N". Branch arguments may not be "main" or start with "-".
# Exit: 0 ok; 1 a step didn't reach its expected result (see output); 2 usage error.
set -euo pipefail

usage() {
  echo "usage: merge-step.sh {merge N|retarget N|check N|delete-local B...|remote-heads B...|delete-remote B...|prune}" >&2
  exit 2
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
  merge)
    [ "$#" -eq 1 ] || usage
    n="$(pr_arg "$1")"
    gh pr merge "$n" --merge
    result="$(gh pr view "$n" --json state,mergeCommit --jq '.state+" "+.mergeCommit.oid[0:7]')"
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
