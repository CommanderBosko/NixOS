#!/usr/bin/env bash
# find-and-check-pr.sh — Find the open PR from the weekly improve-system routine
# and verify it stays inside the routine's auto-apply guardrail.
#
# Usage: find-and-check-pr.sh
# Read-only: only `gh pr list`/`gh pr view` calls, never mutates anything.
#
# Guardrail (must hold for every changed file): path starts with
# `.claude/skills/` or `dotfiles/bosko/claude/skills/`, AND is either named
# `SKILL.md` or sits under a `scripts/` or `assets/` subdirectory.
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

VIOLATIONS=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [[ "$f" == .claude/skills/*SKILL.md ]] || [[ "$f" == dotfiles/bosko/claude/skills/*SKILL.md ]] \
     || [[ "$f" == .claude/skills/*/scripts/* ]] || [[ "$f" == dotfiles/bosko/claude/skills/*/scripts/* ]] \
     || [[ "$f" == .claude/skills/*/assets/* ]] || [[ "$f" == dotfiles/bosko/claude/skills/*/assets/* ]]; then
    continue
  fi
  VIOLATIONS="${VIOLATIONS}${f}"$'\n'
done <<< "$FILES"

echo "PR_NUMBER: $NUMBER"
echo "PR_TITLE: $TITLE"
echo "PR_URL: $URL"
echo "PR_FILES:"
echo "$FILES" | sed 's/^/  /'
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
