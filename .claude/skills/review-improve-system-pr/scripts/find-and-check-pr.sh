#!/usr/bin/env bash
# find-and-check-pr.sh — Find the open PR from the weekly improve-system routine
# and verify it stays inside the routine's auto-apply guardrail.
#
# Usage: find-and-check-pr.sh
# Read-only: only `gh pr list`/`gh pr view` calls, never mutates anything.
#
# Guardrail (must hold for every changed file): path starts with
# `.claude/skills/` or `dotfiles/bosko/claude/skills/`, AND is either named
# `SKILL.md` or sits under a `scripts/`, `assets/`, or `references/`
# subdirectory.
#
# One exception: `.claude/settings.json` passes when check-settings-diff.sh
# confirms the PR only adds scoped entries to `permissions.allow` (the
# fewer-permission-prompts step of the routine) and touches nothing else in it.
#
# Exit codes:
#   0 — PR found, guardrail holds, safe to show diff and offer merge
#   1 — no open PR found (normal/expected most weeks)
#   2 — PR found but a file violates the guardrail (needs manual review)
set -uo pipefail

REPO="CommanderBosko/NixOS"

# Match on the head-branch pattern the routine always uses
# (improve-system/weekly-<date>) rather than the PR title: gh's --search
# mangles a title string containing "()"/":"  (verified empirically —
# `--search "chore(skills): weekly improve-system sweep in:title"` returns
# zero results even against a PR whose title starts with that exact
# string), and the title format has already drifted once in practice
# (PR #4: "chore(skills): weekly improve-system sweep — ..."; PR #6:
# "improve-system weekly sweep — ..."). The head branch is the one thing
# that has stayed stable across every real PR the routine has opened.
PR_JSON=$(gh pr list --repo "$REPO" --state open --json number,title,headRefName,url,body \
  --jq '[.[] | select(.headRefName | startswith("improve-system/weekly-"))][0] // empty')

if [ -z "$PR_JSON" ]; then
  echo "NO_PR: no open improve-system weekly PR found."
  exit 1
fi

NUMBER=$(echo "$PR_JSON" | jq -r '.number')
TITLE=$(echo "$PR_JSON" | jq -r '.title')
URL=$(echo "$PR_JSON" | jq -r '.url')
BODY=$(echo "$PR_JSON" | jq -r '.body')

FILES=$(gh pr view "$NUMBER" --repo "$REPO" --json files --jq '.files[].path')

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SETTINGS_PATH=".claude/settings.json"
SETTINGS_ADDED=""
SETTINGS_REASON=""

# Compare settings.json at the PR's own base and head commits (not main's tip,
# which may have moved) and hand both copies to check-settings-diff.sh.
check_settings() {
  local oids base_oid head_oid tmp side oid out rc
  oids=$(gh pr view "$NUMBER" --repo "$REPO" --json baseRefOid,headRefOid \
    --jq '.baseRefOid + " " + .headRefOid') || { SETTINGS_REASON="could not read PR commits"; return 1; }
  read -r base_oid head_oid <<< "$oids"
  tmp=$(mktemp -d) || { SETTINGS_REASON="could not create temp dir"; return 1; }
  for side in base head; do
    oid=$base_oid
    [ "$side" = head ] && oid=$head_oid
    if ! gh api -H "Accept: application/vnd.github.raw" \
      "repos/$REPO/contents/$SETTINGS_PATH?ref=$oid" > "$tmp/$side.json" 2> /dev/null; then
      SETTINGS_REASON="could not fetch $SETTINGS_PATH at PR $side"
      rm -rf "$tmp"
      return 1
    fi
  done
  out=$("$SCRIPT_DIR/check-settings-diff.sh" "$tmp/base.json" "$tmp/head.json")
  rc=$?
  rm -rf "$tmp"
  if [ $rc -eq 0 ]; then
    SETTINGS_ADDED=$out
  else
    SETTINGS_REASON=${out#REASON: }
  fi
  return $rc
}

VIOLATIONS=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ "$f" = "$SETTINGS_PATH" ]; then
    check_settings && continue
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
