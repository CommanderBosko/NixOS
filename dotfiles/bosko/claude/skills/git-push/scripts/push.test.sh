#!/usr/bin/env bash
# Self-contained test for push.sh execute: protected-branch PR fallback and the plain path.
set -euo pipefail

PUSH="$(cd "$(dirname "$0")" && pwd)/push.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_GLOBAL=/dev/null

mkdir "$T/bin"
cat >"$T/bin/gh" <<'GH'
#!/usr/bin/env bash
echo "https://github.com/fake/repo/pull/42"
GH
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"

fail() { echo "FAIL: $*" >&2; exit 1; }

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

# --- protected: bypass the hook for the seed commit, then protect ---
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
echo x >f && git add f && git commit -q -m "Add Feature: X/Y!"
OUT="$("$PUSH" execute 2>&1)" || { echo "$OUT"; fail "execute exited non-zero"; }
echo "$OUT"
grep -q "https://github.com/fake/repo/pull/42" <<<"$OUT" || fail "PR URL missing"
git --git-dir="$T/prot.git" branch --list 'pr/*' | grep -q 'pr/add-feature-x-y' || fail "no pr/* branch on remote"
[ "$(git rev-parse main)" = "$(git rev-parse origin/main)" ] || fail "local main != origin/main"
case "$(git branch --show-current)" in pr/*) ;; *) fail "not on pr/* branch" ;; esac

# --- unprotected: plain push of main ---
setup open no
cd "$T/open"
git remote set-head origin main >/dev/null
echo y >g && git add g && git commit -q -m "plain"
"$PUSH" execute >/dev/null 2>&1 || fail "plain execute failed"
[ "$(git rev-parse HEAD)" = "$(git --git-dir="$T/open.git" rev-parse main)" ] || fail "main not pushed directly"
[ -z "$(git --git-dir="$T/open.git" branch --list 'pr/*')" ] || fail "unexpected pr/* branch"

echo "PASS"
