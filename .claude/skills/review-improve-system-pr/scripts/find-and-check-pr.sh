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
# subdirectory — AND none of the three extra rules below fires.
#
# Extra rules (each one makes a changed file a VIOLATION, exit 2, with the reason printed
# next to the file; exit 2 means "a human must review this", not "this is forbidden"):
#   1. Gate self-edit: anything under the review-improve-system-pr skill (this gate) or the
#      improve-system skill (which defines the routine's auto-apply boundary) — a PR this
#      gate approves must never be able to loosen the gate.
#   2. Trusted-script edit: a file that .claude/settings.json (at the PR base, or as the PR
#      head adds to it) runs without a permission prompt — every path mentioned in any
#      settings string (allow entries, hook commands), with `bash `/`~`/absolute-home forms
#      normalised to repo-relative paths (`$CLAUDE_PROJECT_DIR/`, `$HOME/` and `"$HOME"/`
#      forms and bare `dotfiles/bosko/claude/...` included). A no-space trailing `*`
#      (`foo.sh*`) is a prefix match at run time, so any file starting with that prefix counts
#      too. This also catches a PR that ADDS a script together with an allow entry for it.
#   3. Shared libs: `.claude/lib/` and the skills `lib/` dirs, sourced by those scripts.
#   Renames: the old name of a renamed file is checked as well (gh's `files` list only has
#   the new path; the REST `pulls/N/files` list adds `previous_filename`). That includes
#   `.claude/settings.json` itself: renaming it away is a violation, not a pass.
#
# One exception to the path rule: `.claude/settings.json` passes when check-settings-diff.sh
# confirms the PR only adds scoped, non-high-power entries to `permissions.allow`
# (the fewer-permission-prompts step of the routine) and touches nothing else in it.
#
# The file list, the settings.json comparison and the printed PR_HEAD_SHA all come from
# ONE `gh pr view` snapshot, so the SHA the caller pins its merge to is exactly the
# commit that was checked.
#
# Fails closed: any gh/jq failure exits 3 and never prints `GUARDRAIL: OK`.
#
# Env: REVIEW_SAFE_HOME (default /home/bosko) — the home directory whose NixOS checkout and
# ~/.claude paths in settings.json entries are mapped back to repo paths.
#
# Exit codes:
#   0 — PR found, guardrail holds, safe to show diff and offer merge
#   1 — no open PR found (normal/expected most weeks)
#   2 — PR found but a file violates the guardrail (needs manual review)
#   3 — could not evaluate (gh auth/network/API failure — including failing to fetch
#       settings.json or the rename list, or a base settings.json without a
#       permissions.allow array — unreadable or implausible PR data, or the
#       settings checker not running) — NOT the same as "no PR": the guardrail was not checked
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

# A renamed file shows up in `files` under its NEW path only, so a rename OUT of a trusted
# or gate path would be invisible. The REST file list carries `previous_filename`
# (null unless renamed); fold those old names into the set of paths that get checked.
RENAMED_FROM=$(gh api --paginate "repos/$REPO/pulls/$NUMBER/files?per_page=100" \
  --jq '.[] | .previous_filename // empty') \
  || die3 "could not read PR #$NUMBER rename list (auth/network?) - guardrail NOT evaluated"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SETTINGS_PATH=".claude/settings.json"
SETTINGS_ADDED=""
SAFE_HOME=${REVIEW_SAFE_HOME:-/home/bosko}
[[ "$SAFE_HOME" =~ ^/[A-Za-z0-9._/-]+$ ]] || die3 "REVIEW_SAFE_HOME is not a plain absolute path: $SAFE_HOME"

TMPD=$(mktemp -d) || die3 "could not create temp dir"
trap 'rm -rf "$TMPD"' EXIT

# fetch_settings SIDE OID — raw .claude/settings.json at that commit into $TMPD/SIDE.json
fetch_settings() {
  gh api -H "Accept: application/vnd.github.raw" \
    "repos/$REPO/contents/$SETTINGS_PATH?ref=$2" > "$TMPD/$1.json" 2> /dev/null
}

# The base copy is always needed (it defines which scripts run unprompted), not only when
# the PR touches settings.json. Compare at the PR's own base and head commits, not main's
# tip, which may have moved.
fetch_settings base "$BASE_OID" || die3 "could not fetch $SETTINGS_PATH at PR base - cannot tell which scripts run without a prompt - guardrail NOT evaluated"
jq empty "$TMPD/base.json" > /dev/null 2>&1 || die3 "$SETTINGS_PATH at PR base is not valid JSON - guardrail NOT evaluated"
# Valid JSON is not enough: `{}`, `[]` or an API error body such as {"message":"Not Found"}
# would parse and give an empty trusted set, i.e. nothing flagged.
jq -e '(.permissions.allow | type) == "array"' "$TMPD/base.json" > /dev/null 2>&1 \
  || die3 "$SETTINGS_PATH at PR base has no permissions.allow array (stripped, replaced, or an API error body?) - cannot tell which scripts run without a prompt - guardrail NOT evaluated"

SETTINGS_CHANGED=0
grep -qxF -- "$SETTINGS_PATH" <<< "$FILES" && SETTINGS_CHANGED=1
HEAD_OK=0
if [ "$SETTINGS_CHANGED" -eq 1 ]; then
  fetch_settings head "$HEAD_OID" || die3 "could not fetch $SETTINGS_PATH at PR head - guardrail NOT evaluated"
  jq -e . "$TMPD/head.json" > /dev/null 2>&1 && HEAD_OK=1   # invalid JSON: the checker below refuses it
fi

VIOLATIONS=""
add_violation() { VIOLATIONS="${VIOLATIONS}$1 ($2)"$'\n'; }

# ---- settings.json: allow-list diff (only when the PR touches it) ----
if [ "$SETTINGS_CHANGED" -eq 1 ]; then
  out=$("$SCRIPT_DIR/check-settings-diff.sh" "$TMPD/base.json" "$TMPD/head.json")
  rc=$?
  if [ $rc -eq 0 ]; then
    SETTINGS_ADDED=$out
  elif [ $rc -eq 1 ]; then
    reason=${out#REASON: }
    [ -n "$reason" ] || reason="check-settings-diff.sh refused with no reason"
    add_violation "$SETTINGS_PATH" "$reason"
  else
    # 126/127/etc: the checker itself did not run properly — that is "not evaluated", not "refused"
    die3 "check-settings-diff.sh exited $rc ($out) - guardrail NOT evaluated"
  fi
fi

# ---- Trusted scripts: every repo path settings.json lets run without a prompt ----
# Path candidates come from every string in the base settings (allow entries AND hook
# commands) plus, when the PR changes it, the head settings (so an entry the PR adds counts).
# TRUST maps a repo-relative path or glob pattern -> the settings string that references it.
declare -A TRUST=()

# repo_candidates TOKEN — print the repo-relative path(s) a settings token can refer to
repo_candidates() {
  local t=$1 h rel=""
  t=${t#./}
  case $t in
    .claude/*|dotfiles/bosko/claude/*)
      printf '%s\n' "$t"
      return
      ;;
  esac
  # Hooks run in the project root, so $CLAUDE_PROJECT_DIR/X is the repo path X.
  for h in '$CLAUDE_PROJECT_DIR' '${CLAUDE_PROJECT_DIR}'; do
    if [[ "$t" == "$h"/* ]]; then
      printf '%s\n' "${t#"$h"/}"
      return
    fi
  done
  for h in "$SAFE_HOME" '~' '$HOME' '${HOME}'; do
    if [[ "$t" == "$h"/* ]]; then
      rel=${t#"$h"/}
      break
    fi
  done
  if [ -z "$rel" ] && [[ "$t" =~ ^/(home/[^/]+|root)/(.+)$ ]]; then
    rel=${BASH_REMATCH[2]}
  fi
  [ -n "$rel" ] || return 0
  case $rel in
    NixOS/*) printf '%s\n' "${rel#NixOS/}" ;;
    # ~/.claude is Home Manager's link of dotfiles/bosko/claude; the project's own .claude/
    # is listed too so an ambiguous reading still gets flagged (over-flagging is the safe side).
    .claude/*) printf '%s\n' "dotfiles/bosko/claude/${rel#.claude/}" ".claude/${rel#.claude/}" ;;
  esac
}

# collect_trusted FILE — add FILE's path-like tokens to TRUST
collect_trusted() {
  local entry tok cand
  while IFS=$'\t' read -r entry tok; do
    tok=${tok//[\'\`]/}   # single quotes/backticks are not path characters (the jq split leaves them in)
    [ -n "$tok" ] || continue
    while IFS= read -r cand; do
      [ -n "$cand" ] || continue
      [ -n "${TRUST[$cand]+x}" ] || TRUST["$cand"]=$entry
    done < <(repo_candidates "$tok")
  done < <(jq -r '[.. | strings] | unique | .[] | . as $s
      | ($s | gsub("\""; "") | split("[\\s;|&()<>=,:]+"; "g") | map(select(length > 0)))[]
      | [$s, .] | @tsv' "$1")   # shell quote removal first, so "$HOME"/x.sh reads as $HOME/x.sh
}

collect_trusted "$TMPD/base.json"
[ "$HEAD_OK" -eq 1 ] && collect_trusted "$TMPD/head.json"

# trust_match FILE — print the settings string that runs FILE unprompted; return 1 if none
trust_match() {
  local p
  [ "${#TRUST[@]}" -gt 0 ] || return 1
  for p in "${!TRUST[@]}"; do
    # exact path, or (for a glued `*`) a glob/prefix pattern; the quoted form covers paths
    # that contain glob metacharacters literally
    if [[ "$1" == "$p" || "$1" == $p ]]; then
      printf '%s' "${TRUST[$p]}"
      return 0
    fi
  done
  return 1
}

# Gate self-edit: the gate itself, and the skill that defines the routine's auto-apply boundary.
GATE_DENY_RE='^(\.claude|dotfiles/bosko/claude)/skills/(review-improve-system-pr|improve-system)/'
# Shared helpers the allow-listed scripts source.
SHARED_LIB_RE='^(\.claude|dotfiles/bosko/claude)/(skills/)?lib/'
# The routine's auto-apply boundary.
BOUNDARY_RE='^(\.claude|dotfiles/bosko/claude)/skills/[^/]+/(SKILL\.md|(scripts|assets|references)/.+)$'

# violation_reason FILE — print why FILE needs a human and return 0, or return 1 if it is fine
violation_reason() {
  local f=$1 hit
  if [[ "$f" =~ $GATE_DENY_RE ]]; then
    echo "part of the review gate or the improve-system skill that defines its boundary - a PR this gate approves must not be able to loosen it; human review required"
    return 0
  fi
  if hit=$(trust_match "$f"); then
    echo "a script settings.json lets run without a permission prompt, via entry: $hit - a human must read what it now executes"
    return 0
  fi
  if [[ "$f" =~ $SHARED_LIB_RE ]]; then
    echo "shared helper sourced by the allow-listed scripts - a human must read what it now executes"
    return 0
  fi
  if ! [[ "$f" =~ $BOUNDARY_RE ]]; then
    echo "outside the routine's auto-apply boundary (SKILL.md / scripts / assets / references of a skill)"
    return 0
  fi
  return 1
}

# Anchored regexes, not globs: `*` in [[ == ]] crosses `/`, so the old patterns also
# matched `.claude/skills/x/NOTSKILL.md` and arbitrarily nested paths.
CHECK_LIST=$FILES
[ -z "$RENAMED_FROM" ] || CHECK_LIST="${FILES}"$'\n'"${RENAMED_FROM}"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # judged by check-settings-diff.sh above, but only when the PR's own file list has it; as a
  # rename source (moved away, so there is no head copy to diff) it is a violation below
  [ "$f" = "$SETTINGS_PATH" ] && [ "$SETTINGS_CHANGED" -eq 1 ] && continue
  if reason=$(violation_reason "$f"); then
    add_violation "$f" "$reason"
  fi
done <<< "$CHECK_LIST"

echo "PR_NUMBER: $NUMBER"
echo "PR_TITLE: $TITLE"
echo "PR_URL: $URL"
echo "PR_HEAD_SHA: $HEAD_OID"
echo "PR_FILES:"
echo "$FILES" | sed 's/^/  /'
if [ -n "$RENAMED_FROM" ]; then
  echo "PR_RENAMED_FROM:"
  echo "$RENAMED_FROM" | sed 's/^/  /'
fi
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
  echo "NOTE: exit 2 means a human must review these files before any merge - it is not a verdict that the change is wrong."
  exit 2
fi

echo "GUARDRAIL: OK"
exit 0
