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
#   4. Symlinks and submodules: any mode-120000 or mode-160000 entry in the head git tree at
#   or under `.claude/` or `dotfiles/bosko/claude/` (the contents API follows symlinks, so a
#   linked settings.json or script would be judged by its target while Claude Code runs the
#   link), whether or not the PR touches it; and any changed path whose file mode differs
#   between base and head.
#   5. SKILL.md frontmatter: a changed SKILL.md passes only if every column-0 line of its
#   frontmatter is a plain name/description/model/version/argument-hint key (`name` a plain
#   token), indented lines only continue a key (never `name`), the block closes, and nothing in
#   it mentions improve-system (so a gate-named skill cannot shadow the gate). It is an
#   allowlist because allowed-tools/hooks/mcp (which widen what a skill runs without touching
#   settings.json) have many YAML spellings. The gate directories are matched case-insensitively.
#
# Trust set: the settings strings are read at the PR's merge-base AND at the current tip of
# the base branch (an entry added to main after the PR branched still counts), plus the head
# settings when the PR changes them. Every settings file must be exactly one JSON document with
# a permissions.allow array.
#
# One exception to the path rule: `.claude/settings.json` passes when check-settings-diff.sh
# confirms the PR only adds scoped, non-high-power entries to `permissions.allow`
# (the fewer-permission-prompts step of the routine) and touches nothing else in it.
#
# The file list, the settings.json comparison and the printed PR_HEAD_SHA all come from
# ONE `gh pr view` snapshot, so the SHA the caller pins its merge to is exactly the
# commit that was checked. The REST file list (renames) and the PR's current head SHA are
# cross-checked against that snapshot; any disagreement exits 3 rather than guessing.
#
# Output: every line the caller should act on starts at column 0 (PR_HEAD_SHA:, GUARDRAIL:,
# OFFENDING_FILES:). The PR body is attacker-controlled text, so each of its lines is printed
# with a `| ` prefix and carriage returns removed: nothing in it can pose as one of those lines.
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
#       settings.json (base, tip or head), the git trees, a SKILL.md or the rename list, a
#       truncated tree, a settings.json that is not exactly one document with a
#       permissions.allow array, a REST file list or PR head that disagrees with the
#       snapshot, a file name with control characters — unreadable or implausible PR data,
#       or the settings checker not running) — NOT the same as "no PR": the guardrail was not checked
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
VIEW_JSON=$(gh pr view "$NUMBER" --repo "$REPO" --json files,baseRefOid,baseRefName,headRefOid) \
  || die3 "could not read PR #$NUMBER files/commits (auth/network?) - guardrail NOT evaluated"
FILES=$(jq -r '.files[].path' <<< "$VIEW_JSON") || die3 "could not parse PR #$NUMBER file list"
FILE_COUNT=$(jq -r '.files | length' <<< "$VIEW_JSON") || die3 "could not count PR #$NUMBER files"
BASE_OID=$(jq -r '.baseRefOid' <<< "$VIEW_JSON") || die3 "could not parse PR #$NUMBER base commit"
BASE_REF=$(jq -r '.baseRefName' <<< "$VIEW_JSON") || die3 "could not parse PR #$NUMBER base branch"
HEAD_OID=$(jq -r '.headRefOid' <<< "$VIEW_JSON") || die3 "could not parse PR #$NUMBER head commit"

[ -n "$FILES" ] || die3 "PR #$NUMBER reports no changed files"
# A file name with a newline or other control character could print a line that looks like
# one of ours, so refuse to list it at all.
jq -e '[.files[].path | test("[\u0001-\u001f\u007f]")] | any | not' <<< "$VIEW_JSON" > /dev/null \
  || die3 "PR #$NUMBER has a changed file name with control characters - cannot be listed safely, review manually"
# gh caps the files it returns; a list that hits the cap may be truncated, so do not trust it.
[ "$FILE_COUNT" -lt 100 ] || die3 "PR #$NUMBER lists $FILE_COUNT changed files - the list may be truncated, review manually"
[[ "$BASE_OID" =~ ^[0-9a-f]{40}$ ]] || die3 "unexpected base commit from gh: '$BASE_OID'"
[[ "$HEAD_OID" =~ ^[0-9a-f]{40}$ ]] || die3 "unexpected head commit from gh: '$HEAD_OID'"
[[ "$BASE_REF" =~ ^[A-Za-z0-9._/-]+$ && "$BASE_REF" != null ]] || die3 "unexpected base branch name from gh: '$BASE_REF'"
DEFAULT_BRANCH=$(gh api "repos/$REPO" --jq .default_branch) || die3 "could not read the default branch of $REPO - guardrail NOT evaluated"
[[ "$DEFAULT_BRANCH" =~ ^[A-Za-z0-9._/-]+$ ]] || die3 "unexpected default branch from gh: '$DEFAULT_BRANCH'"
TITLE=${TITLE//[[:cntrl:]]/}
URL=${URL//[[:cntrl:]]/}

# A renamed file shows up in `files` under its NEW path only, so a rename OUT of a trusted
# or gate path would be invisible. The REST file list carries `previous_filename`
# (null unless renamed); fold those old names into the set of paths that get checked.
REST_TSV=$(gh api --paginate "repos/$REPO/pulls/$NUMBER/files?per_page=100" \
  --jq '.[] | [.filename, (.previous_filename // "")] | @tsv') \
  || die3 "could not read PR #$NUMBER rename list (auth/network?) - guardrail NOT evaluated"
# The two lists come from separate calls. An empty, partial or shifted REST answer would hide a
# rename out of a trusted path, so the file sets must be identical.
[ "$(cut -f1 <<< "$REST_TSV" | LC_ALL=C sort)" = "$(LC_ALL=C sort <<< "$FILES")" ] \
  || die3 "PR #$NUMBER: the REST file list does not match gh's (empty, partial or changed between calls?) - guardrail NOT evaluated"
RENAMED_FROM=$(awk -F'\t' '$2 != "" { print $2 }' <<< "$REST_TSV")
PULL_HEAD=$(gh api "repos/$REPO/pulls/$NUMBER" --jq .head.sha) \
  || die3 "could not re-read PR #$NUMBER head commit - guardrail NOT evaluated"
[ "$PULL_HEAD" = "$HEAD_OID" ] \
  || die3 "PR #$NUMBER head moved from $HEAD_OID to $PULL_HEAD between reads - guardrail NOT evaluated"

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

# check_settings_file FILE LABEL - FILE must be exactly one JSON document holding a
# permissions.allow array. Valid JSON is not enough: `{}`, `[]` or an API error body such as
# {"message":"Not Found"} would parse and give an empty trusted set (nothing flagged), and
# `jq -e` alone judges only the LAST of several documents.
check_settings_file() {
  jq empty "$1" > /dev/null 2>&1 || die3 "$SETTINGS_PATH at $2 is not valid JSON - guardrail NOT evaluated"
  jq -es 'length == 1 and ((.[0].permissions.allow | type) == "array")' "$1" > /dev/null 2>&1 \
    || die3 "$SETTINGS_PATH at $2 is not exactly one JSON document with a permissions.allow array (stripped, replaced, doubled, or an API error body?) - cannot tell which scripts run without a prompt - guardrail NOT evaluated"
}

# The base copy is always needed (it defines which scripts run unprompted), not only when
# the PR touches settings.json. It is read at the PR's merge-base AND at the current tip of
# the base branch: main may have gained an allow entry or hook for an existing script since
# the PR branched, and editing that script must still be flagged.
fetch_settings base "$BASE_OID" || die3 "could not fetch $SETTINGS_PATH at PR base - cannot tell which scripts run without a prompt - guardrail NOT evaluated"
check_settings_file "$TMPD/base.json" "PR base"
TIP_OID=$(gh api "repos/$REPO/commits/$BASE_REF" --jq .sha) \
  || die3 "could not resolve the tip of $BASE_REF - cannot read the current trust set - guardrail NOT evaluated"
[[ "$TIP_OID" =~ ^[0-9a-f]{40}$ ]] || die3 "unexpected tip commit for $BASE_REF from gh: '$TIP_OID'"
fetch_settings tip "$TIP_OID" || die3 "could not fetch $SETTINGS_PATH at the tip of $BASE_REF - guardrail NOT evaluated"
check_settings_file "$TMPD/tip.json" "the tip of $BASE_REF"

# Git trees (recursive) at both commits: symlinks, submodules and file modes are invisible to
# the file list and to the contents API, which follows links.
fetch_tree() { gh api "repos/$REPO/git/trees/$2?recursive=1" > "$TMPD/$1-tree.json" 2> /dev/null; }
fetch_tree head "$HEAD_OID" || die3 "could not read the head git tree - symlinks and file modes cannot be checked - guardrail NOT evaluated"
fetch_tree base "$BASE_OID" || die3 "could not read the base git tree - file modes cannot be checked - guardrail NOT evaluated"
for side in head base; do
  # Valid JSON is not enough: an empty tree, entries without a string mode/path or a non-object
  # entry would make the symlink and mode checks silently see nothing.
  jq -e '(.truncated == false) and ((.tree | type) == "array") and ((.tree | length) > 0)
         and all(.tree[]; ((.mode | type) == "string") and ((.path | type) == "string"))' "$TMPD/$side-tree.json" > /dev/null 2>&1 \
    || die3 "the $side git tree is truncated, empty or malformed - symlinks and file modes cannot be checked - guardrail NOT evaluated"
  jq -r '.tree[] | [.mode, .path] | @tsv' "$TMPD/$side-tree.json" > "$TMPD/$side-modes.tsv" \
    || die3 "could not list the $side git tree - guardrail NOT evaluated"
done
jq -e 'any(.tree[]; .path == ".claude/settings.json")' "$TMPD/base-tree.json" > /dev/null 2>&1 \
  || die3 "the base git tree has no $SETTINGS_PATH although it was fetched - implausible tree - guardrail NOT evaluated"
jq -r '.tree[] | select(.mode == "120000" or .mode == "160000") | [.mode, .path] | @tsv' "$TMPD/head-tree.json" \
  | LC_ALL=C sort -t$'\t' -k2 > "$TMPD/links.tsv" || die3 "could not list symlinks in the head git tree - guardrail NOT evaluated"

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

# normalize_path TOKEN - drop empty and `.` segments (`//`, `/./`, a leading `./`) and cancel
# `x/..` pairs one segment at a time, leaving leading `..` segments and a leading or trailing `/`.
normalize_path() {
  local p=$1 lead="" trail="" seg out=() segs=()
  [[ "$p" == */* ]] || { printf '%s' "$p"; return; }
  [[ "$p" == /* ]] && lead=/
  [[ "$p" == */ ]] && trail=/
  IFS=/ read -ra segs <<< "$p"
  for seg in "${segs[@]}"; do
    case $seg in
      ""|.) continue ;;
      ..) if [ "${#out[@]}" -gt 0 ] && [ "${out[${#out[@]}-1]}" != .. ]; then unset "out[${#out[@]}-1]"; continue; fi ;;
    esac
    out+=("$seg")
  done
  [ "${#out[@]}" -gt 0 ] || { printf '%s' "$p"; return; }
  local IFS=/
  printf '%s' "$lead${out[*]}$trail"
}

# repo_candidates TOKEN - print the repo-relative path(s) a settings token can refer to
repo_candidates() {
  local t=$1 n h rel="" r printed=0
  # `//`, `/./`, a leading `./` and brace-list braces name the same file but defeat every
  # prefix test below, so normalise first and map the normalised token instead.
  n=$(normalize_path "$t")
  n=${n//[\{\}]/}
  if [ "$n" != "$t" ]; then
    repo_candidates "$n"
    return
  fi
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
  case $rel in
    NixOS/*) printf '%s\n' "${rel#NixOS/}"; printed=1 ;;
    # ~/.claude is Home Manager's link of dotfiles/bosko/claude; the project's own .claude/
    # is listed too so an ambiguous reading still gets flagged (over-flagging is the safe side).
    .claude/*) printf '%s\n' "dotfiles/bosko/claude/${rel#.claude/}" ".claude/${rel#.claude/}"; printed=1 ;;
  esac
  [ "$printed" -eq 0 ] || return 0
  # Fallback for every other spelling (`${CLAUDE_PROJECT_DIR:-.}/...`, `$(git rev-parse
  # --show-toplevel)/...`, an unfamiliar root): whatever follows a `.claude/` or
  # `dotfiles/bosko/claude/` substring is a candidate. Over-flagging is the safe side.
  case $t in
    *dotfiles/bosko/claude/*) printf '%s\n' "dotfiles/bosko/claude/${t#*dotfiles/bosko/claude/}" ;;
  esac
  case $t in
    *.claude/*) r=${t#*.claude/}; printf '%s\n' ".claude/$r" "dotfiles/bosko/claude/$r"; return ;;
  esac
  # A relative script path with no recognisable root (`cd .claude && ./skills/x/scripts/y.sh`,
  # a brace-list leftover like `y.sh`): match it under any directory. Leading `../` segments
  # (the script sits next to the directory we cd'd into) are dropped from the tail.
  if [[ "$t" =~ ^[A-Za-z0-9._/-]+\.(sh|py)\*?$ ]]; then
    r=${t#/}
    while [[ "$r" == ../* ]]; do r=${r#../}; done
    printf '%s\n' "*/$r"
  fi
}

# collect_trusted FILE — add FILE's path-like tokens to TRUST
collect_trusted() {
  local entry tok cand isdir
  while IFS=$'\t' read -r entry tok; do
    tok=${tok//[\'\`]/}   # single quotes/backticks are not path characters (the jq split leaves them in)
    [ -n "$tok" ] || continue
    while IFS= read -r cand; do
      [ -n "$cand" ] || continue
      isdir=0
      [[ "$cand" == */ ]] && { isdir=1; cand=${cand%/}; }
      [ -n "$cand" ] || continue
      [ -n "${TRUST[$cand]+x}" ] || TRUST["$cand"]=$entry
      # A directory token (`cd .../scripts && ./x.sh`: a trailing slash, or no dot in its last
      # component) trusts what is under it.
      if [ "$isdir" -eq 1 ]; then
        [ -n "${TRUST["$cand/*"]+x}" ] || TRUST["$cand/*"]=$entry
      else
        case ${cand##*/} in
          *.*|*\**|"") ;;
          *) [ -n "${TRUST["$cand/*"]+x}" ] || TRUST["$cand/*"]=$entry ;;
        esac
      fi
    done < <(repo_candidates "$tok")
  done < <(jq -r '[.. | strings] | unique | .[] | . as $s
      | ($s | gsub("\""; "") | split("[\\s;|&()<>=,:]+"; "g") | map(select(length > 0)))[]
      | [$s, .] | @tsv' "$1")   # shell quote removal first, so "$HOME"/x.sh reads as $HOME/x.sh
}

collect_trusted "$TMPD/base.json"
collect_trusted "$TMPD/tip.json"
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
  local f=$1 fl=${1,,} hit
  # the gate directories are matched case-insensitively (a differently-cased copy must not slip past)
  if [[ "$fl" =~ $GATE_DENY_RE ]]; then
    echo "part of the review gate or the improve-system skill that defines its boundary - a PR this gate approves must not be able to loosen it; human review required"
    return 0
  fi
  if hit=$(trust_match "$f"); then
    echo "a script settings.json lets run without a permission prompt, via entry: $hit - a human must read what it now executes"
    return 0
  fi
  if [[ "$fl" =~ $SHARED_LIB_RE ]]; then
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

# ---- Git tree checks: symlinks/submodules in the trust roots, and mode changes ----
declare -A HMODE=() BMODE=()
while IFS=$'\t' read -r m p; do HMODE["$p"]=$m; done < "$TMPD/head-modes.tsv"
while IFS=$'\t' read -r m p; do BMODE["$p"]=$m; done < "$TMPD/base-modes.tsv"
# exactly the trust roots and their parent directories (a symlinked parent redirects everything below it)
TRUST_ROOT_RE='^(\.claude(/|$)|dotfiles$|dotfiles/bosko$|dotfiles/bosko/claude(/|$))'
while IFS=$'\t' read -r m p; do
  [[ "$p" =~ $TRUST_ROOT_RE ]] || continue
  kind=symlink; [ "$m" = 160000 ] && kind=submodule
  add_violation "$p" "is a $kind (mode $m) inside the trust boundary - the contents API follows links, so a linked settings.json or script would be judged by its target while Claude Code runs the link; human review required"
done < "$TMPD/links.tsv"
[ "$BASE_REF" = "$DEFAULT_BRANCH" ] || add_violation "PR #$NUMBER" "targets $BASE_REF, not the default branch $DEFAULT_BRANCH - the trust set was read from that branch's settings.json; human review required"

# ---- SKILL.md frontmatter (read at the PR head) ----
check_skill_frontmatter() {
  local f=$1 blob fm bad
  if ! [[ "$f" =~ ^[A-Za-z0-9._/+-]+$ ]]; then
    add_violation "$f" "SKILL.md path has unusual characters - its frontmatter cannot be read safely; human review required"
    return
  fi
  blob=$(gh api -H "Accept: application/vnd.github.raw" "repos/$REPO/contents/$f?ref=$HEAD_OID") \
    || die3 "could not read $f at PR head - its frontmatter was NOT checked - guardrail NOT evaluated"
  # The frontmatter block as Claude Code would read it. Its regex is /^---\s*\n([\s\S]*?)---\s*\n?/
  # after one BOM is stripped; JS \s also matches NBSP, U+202F and U+FEFF, which awk's
  # [[:space:]] does not, so the opener here is just a line starting with `---` (over-flagging
  # `--- # c` and `----` is the safe direction). The block runs to the next line that is only
  # `---`; because Claude closes at the first `---` anywhere, mine can only be a superset of its
  # block. A lone CR is a YAML line break, so CR becomes LF (CRLF then just adds blank lines).
  fm=$(tr '\r' '\n' <<< "$blob" | LC_ALL=C sed '1s/^\xEF\xBB\xBF//' \
    | awk 'NR == 1 { if ($0 !~ /^---/) exit; inside = 1; next } inside && /^---[[:space:]]*$/ { closed = 1; exit } inside { print } END { if (inside && !closed) print "@@UNCLOSED@@" }') \
    || die3 "could not extract the frontmatter of $f - guardrail NOT evaluated"
  # An allowlist, not a search for the bad keys: allowed-tools, hooks and mcp have many YAML
  # spellings (quoted keys, flow mappings, `? key`, an indented block, merge keys). Every
  # column-0 line must be a known plain key; an indented line is only a continuation of one,
  # never of `name`, and `name` must be a plain token (no quotes, escapes, comment or tag, which
  # could spell a gate name that a text search would not see).
  bad=$(awk '
    /^[[:space:]]*$/ { next }
    /^#/ { next }
    /^[[:space:]]/ { if (!seen) { print "an indented line before any key: " $0; exit }
                     if (last == "name") { print "an indented continuation of name: " $0; exit }
                     next }
    /^name:/ { if ($0 !~ /^name:[[:space:]]+[A-Za-z0-9._-]+[[:space:]]*$/) { print "a name that is not a plain token: " $0; exit }
               seen = 1; last = "name"; next }
    /^(description|model|version|argument-hint):([[:space:]]|$)/ { seen = 1; last = "other"; next }
    { print "a line outside the known keys: " $0; exit }
  ' <<< "$fm") || die3 "could not check the frontmatter of $f - guardrail NOT evaluated"
  if [ -n "$bad" ] || grep -qx '@@UNCLOSED@@' <<< "$fm"; then
    add_violation "$f" "SKILL.md frontmatter is not just the known plain keys (name, description, model, version, argument-hint) - ${bad:-it never closes}; allowed-tools, hooks and mcp widen what a skill can run without touching settings.json and have many YAML spellings, so anything unfamiliar goes to a human"
  fi
  # a name that is, or contains, the gate's or improve-system's (any quoting, comment, tag or folded form)
  if grep -qiE 'improve-system' <<< "$fm"; then
    add_violation "$f" "SKILL.md frontmatter mentions improve-system / review-improve-system-pr - a skill with that name could shadow the gate or improve-system; human review required"
  fi
}

while IFS= read -r f; do
  [ -z "$f" ] && continue
  # a changed path whose file mode differs between base and head (executable bit, symlink <-> file)
  if [ -n "${HMODE["$f"]+x}" ] && [ -n "${BMODE["$f"]+x}" ] && [ "${HMODE["$f"]}" != "${BMODE["$f"]}" ]; then
    add_violation "$f" "file mode changed (${BMODE["$f"]} -> ${HMODE["$f"]}) - an executable bit or symlink change is not visible in the diff; human review required"
  fi
  # a changed SKILL.md that still exists at head (the gate's own dirs are flagged below anyway)
  if [ "${f##*/}" = SKILL.md ] && [ -n "${HMODE["$f"]+x}" ] && ! [[ "${f,,}" =~ $GATE_DENY_RE ]]; then
    check_skill_frontmatter "$f"
  fi
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
# The body is attacker-controlled: prefix every line and drop carriage returns so none of it
# can pose as a PR_HEAD_SHA:/GUARDRAIL: line.
printf '%s\n' "$BODY" | tr -d '\r' | sed 's/^/| /'

if [ -n "$VIOLATIONS" ]; then
  echo "GUARDRAIL: VIOLATION"
  echo "OFFENDING_FILES:"
  echo "$VIOLATIONS" | sed '/^$/d;s/^/  /'
  echo "NOTE: exit 2 means a human must review these files before any merge - it is not a verdict that the change is wrong."
  exit 2
fi

echo "GUARDRAIL: OK"
exit 0
