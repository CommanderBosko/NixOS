#!/usr/bin/env bash
# Mechanical git-push helpers: state gathering, then the actual push.
# Usage:
#   push.sh status  [opts]   — print working-tree status, branch, and commits ahead of upstream;
#                              on a non-default branch also the open PR (or the PR `execute --pr` would open)
#   push.sh execute [opts]   — push (with -u if no upstream yet) and report the result;
#                              exits 0 without pushing if origin/<branch>..HEAD is empty.
#                              If the branch is origin's default branch and the push is rejected by
#                              a protection rule (GH013 / PR required), falls back to: new pr/<slug>-<sha>
#                              branch at HEAD, push it, `gh pr create`, reset local default branch to
#                              origin/<default> (clean tree only), stay on the PR branch. Never forces.
#                              Without --pr, any OTHER branch is just pushed: gh is never called.
#                              With --pr, after the push: if an open PR has this branch as its head it
#                              prints its URL; if none exists, opens one with
#                              `gh pr create --base <default>` (Summary + Verification body drafted from
#                              the commits and diff stat) — but never a second PR for a head that
#                              already has a merged/closed one unless new commits were pushed this run.
#                              A non-default branch that tracks a different origin branch (e.g. cut from
#                              origin/main without --no-track) is pushed with `-u origin <branch>`, never
#                              with a bare `git push`. Never merges.
# Options (both modes; the PR ones only matter on a non-default branch):
#   --pr                 execute only: open (or look up) the PR after pushing. Off by default so callers
#                        that just want a push (e.g. session-closer) never trigger PR creation.
#   --base <branch>      PR base instead of origin's default branch (e.g. a stacked PR's parent)
#   --title <text>       PR title instead of the drafted one (oldest commit's subject)
#   --body-file <path>   PR body from this file instead of the drafted one
# Exit codes: 0 ok; 1 push/usage error; 2 pushed fine but the PR step (--pr) failed (gh missing, not
# authenticated, or `gh pr create` failed) — re-running with --pr skips the push and retries the PR.
set -euo pipefail

MODE="${1:-status}"
shift || true

PR_BASE=""
PR_TITLE=""
PR_BODY_FILE=""
OPT_PR=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base) PR_BASE="${2:?--base needs a branch name}"; shift 2 ;;
    --title) PR_TITLE="${2:?--title needs text}"; shift 2 ;;
    --body-file) PR_BODY_FILE="${2:?--body-file needs a path}"; shift 2 ;;
    --pr) OPT_PR=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done
if [ -n "$PR_BODY_FILE" ] && [ ! -f "$PR_BODY_FILE" ]; then
  echo "--body-file: no such file: $PR_BODY_FILE" >&2
  exit 1
fi

PR_FOOTER='🤖 Generated with [Claude Code](https://claude.com/claude-code)'

WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# Base to compare against when the branch has no upstream: origin's default branch
# (origin/HEAD), falling back to origin/main, then origin/master. Prints nothing and
# returns 1 if none exists.
default_base() {
  local ref
  ref="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -n "$ref" ] && git rev-parse --verify --quiet "$ref" >/dev/null; then
    echo "$ref"
    return 0
  fi
  for ref in origin/main origin/master; do
    if git rev-parse --verify --quiet "$ref" >/dev/null; then
      echo "$ref"
      return 0
    fi
  done
  return 1
}

# Sets DEFAULT (origin's default branch name, may be empty) and, when the current branch is a
# non-default branch, FEATURE=1 and PR_BASE (--base, else DEFAULT). FEATURE only says a PR is
# *possible*; execute acts on it only with --pr, status always reports it.
FEATURE=0
DEFAULT=""
resolve_pr_context() {
  DEFAULT="$(default_base 2>/dev/null || true)"
  DEFAULT="${DEFAULT#origin/}"
  [ -n "$DEFAULT" ] && [ -n "$BRANCH" ] && [ "$BRANCH" != "$DEFAULT" ] || return 0
  FEATURE=1
  PR_BASE="${PR_BASE:-$DEFAULT}"
}

# Sets UP (short name of the current branch's upstream, e.g. origin/main; empty if none) and
# RETARGET=1 when that upstream is a DIFFERENT origin branch than origin/<branch> — the memory-
# recorded trap of `git checkout -b X origin/main` without --no-track, where a bare `git push`
# refuses (or, with push.default=upstream, would push to main). Never applied to the default
# branch (it behaves exactly as before), and upstreams on other remotes are left alone too.
# Needs DEFAULT, so call resolve_pr_context first.
UP=""
RETARGET=0
compute_upstream() {
  UP="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  RETARGET=0
  if [ -n "$UP" ] && [ "$BRANCH" != "$DEFAULT" ] && [ "$UP" != "origin/$BRANCH" ] && [ "${UP#origin/}" != "$UP" ]; then
    RETARGET=1
  fi
}

# PRs (any state, any base) whose head branch is $1, newest first, one "STATE URL" line each
# (STATE is OPEN, MERGED or CLOSED); prints nothing if there are none. Any base means a stacked
# child isn't duplicated; any state means a squash-merged branch isn't re-opened. Returns 1 with
# the reason on stderr if gh is missing or the lookup fails.
pr_lookup() {
  local out
  command -v gh >/dev/null 2>&1 || { echo "gh not found on PATH" >&2; return 1; }
  if ! out="$(gh pr list --head "$1" --state all --json state,url --jq '.[] | "\(.state) \(.url)"' 2>"$WORK_DIR/gh.err")"; then
    cat "$WORK_DIR/gh.err" >&2
    return 1
  fi
  printf '%s\n' "$out"
}

# Draft PR title for the commits in $1..HEAD: --title if given, else the oldest commit's subject.
draft_title() {
  local subjects
  if [ -n "$PR_TITLE" ]; then
    printf '%s\n' "$PR_TITLE"
    return 0
  fi
  mapfile -t subjects < <(git log --reverse --format=%s "$1..HEAD")
  printf '%s\n' "${subjects[0]:-$BRANCH}"
}

# Draft PR body for the commits in $1..HEAD: Summary (commit subjects, plus the commit body when
# there is exactly one commit) and Verification (diff stat), ending with the Claude Code footer.
draft_body() {
  local subjects s body
  mapfile -t subjects < <(git log --reverse --format=%s "$1..HEAD")
  echo "## Summary"
  echo
  for s in "${subjects[@]}"; do
    echo "- $s"
  done
  if [ "${#subjects[@]}" -eq 1 ]; then
    body="$(git log -1 --format=%b HEAD | grep -viE '^(co-authored-by|signed-off-by|claude-session):' || true)"
    if [ -n "$body" ]; then
      echo
      printf '%s\n' "$body"
    fi
  fi
  echo
  echo "## Verification"
  echo
  echo "Diff stat against \`$1\`:"
  echo
  echo '```'
  git diff --no-color --stat "$1...HEAD"
  echo '```'
  echo
  echo "$PR_FOOTER"
}

# With --pr, once $1 (a non-default branch) is on origin: print the open PR's URL, or open one
# against base $2. $3 is 1 if this run pushed new commits, else 0: a head that already has a
# merged/closed PR only gets a new one when new commits were pushed (so a squash-merged branch
# isn't re-opened by a repeat run). Returns 2 (with a message that says the push itself
# succeeded) if gh can't do it.
ensure_pr() {
  local lookup url title bodyf
  echo "--- pull request ---"
  if ! lookup="$(pr_lookup "$1" 2>"$WORK_DIR/ensure.err")"; then
    echo "ERROR: $1 is pushed, but the PR lookup failed: $(<"$WORK_DIR/ensure.err")" >&2
    echo "Fix gh (e.g. gh auth status), then re-run push.sh execute --pr — it skips the push and retries the PR." >&2
    return 2
  fi
  url="$(awk '$1 == "OPEN" { print $2; exit }' <<<"$lookup")"
  if [ -n "$url" ]; then
    echo "PR already open for $1: $url"
    return 0
  fi
  if [ -n "$lookup" ] && [ "$3" -eq 0 ]; then
    echo "PR for $1 already exists ($(awk 'NR == 1 { print $1 ": " $2 }' <<<"$lookup")) and nothing new was pushed — not opening another"
    return 0
  fi
  title="$(draft_title "origin/$2")"
  if [ -n "$PR_BODY_FILE" ]; then
    bodyf="$PR_BODY_FILE"
  else
    bodyf="$WORK_DIR/body.md"
    draft_body "origin/$2" >"$bodyf"
  fi
  if ! url="$(gh pr create --base "$2" --head "$1" --title "$title" --body-file "$bodyf" 2>"$WORK_DIR/ensure.err")"; then
    echo "ERROR: $1 is pushed, but 'gh pr create --base $2' failed: $(<"$WORK_DIR/ensure.err")" >&2
    echo "Fix the cause, then re-run push.sh execute --pr — it skips the push and retries the PR." >&2
    return 2
  fi
  echo "opened PR for $1 (base $2): $url"
}

case "$MODE" in
  status)
    BRANCH="$(git branch --show-current)"
    echo "branch: $BRANCH"
    echo "--- git status ---"
    git status --short
    echo "--- commits ahead of upstream ---"
    resolve_pr_context
    compute_upstream
    if [ -n "$UP" ] && [ "$RETARGET" -eq 0 ]; then
      git log --oneline "origin/$BRANCH..HEAD"
    elif [ "$RETARGET" -eq 1 ]; then
      echo "(note: $BRANCH tracks $UP, not origin/$BRANCH — execute will push with -u origin $BRANCH)"
      if git rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null; then
        git log --oneline "origin/$BRANCH..HEAD"
      elif BASE="$(default_base)"; then
        echo "(not on origin yet — commits not on $BASE)"
        git log --oneline "$BASE..HEAD"
      else
        git log --oneline
      fi
    elif BASE="$(default_base)"; then
      echo "(no upstream set yet — commits not on $BASE)"
      git log --oneline "$BASE..HEAD"
    else
      echo "(no upstream set yet and no origin default branch found — all commits on $BRANCH shown)"
      git log --oneline
    fi
    if [ "$FEATURE" -eq 1 ]; then
      echo "--- pull request (base: $PR_BASE) ---"
      if ! git rev-parse --verify --quiet "refs/remotes/origin/$PR_BASE" >/dev/null; then
        echo "(origin/$PR_BASE not found — fetch first; execute --pr will refuse to open a PR)"
      elif ! LOOKUP="$(pr_lookup "$BRANCH" 2>"$WORK_DIR/status.err")"; then
        echo "(could not check for an open PR: $(<"$WORK_DIR/status.err"))"
      elif URL="$(awk '$1 == "OPEN" { print $2; exit }' <<<"$LOOKUP")" && [ -n "$URL" ]; then
        echo "open PR: $URL"
      elif [ -n "$LOOKUP" ] &&
        git rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null &&
        [ "$(git rev-list --count "origin/$BRANCH..HEAD")" -eq 0 ]; then
        echo "no open PR; $(awk 'NR == 1 { print $1 ": " $2 }' <<<"$LOOKUP") already exists and nothing new to push — execute --pr will not open another"
      elif [ "$(git rev-list --count "origin/$PR_BASE..HEAD")" -eq 0 ]; then
        echo "(no commits ahead of origin/$PR_BASE — no PR to open)"
      else
        echo "no open PR — execute --pr would push and open one (plain execute only pushes)"
        echo "title: $(draft_title "origin/$PR_BASE")"
        echo "--- draft body ---"
        draft_body "origin/$PR_BASE"
        echo "--- end draft body ---"
      fi
    fi
    ;;
  execute)
    BRANCH="$(git branch --show-current)"
    resolve_pr_context
    # DO_PR: --pr was asked for AND this is a non-default branch. Without --pr gh is never called.
    DO_PR=0
    if [ "$FEATURE" -eq 1 ] && [ "$OPT_PR" -eq 1 ]; then
      DO_PR=1
    fi
    if [ "$DO_PR" -eq 1 ] && ! git rev-parse --verify --quiet "refs/remotes/origin/$PR_BASE" >/dev/null; then
      echo "ERROR: PR base origin/$PR_BASE not found (git fetch origin, or fix --base); nothing pushed" >&2
      exit 1
    fi
    if [ "$OPT_PR" -eq 1 ] && [ "$FEATURE" -eq 0 ]; then
      echo "note: --pr ignored (not on a non-default branch)" >&2
    fi
    NOTHING=""
    if git rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null; then
      AHEAD="$(git rev-list --count "origin/$BRANCH..HEAD")"
      if [ "$AHEAD" -eq 0 ]; then
        NOTHING="nothing to push: $BRANCH has no commits ahead of origin/$BRANCH"
      fi
    elif BASE="$(default_base)" && [ "$(git rev-list --count "$BASE..HEAD")" -eq 0 ]; then
      NOTHING="nothing to push: $BRANCH has no commits ahead of $BASE"
    fi
    if [ -n "$NOTHING" ]; then
      echo "$NOTHING"
      # With --pr: already on origin, but the branch may still lack its PR (e.g. a retry after the
      # PR step failed): open it if the branch has commits beyond the PR base. ensure_pr (pushed=0)
      # won't open a second PR for a head that already has a merged/closed one.
      if [ "$DO_PR" -eq 1 ] && git rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null &&
        [ "$(git rev-list --count "origin/$PR_BASE..origin/$BRANCH")" -gt 0 ]; then
        ensure_pr "$BRANCH" "$PR_BASE" 0 || exit $?
      fi
      exit 0
    fi
    compute_upstream
    if [ -z "$UP" ]; then
      PUSH=(git push -u origin "$BRANCH")
    elif [ "$RETARGET" -eq 1 ]; then
      # Name the branch and retarget the upstream instead of a bare `git push` (see compute_upstream).
      echo "note: $BRANCH tracks $UP; pushing with -u origin $BRANCH to retarget its upstream" >&2
      PUSH=(git push -u origin "$BRANCH")
    else
      PUSH=(git push)
    fi
    # Capture output so protection errors can be pattern-matched, but still show it.
    if ! OUT="$("${PUSH[@]}" 2>&1)"; then
      echo "$OUT" >&2
      if [ -n "$DEFAULT" ] && [ "$BRANCH" = "$DEFAULT" ] &&
        grep -qiE 'GH013|Repository rule violations|protected branch|must be made through a pull request' <<<"$OUT"; then
        N="$(git rev-list --count "origin/$DEFAULT..HEAD")"
        SUBJECT="$(git log -1 --format=%s)"
        SLUG="$(tr '[:upper:]' '[:lower:]' <<<"$SUBJECT" | tr -c 'a-z0-9\n' '-' | tr -s '-' | cut -c1-40 | sed 's/^-//; s/-$//')"
        PR_BRANCH="pr/${SLUG:-changes}-$(git rev-parse --short=7 HEAD)"
        echo "$DEFAULT is protected: pushing $PR_BRANCH and opening a PR instead" >&2
        git switch -c "$PR_BRANCH"
        git push -u origin "$PR_BRANCH"
        PR_URL="$(gh pr create --fill --base "$DEFAULT" --head "$PR_BRANCH")"
        echo "$PR_URL"
        if [ -z "$(git status --porcelain)" ]; then
          git branch -f "$DEFAULT" "origin/$DEFAULT"
          RESET="local $DEFAULT reset to origin/$DEFAULT"
        else
          RESET="WARNING: working tree dirty, local $DEFAULT NOT reset (run: git branch -f $DEFAULT origin/$DEFAULT)"
        fi
        echo "$DEFAULT is protected: pushed $N commit(s) as PR $PR_URL; $RESET; merge via land-prs"
        exit 0
      fi
      exit 1
    fi
    echo "$OUT"
    echo "--- pushed ---"
    echo "branch: $BRANCH"
    git remote get-url origin
    if [ "$DO_PR" -eq 1 ]; then
      # Don't trust a quiet push: confirm origin really has this commit before opening a PR.
      REMOTE_SHA="$(git ls-remote --heads origin "refs/heads/$BRANCH" 2>/dev/null | cut -f1)" || REMOTE_SHA=""
      if [ "$REMOTE_SHA" != "$(git rev-parse HEAD)" ]; then
        echo "ERROR: push reported success but origin/$BRANCH is not at HEAD (remote: ${REMOTE_SHA:-missing}); no PR opened" >&2
        exit 1
      fi
      ensure_pr "$BRANCH" "$PR_BASE" 1 || exit $?
    fi
    ;;
  *)
    echo "usage: push.sh {status|execute} [--pr] [--base <branch>] [--title <text>] [--body-file <path>]" >&2
    exit 1
    ;;
esac
