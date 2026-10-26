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

# test_home_pids <home>: PIDs of Hermes processes (a chat, the on-demand gateway, its MCP supervisor)
# whose environment has HERMES_HOME=<home>.
test_home_pids() {
  local pid
  for pid in $(pgrep -u "$(id -u)" -f hermes 2>/dev/null); do
    tr '\0' '\n' 2>/dev/null <"/proc/$pid/environ" | grep -qx "HERMES_HOME=$1" && echo "$pid"
  done
}

# stop_test_procs <home>: SIGTERM those processes, wait for them to exit, SIGKILL stragglers, wait
# again. Returns 1 if any survive. Waiting is the point: the gateway drains for a few seconds after
# SIGTERM, and a `hermes chat` started meanwhile exits 1 within ~1.5 s ("A gateway is already
# running" / "Gateway draining"). That cost 42 of 90 repeats in the first full run, graded as 0.
stop_test_procs() {
  local home="$1" grace="${HC_STOP_GRACE_S:-30}" pid i
  [ -n "$(test_home_pids "$home")" ] || return 0
  for pid in $(test_home_pids "$home"); do kill "$pid" 2>/dev/null; done
  for ((i = 0; i < grace * 2; i++)); do
    [ -z "$(test_home_pids "$home")" ] && return 0
    sleep 0.5
  done
  for pid in $(test_home_pids "$home"); do kill -KILL "$pid" 2>/dev/null; done
  for ((i = 0; i < 10; i++)); do
    [ -z "$(test_home_pids "$home")" ] && return 0
    sleep 0.5
  done
  return 1
}

# gateway_start_failed <stderr-file>: true if a hermes chat died because its gateway wouldn't start.
gateway_start_failed() {
  grep -qE 'Gateway could not start|Gateway draining|gateway is already running' "$1" 2>/dev/null
}

# startup_failed <rc> <seconds> <stderr-file> <stream-file>: true if a hermes chat never got going, so
# nothing ran and the repeat can simply be tried again. Either its gateway wouldn't start (known
# messages), or, whatever the message, it exited non-zero within HC_FAST_CRASH_S (10) seconds before a
# single tool call: a model can't fail a task that fast, so that's the harness. Timeouts don't count.
startup_failed() {
  local rc="$1" secs="$2" err="$3" stream="$4"
  { [ "$rc" -ne 0 ] && [ "$rc" -ne 124 ] && [ "$rc" -ne 137 ]; } || return 1
  gateway_start_failed "$err" && return 0
  awk -v s="$secs" -v t="${HC_FAST_CRASH_S:-10}" 'BEGIN { exit !(s < t) }' || return 1
  ! grep -qE '"type": *"tool_use"' "$stream" 2>/dev/null
}

# startup_failure_reason <stderr-file>: one line saying why, for logs and error.txt.
startup_failure_reason() {
  local line
  line=$(grep -m1 -E '^Error' "$1" 2>/dev/null) || line=$(head -n 1 "$1" 2>/dev/null)
  echo "${line:-no output}"
}

# taker_crashed <rc> <stream-file>: true if a calibration `claude -p` died instead of finishing, so the
# repeat measured nothing: a non-zero exit that isn't the timeout (124/137, which is the model being slow
# and is scored), or a clean exit that wrote no stream at all. Such a repeat is an infrastructure error;
# grading its empty output would record a genuine 0 for Sonnet.
taker_crashed() {
  local rc="$1" stream="$2"
  if [ "$rc" -ne 0 ]; then
    [ "$rc" -ne 124 ] && [ "$rc" -ne 137 ]
    return
  fi
  ! grep -q '^{' "$stream" 2>/dev/null
}

# crash_reason <stderr-file> <stream-file>: one line saying why a taker died. Falls back to the stream's
# error result event, which is where `claude -p --output-format stream-json` reports API/credit errors.
crash_reason() {
  local r
  r=$(startup_failure_reason "$1")
  if [ "$r" = "no output" ]; then
    r=$(jq -r 'select(.type == "result") | .result // empty' "$2" 2>/dev/null | head -n 1)
    r="${r:-no output}"
  fi
  echo "${r:0:200}"
}

# infra_should_abort <attempted> <errors> <consecutive-errors>: true when the harness, not the model,
# is failing (3 infrastructure errors in a row, or at least 20% of 10+ attempts).
infra_should_abort() {
  [ "$3" -ge 3 ] || { [ "$1" -ge 10 ] && [ $(($2 * 5)) -ge "$1" ]; }
}
