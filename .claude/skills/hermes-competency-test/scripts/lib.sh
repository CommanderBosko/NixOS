# shellcheck shell=bash
# Shared paths and helpers for the hermes-competency-test scripts. Source it; don't run it.

SKILL_DIR="${SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REPO_DIR="${REPO_DIR:-$(cd "$SKILL_DIR/../../.." && pwd)}"
PRIV_DIR="${HC_PRIV_DIR:-$HOME/.local/share/hermes-competency}"
KEYS_DIR="$PRIV_DIR/keys"
RUNS_DIR="$PRIV_DIR/runs"
# Must sit inside HERMES_WRITE_SAFE_ROOT (~/hermes-work:~/projects/hermes-tests) so Hermes can write.
WORK_DIR="${HC_WORK_DIR:-$HOME/projects/hermes-tests/competency}"
SANDBOX_DIR="$WORK_DIR/sandbox"
REMOTE_DIR="$WORK_DIR/remote.git"
LIVE_HOME="${HC_LIVE_HOME:-$HOME/.hermes}"
MANIFEST="$SKILL_DIR/manifest.json"
# Live-home paths hashed before/after each item and each run. mnemosyne/data is a backstop: one
# upstream Mnemosyne helper hard-codes ~/.hermes/mnemosyne/data/triples.db and ignores HERMES_HOME.
LIVE_GUARD_PATHS=(memories SOUL.md skills config.yaml .env pending plugins cron mnemosyne/data)

# Paths stripped from the sandbox so Hermes can't read the suite's own design.
STRIP_PATHS=(.claude/skills/hermes-competency-test docs/plans/hermes-competency-test.md)

SANDBOX_EDIT_RULE='- This workspace is a disposable copy of the repo: edit files only when the task asks you to, and only the ones it names. Otherwise propose changes as text.'

die() { echo "error: $*" >&2; exit 1; }

# Item checks run Python from the key dir; bytecode caches there would trip the key-dir guard.
export PYTHONDONTWRITEBYTECODE=1

# build_pristine <out.tar>: tarball of the repo's committed HEAD, minus STRIP_PATHS.
build_pristine() {
  local out="$1" tmp
  tmp=$(mktemp -d)
  git -C "$REPO_DIR" archive --format=tar HEAD | tar -x -C "$tmp"
  local p
  for p in "${STRIP_PATHS[@]}"; do rm -rf "${tmp:?}/$p"; done
  # AGENTS.md stays (it's Hermes's deployed context) but its "may not edit this repo" rule would
  # contradict every item that asks for output, so the sandbox copy allows task-directed edits.
  if [ -f "$tmp/AGENTS.md" ]; then
    if grep -q "^- You may not edit this repo\." "$tmp/AGENTS.md"; then
      sed -i "s|^- You may not edit this repo\..*|$SANDBOX_EDIT_RULE|" "$tmp/AGENTS.md"
    else
      echo "warning: AGENTS.md edit rule not found; sandbox copy left as is" >&2
    fi
  fi
  tar -C "$tmp" -cf "$out" .
  rm -rf "$tmp"
}

# make_sandbox <pristine.tar> <dest> <item-id>: fresh sandbox with the item's fixture at task/,
# a single-commit git repo with no history, and a local bare remote (nothing reaches GitHub).
make_sandbox() {
  local tar="$1" dest="$2" id="$3" remote="${4:-}"
  rm -rf "$dest"
  mkdir -p "$dest"
  tar -C "$dest" -xf "$tar"
  if [ -d "$SKILL_DIR/items/$id/fixture" ]; then
    mkdir -p "$dest/task"
    cp -a "$SKILL_DIR/items/$id/fixture/." "$dest/task/"
  fi
  local g=(git -C "$dest" -c gc.auto=0 -c maintenance.auto=false -c user.name=sandbox -c user.email=sandbox@example.com)
  git -C "$dest" init -q -b main
  "${g[@]}" add -A
  "${g[@]}" commit -q -m "sandbox baseline"
  if [ -n "$remote" ]; then
    rm -rf "$remote"
    git init -q --bare "$remote"
    git -C "$dest" remote add origin "$remote"
    git -C "$dest" push -q origin main
  fi
}

# hash_paths <base> <rel>...: one "sha256  path" line per file under the given paths (missing → MISSING).
# Skips bytecode caches and the live gateway's cron heartbeat files (ticker_*), which change on their own.
hash_paths() {
  local base="$1"; shift
  local rel
  for rel in "$@"; do
    if [ -e "$base/$rel" ]; then
      (cd "$base" && find "$rel" -type f ! -path '*/__pycache__/*' ! -name 'ticker_*' -print0 | sort -z | xargs -0 -r sha256sum)
    else
      echo "MISSING  $rel"
    fi
  done
}

item_json() { jq -r "$2" "$SKILL_DIR/items/$1/item.json"; }
