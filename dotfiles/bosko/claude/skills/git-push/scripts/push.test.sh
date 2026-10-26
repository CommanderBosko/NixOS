#!/usr/bin/env bash
# Self-contained test for push.sh: default-branch behavior (plain push, protected-branch PR
# fallback) and the feature-branch PR flow (create / reuse / retarget upstream / gh failures).
# Uses a throwaway bare "origin" and a stub `gh` on PATH — no network, no real GitHub.
set -euo pipefail

PUSH="$(cd "$(dirname "$0")" && pwd)/push.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_GLOBAL=/dev/null

# Stub gh. Logs every call to $GH_LOG. `pr list --head X` answers from $GH_STATE/open.<X with / -> _>.
# `pr create` records --title/--body-file/--base/--head under $GH_STATE and prints a PR URL.
# GH_LIST_FAIL=1 / GH_CREATE_FAIL=1 make the respective call fail with a message on stderr.
mkdir "$T/bin" "$T/state"
export GH_LOG="$T/gh.log" GH_STATE="$T/state"
cat >"$T/bin/gh" <<'GH'
#!/usr/bin/env bash
echo "$*" >>"$GH_LOG"
sub="$1 $2"
head="" title="" bodyfile="" base=""
while [ $# -gt 0 ]; do
  case "$1" in
    --head) head="$2" ;;
    --title) title="$2" ;;
    --body-file) bodyfile="$2" ;;
    --base) base="$2" ;;
  esac
  shift
done
case "$sub" in
  "pr list")
    [ "${GH_LIST_FAIL:-}" = 1 ] && { echo "gh: HTTP 401: Bad credentials" >&2; exit 1; }
    f="$GH_STATE/open.${head//\//_}"
    [ -f "$f" ] && cat "$f"
    exit 0
    ;;
  "pr create")
    [ "${GH_CREATE_FAIL:-}" = 1 ] && { echo "gh: GraphQL: boom" >&2; exit 1; }
    printf '%s' "$title" >"$GH_STATE/title.last"
    printf '%s' "$base" >"$GH_STATE/base.last"
    [ -n "$bodyfile" ] && cp "$bodyfile" "$GH_STATE/body.last"
    echo "https://github.com/fake/repo/pull/42"
    exit 0
    ;;
esac
echo "stub gh: unexpected call: $sub" >&2
exit 1
GH
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"

fail() { echo "FAIL: $*" >&2; exit 1; }
reset_gh() { : >"$GH_LOG"; rm -f "$GH_STATE"/*; }
# run <push.sh args...>: sets OUT (stdout+stderr) and RC without tripping set -e.
run() { set +e; OUT="$("$PUSH" "$@" 2>&1)"; RC=$?; set -e; }
has() { grep -qF -- "$1" <<<"$OUT" || { echo "$OUT"; fail "output missing: $1"; }; }
creates() { grep -c '^pr create' "$GH_LOG" || true; }
remote_sha() { git --git-dir="$T/$1.git" rev-parse "refs/heads/$2"; }

setup() { # $1 = name, $2 = protect(yes/no)
  git init -q --bare -b main "$T/$1.git"
  if [ "$2" = yes ]; then
    cat >"$T/$1.git/hooks/pre-receive" <<'HOOK'
#!/usr/bin/env bash
while read -r _ _ ref; do
  if [ "$ref" = refs/heads/main ]; then
    echo "remote: error: GH013: Repository rule violations found" >&2
    exit 1
  fi
done
HOOK
    chmod +x "$T/$1.git/hooks/pre-receive"
  fi
  git clone -q "$T/$1.git" "$T/$1" 2>/dev/null
  git -C "$T/$1" switch -q -c main 2>/dev/null || true
  git -C "$T/$1" commit -q --allow-empty -m "init"
  git -C "$T/$1" push -q origin main 2>/dev/null || true
}

# Fresh unprotected repo with origin/HEAD set; cd into it.
newrepo() {
  setup "$1" no
  cd "$T/$1"
  git remote set-head origin main >/dev/null
  reset_gh
}

commit() { # $1 = file, $2... = message lines (first is the subject)
  local f="$1"
  shift
  echo "$f" >"$f"
  git add "$f"
  git commit -q -m "$1" ${2:+-m "$2"}
}

# --- protected default branch: PR fallback (unchanged) ---
setup prot no
cp "$T/prot.git/hooks/pre-receive.sample" /dev/null 2>/dev/null || true
cat >"$T/prot.git/hooks/pre-receive" <<'HOOK'
#!/usr/bin/env bash
while read -r _ _ ref; do
  if [ "$ref" = refs/heads/main ]; then
    echo "remote: error: GH013: Repository rule violations found" >&2
    exit 1
  fi
done
HOOK
chmod +x "$T/prot.git/hooks/pre-receive"
cd "$T/prot"
git fetch -q origin
git remote set-head origin main >/dev/null
reset_gh
echo x >f && git add f && git commit -q -m "Add Feature: X/Y!"
OUT="$("$PUSH" execute 2>&1)" || { echo "$OUT"; fail "execute exited non-zero"; }
echo "$OUT"
grep -q "https://github.com/fake/repo/pull/42" <<<"$OUT" || fail "PR URL missing"
git --git-dir="$T/prot.git" branch --list 'pr/*' | grep -q 'pr/add-feature-x-y' || fail "no pr/* branch on remote"
[ "$(git rev-parse main)" = "$(git rev-parse origin/main)" ] || fail "local main != origin/main"
case "$(git branch --show-current)" in pr/*) ;; *) fail "not on pr/* branch" ;; esac
grep -q '^pr create --fill --base main' "$GH_LOG" || fail "fallback should use gh pr create --fill"
[ "$(grep -c '^pr list' "$GH_LOG" || true)" -eq 0 ] || fail "fallback path must not look up PRs"
echo "ok: protected default branch falls back to pr/* + PR"

# --- default branch, unprotected: plain push, gh never touched ---
setup open no
cd "$T/open"
git remote set-head origin main >/dev/null
reset_gh
echo y >g && git add g && git commit -q -m "plain"
run status
has "branch: main"
grep -q 'pull request' <<<"$OUT" && { echo "$OUT"; fail "status on default branch must not print a PR section"; }
run execute
[ "$RC" -eq 0 ] || { echo "$OUT"; fail "plain execute failed"; }
[ "$(git rev-parse HEAD)" = "$(remote_sha open main)" ] || fail "main not pushed directly"
[ -z "$(git --git-dir="$T/open.git" branch --list 'pr/*')" ] || fail "unexpected pr/* branch"
[ ! -s "$GH_LOG" ] || { cat "$GH_LOG"; fail "default branch must never call gh"; }
run execute
has "nothing to push"
[ ! -s "$GH_LOG" ] || fail "nothing-to-push on default must not call gh"
echo "ok: default branch unchanged (no gh calls)"

# --- feature branch, no PR: push, then open it against main ---
newrepo f1
git checkout -q -b feat/one --no-track origin/main
commit one.txt "feat(x): add one" "Because one is the loneliest number.

Co-Authored-By: Someone <s@example.com>"
run status
[ "$RC" -eq 0 ] || { echo "$OUT"; fail "status failed on feature branch"; }
has "--- pull request (base: main) ---"
has "no open PR"
has "title: feat(x): add one"
run execute
[ "$RC" -eq 0 ] || { echo "$OUT"; fail "feature execute failed"; }
has "opened PR for feat/one (base main): https://github.com/fake/repo/pull/42"
[ "$(git rev-parse HEAD)" = "$(remote_sha f1 feat/one)" ] || fail "feat/one not pushed"
[ "$(creates)" -eq 1 ] || { cat "$GH_LOG"; fail "expected exactly one pr create"; }
grep -q '^pr create --base main --head feat/one --title feat(x): add one --body-file ' "$GH_LOG" || { cat "$GH_LOG"; fail "pr create args wrong"; }
[ "$(cat "$GH_STATE/title.last")" = "feat(x): add one" ] || fail "title wrong"
B="$GH_STATE/body.last"
grep -qx '## Summary' "$B" || fail "body: no Summary"
grep -qx -- '- feat(x): add one' "$B" || fail "body: no commit bullet"
grep -qF 'Because one is the loneliest number.' "$B" || fail "body: single-commit body missing"
grep -qi 'co-authored-by' "$B" && fail "body: trailer leaked"
grep -qx '## Verification' "$B" || fail "body: no Verification"
grep -qF 'one.txt' "$B" || fail "body: diff stat missing"
[ "$(tail -n1 "$B")" = '🤖 Generated with [Claude Code](https://claude.com/claude-code)' ] || fail "body: footer not last line"
echo "ok: feature branch without PR -> pushed + PR opened (--base main)"

# --- same branch again: PR now open -> just push + print URL, no duplicate ---
echo "https://github.com/fake/repo/pull/42" >"$GH_STATE/open.feat_one"
: >"$GH_LOG"
commit two.txt "feat(x): add two"
run status
has "open PR: https://github.com/fake/repo/pull/42"
run execute
[ "$RC" -eq 0 ] || { echo "$OUT"; fail "execute with open PR failed"; }
has "PR already open for feat/one: https://github.com/fake/repo/pull/42"
[ "$(git rev-parse HEAD)" = "$(remote_sha f1 feat/one)" ] || fail "second commit not pushed"
[ "$(creates)" -eq 0 ] || fail "duplicate PR created"
echo "ok: existing PR -> push only, no duplicate"

# --- multi-commit branch: title is the oldest subject, every commit bulleted ---
newrepo f2
git checkout -q -b feat/multi --no-track origin/main
commit a.txt "feat(a): first"
commit b.txt "fix(a): second"
run execute
[ "$RC" -eq 0 ] || { echo "$OUT"; fail "multi execute failed"; }
[ "$(cat "$GH_STATE/title.last")" = "feat(a): first" ] || fail "multi: title should be oldest subject"
grep -qx -- '- feat(a): first' "$GH_STATE/body.last" || fail "multi: bullet 1"
grep -qx -- '- fix(a): second' "$GH_STATE/body.last" || fail "multi: bullet 2"
echo "ok: multi-commit draft"

# --- branch cut from origin/main WITH tracking (the known trap) ---
newrepo f3
git checkout -q -b feat/tracks origin/main
[ "$(git rev-parse --abbrev-ref '@{u}')" = "origin/main" ] || fail "setup: expected upstream origin/main"
commit t.txt "feat(t): tracked branch"
MAIN_BEFORE="$(remote_sha f3 main)"
run status
[ "$RC" -eq 0 ] || { echo "$OUT"; fail "status crashed on a branch tracking main"; }
has "tracks origin/main, not origin/feat/tracks"
has "feat(t): tracked branch"
run execute
[ "$RC" -eq 0 ] || { echo "$OUT"; fail "execute failed on a branch tracking main"; }
has "pushing with -u origin feat/tracks"
[ "$(git rev-parse HEAD)" = "$(remote_sha f3 feat/tracks)" ] || fail "tracking branch never reached origin"
[ "$(remote_sha f3 main)" = "$MAIN_BEFORE" ] || fail "origin/main moved!"
[ "$(git rev-parse --abbrev-ref '@{u}')" = "origin/feat/tracks" ] || fail "upstream not retargeted"
[ "$(creates)" -eq 1 ] || fail "PR not opened for tracking branch"
echo "ok: branch tracking main is pushed with -u origin <branch>, main untouched, PR opened"

# --- gh pr create fails: clear error, nonzero, branch still pushed; retry opens the PR ---
newrepo f4
git checkout -q -b feat/boom --no-track origin/main
commit boom.txt "feat(b): boom"
GH_CREATE_FAIL=1 run execute
[ "$RC" -eq 2 ] || { echo "$OUT"; fail "expected exit 2 when gh pr create fails, got $RC"; }
has "feat/boom is pushed, but 'gh pr create --base main' failed"
has "gh: GraphQL: boom"
[ "$(git rev-parse HEAD)" = "$(remote_sha f4 feat/boom)" ] || fail "branch should be pushed despite gh failure"
run execute
[ "$RC" -eq 0 ] || { echo "$OUT"; fail "retry should succeed"; }
has "nothing to push"
has "opened PR for feat/boom (base main)"
echo "ok: gh pr create failure -> exit 2 with message; retry opens the PR without re-pushing"

# --- PR lookup fails (not authenticated) ---
newrepo f5
git checkout -q -b feat/auth --no-track origin/main
commit auth.txt "feat(c): auth"
GH_LIST_FAIL=1 run execute
[ "$RC" -eq 2 ] || { echo "$OUT"; fail "expected exit 2 when gh pr list fails, got $RC"; }
has "feat/auth is pushed, but the PR lookup failed"
has "Bad credentials"
[ "$(creates)" -eq 0 ] || fail "must not create a PR when the lookup failed"
GH_LIST_FAIL=1 run status
[ "$RC" -eq 0 ] || fail "status must stay exit 0 when gh fails"
has "could not check for an open PR"
echo "ok: gh lookup failure -> exit 2 (execute), soft note (status)"

# --- gh missing from PATH ---
newrepo f6
git checkout -q -b feat/nogh --no-track origin/main
commit nogh.txt "feat(d): no gh"
mkdir "$T/nogh"
for c in bash env git sh tr cut sed grep mktemp rm cat head tail wc; do
  p="$(command -v "$c" 2>/dev/null || true)"
  case "$p" in /*) ln -sf "$p" "$T/nogh/$c" ;; esac
done
set +e
OUT="$(PATH="$T/nogh" "$PUSH" execute 2>&1)"
RC=$?
set -e
[ "$RC" -eq 2 ] || { echo "$OUT"; fail "expected exit 2 without gh, got $RC"; }
has "gh not found on PATH"
[ "$(git rev-parse HEAD)" = "$(remote_sha f6 feat/nogh)" ] || fail "branch should still be pushed without gh"
echo "ok: gh missing -> exit 2 with message, branch still pushed"

# --- --no-pr: push only ---
newrepo f7
git checkout -q -b feat/nopr --no-track origin/main
commit nopr.txt "feat(e): no pr"
run execute --no-pr
[ "$RC" -eq 0 ] || { echo "$OUT"; fail "--no-pr execute failed"; }
[ "$(git rev-parse HEAD)" = "$(remote_sha f7 feat/nopr)" ] || fail "--no-pr: not pushed"
[ ! -s "$GH_LOG" ] || fail "--no-pr must not call gh"
echo "ok: --no-pr"

# --- --base / --title / --body-file overrides (stacked child) ---
newrepo f8
git checkout -q -b feat/parent --no-track origin/main
commit parent.txt "feat(p): parent"
git push -q -u origin feat/parent 2>/dev/null
git fetch -q origin
git checkout -q -b feat/child --no-track origin/feat/parent
commit child.txt "feat(p): child"
printf 'custom body\n' >"$T/custom-body.md"
reset_gh
run execute --base feat/parent --title "Custom title" --body-file "$T/custom-body.md"
[ "$RC" -eq 0 ] || { echo "$OUT"; fail "override execute failed"; }
has "opened PR for feat/child (base feat/parent)"
[ "$(cat "$GH_STATE/base.last")" = "feat/parent" ] || fail "--base ignored"
[ "$(cat "$GH_STATE/title.last")" = "Custom title" ] || fail "--title ignored"
[ "$(cat "$GH_STATE/body.last")" = "custom body" ] || fail "--body-file ignored"
run execute --base nope
[ "$RC" -eq 1 ] || { echo "$OUT"; fail "unknown --base should exit 1"; }
has "PR base origin/nope not found"
echo "ok: --base / --title / --body-file"

# --- feature branch with nothing ahead of main: nothing pushed, no PR ---
newrepo f9
git checkout -q -b feat/empty --no-track origin/main
run execute
[ "$RC" -eq 0 ] || { echo "$OUT"; fail "empty branch execute failed"; }
has "nothing to push"
[ "$(creates)" -eq 0 ] || fail "PR opened for an empty branch"
echo "ok: empty feature branch -> no push, no PR"

echo "PASS"
