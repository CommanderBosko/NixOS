#!/usr/bin/env bash
# find-and-check-pr.sh — Find the open PR from the weekly improve-system routine
# and verify it stays inside the routine's auto-apply guardrail.
#
# Usage: find-and-check-pr.sh
# Read-only: only `gh pr list`/`gh pr view`/`gh api` GETs, never mutates anything.
#
# Guardrail (must hold for every changed file): path starts with
# `.claude/skills/` or `dotfiles/bosko/claude/skills/`, AND is either named
# `SKILL.md` or sits under a `scripts/`, `assets/`, or `references/`
# subdirectory.
#
# One exception: `.claude/settings.json` passes when check-settings-diff.sh
# confirms the PR only adds scoped, non-high-power entries to `permissions.allow`
# (the fewer-permission-prompts step of the routine) and touches nothing else in it.
#
# The file list, the settings.json comparison and the printed PR_HEAD_SHA all come from
# ONE `gh pr view` snapshot, so the SHA the caller pins its merge to is exactly the
# commit that was checked.
#
# Fails closed: any gh/jq failure exits 3 and never prints `GUARDRAIL: OK`.
#
# Exit codes:
#   0 — PR found, guardrail holds, safe to show diff and offer merge
#   1 — no open PR found (normal/expected most weeks)
#   2 — PR found but a file violates the guardrail (needs manual review)
#   3 — could not evaluate (gh auth/network/API failure — including failing to fetch
#       settings.json — unreadable or implausible PR data, or the settings checker
#       not running) — NOT the same as "no PR": the guardrail was not checked
set -uo pipefail

REPO="CommanderBosko/NixOS"

die3() {
  echo "ERROR: $1"
  echo "GUARDRAIL: NOT EVALUATED"
  exit 3
}

# Match on the head-branch pattern the routine always uses
# (improve-system/weekly-<date>) rather than the PR title: gh's --search
# mangles a title string containing "()"/":"  (verified empirically —
# `--search "chore(skills): weekly improve-system sweep in:title"` returns
# zero results even against a PR whose title starts with that exact
# string), and the title format has already drifted once in practice
# (PR #4: "chore(skills): weekly improve-system sweep — ..."; PR #6:
# "improve-system weekly sweep — ..."). The head branch is the one thing
# that has stayed stable across every real PR the routine has opened.
PR_JSON=$(gh pr list --repo "$REPO" --state open --limit 1000 --json number,title,headRefName,url,body \
  --jq '[.[] | select(.headRefName | startswith("improve-system/weekly-"))][0] // empty') \
  || die3 "gh pr list failed (auth/network?) - cannot tell whether a PR exists. Try: gh auth status"

if [ -z "$PR_JSON" ]; then
  echo "NO_PR: no open improve-system weekly PR found."
  exit 1
fi

NUMBER=$(jq -r '.number' <<< "$PR_JSON") || die3 "could not parse PR number from gh output"
[[ "$NUMBER" =~ ^[0-9]+$ ]] || die3 "unexpected PR number from gh: '$NUMBER'"
TITLE=$(jq -r '.title' <<< "$PR_JSON") || die3 "could not parse PR title"
URL=$(jq -r '.url' <<< "$PR_JSON") || die3 "could not parse PR url"
BODY=$(jq -r '.body' <<< "$PR_JSON") || die3 "could not parse PR body"

# One snapshot: changed files + the exact base/head commits they belong to.
VIEW_JSON=$(gh pr view "$NUMBER" --repo "$REPO" --json files,baseRefOid,headRefOid) \
  || die3 "could not read PR #$NUMBER files/commits (auth/network?) - guardrail NOT evaluated"
FILES=$(jq -r '.files[].path' <<< "$VIEW_JSON") || die3 "could not parse PR #$NUMBER file list"
FILE_COUNT=$(jq -r '.files | length' <<< "$VIEW_JSON") || die3 "could not count PR #$NUMBER files"
BASE_OID=$(jq -r '.baseRefOid' <<< "$VIEW_JSON") || die3 "could not parse PR #$NUMBER base commit"
HEAD_OID=$(jq -r '.headRefOid' <<< "$VIEW_JSON") || die3 "could not parse PR #$NUMBER head commit"

[ -n "$FILES" ] || die3 "PR #$NUMBER reports no changed files"
# gh caps the files it returns; a list that hits the cap may be truncated, so do not trust it.
[ "$FILE_COUNT" -lt 100 ] || die3 "PR #$NUMBER lists $FILE_COUNT changed files - the list may be truncated, review manually"
[[ "$BASE_OID" =~ ^[0-9a-f]{40}$ ]] || die3 "unexpected base commit from gh: '$BASE_OID'"
[[ "$HEAD_OID" =~ ^[0-9a-f]{40}$ ]] || die3 "unexpected head commit from gh: '$HEAD_OID'"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SETTINGS_PATH=".claude/settings.json"
SETTINGS_ADDED=""
SETTINGS_REASON=""

# Compare settings.json at the PR's own base and head commits (not main's tip,
# which may have moved) and hand both copies to check-settings-diff.sh.
check_settings() {
  local tmp side oid out rc
  tmp=$(mktemp -d) || { SETTINGS_REASON="could not create temp dir"; return 1; }
  for side in base head; do
    oid=$BASE_OID
    [ "$side" = head ] && oid=$HEAD_OID
    if ! gh api -H "Accept: application/vnd.github.raw" \
      "repos/$REPO/contents/$SETTINGS_PATH?ref=$oid" > "$tmp/$side.json" 2> /dev/null; then
      SETTINGS_REASON="could not fetch $SETTINGS_PATH at PR $side"
      rm -rf "$tmp"
      return 3
    fi
  done
  out=$("$SCRIPT_DIR/check-settings-diff.sh" "$tmp/base.json" "$tmp/head.json")
  rc=$?
  rm -rf "$tmp"
  if [ $rc -eq 0 ]; then
    SETTINGS_ADDED=$out
  elif [ $rc -eq 1 ]; then
    SETTINGS_REASON=${out#REASON: }
    [ -n "$SETTINGS_REASON" ] || SETTINGS_REASON="check-settings-diff.sh refused with no reason"
  else
    # 126/127/etc: the checker itself did not run properly — that is "not evaluated", not "refused"
    SETTINGS_REASON="check-settings-diff.sh exited $rc ($out)"
    return 3
  fi
  return $rc
}

VIOLATIONS=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ "$f" = "$SETTINGS_PATH" ]; then
    check_settings
    src=$?
    [ "$src" -eq 0 ] && continue
    [ "$src" -eq 3 ] && die3 "$SETTINGS_REASON - guardrail NOT evaluated"
    VIOLATIONS="${VIOLATIONS}${f} (${SETTINGS_REASON})"$'\n'
    continue
  fi
  # Anchored regex, not globs: `*` in [[ == ]] crosses `/`, so the old patterns also
  # matched `.claude/skills/x/NOTSKILL.md` and arbitrarily nested paths.
  if [[ "$f" =~ ^(\.claude|dotfiles/bosko/claude)/skills/[^/]+/(SKILL\.md|(scripts|assets|references)/.+)$ ]]; then
    continue
  fi
  VIOLATIONS="${VIOLATIONS}${f}"$'\n'
done <<< "$FILES"

echo "PR_NUMBER: $NUMBER"
echo "PR_TITLE: $TITLE"
echo "PR_URL: $URL"
echo "PR_HEAD_SHA: $HEAD_OID"
echo "PR_FILES:"
echo "$FILES" | sed 's/^/  /'
if [ -n "$SETTINGS_ADDED" ]; then
  echo "SETTINGS_ALLOW_ADDED:"
  echo "$SETTINGS_ADDED" | sed 's/^ADDED: /  /'
fi
echo "PR_BODY:"
echo "$BODY"

if [ -n "$VIOLATIONS" ]; then
  echo "GUARDRAIL: VIOLATION"
  echo "OFFENDING_FILES:"
  echo "$VIOLATIONS" | sed '/^$/d;s/^/  /'
  exit 2
fi

echo "GUARDRAIL: OK"
exit 0
