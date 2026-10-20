#!/usr/bin/env bash
# prepare-run.sh <full|quick|custom> <hermes|claude|fake> [repeats]
# Creates a run root under the private runs dir and prints its path. For Hermes runs it snapshots the
# live HERMES_HOME (minus auth.json, caches, logs, backups and runtime files), adds the test-only
# deny globs and pins approvals.single_query_mode to deny in the snapshot's config, and records the
# hashes/versions every report carries. Also builds the stripped repo tarball for sandboxes.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

MODE="${1:?mode}" TAKER="${2:?taker}" REPEATS="${3:-3}"
ID="$(date +%Y%m%d-%H%M%S)-$MODE-$TAKER"
RUN="$RUNS_DIR/$ID"
mkdir -p "$RUN/items" "$WORK_DIR"
cp "$MANIFEST" "$RUN/manifest.json"

# Test-only denies layered on the live list (globs match the start of the command unless they
# begin with *; the detectors in hc.py catch the mid-command cases).
TEST_DENIES=("ssh*" "scp*" "sftp*" "git push*" "gh *" "*api.github.com*" "curl*github.com*" "wget*github.com*"
             "nmcli con* up*" "nmcli con* down*" "nmcli con* mod*" "ip link set*" "ip route add*"
             "ip route del*" "ip addr add*" "ip addr del*" "resolvectl dns*" "resolvectl domain*"
             "tailscale up*" "tailscale down*" "tailscale set*" "tailscale logout*"
             "systemctl restart*" "systemctl stop*" "systemctl start*" "msmtp*" "sendmail*" "himalaya*send*")

snapshot_home() {
  local snap="$RUN/home-snapshot"
  # u+w: some skills arrive read-only (store-sourced); a read-only copy can't be reset or removed.
  rsync -a --chmod=u+w --exclude=auth.json --exclude=auth.lock --exclude=backups/ --exclude=cache/ \
    --exclude=.curator_backups/ --exclude=logs/ --exclude='gateway*' --exclude=gateway_state.json \
    --exclude=runtime/ --exclude=state/ --exclude=audio_cache/ --exclude=image_cache/ \
    --exclude=terminal-sessions/ --exclude='state.db*' --exclude='kanban.db*' --exclude='projects.db*' \
    --exclude=.hermes_history "$LIVE_HOME/" "$snap/"
  # SQLite files via the backup API so a running live gateway can't hand us a torn copy.
  python3 -I - "$LIVE_HOME" "$snap" <<'EOF'
import sqlite3, sys, pathlib
src, dst = map(pathlib.Path, sys.argv[1:3])
for name in ("state.db", "kanban.db", "projects.db"):
    if (src / name).exists():
        s = sqlite3.connect(f"file:{src / name}?mode=ro", uri=True)
        d = sqlite3.connect(dst / name)
        s.backup(d); d.close(); s.close()
EOF
  chmod u+w "$snap/config.yaml"
  python3 -I - "$snap/config.yaml" "${TEST_DENIES[@]}" <<'EOF'
import sys, re
path, denies = sys.argv[1], sys.argv[2:]
s = open(path).read()
m = re.search(r"^approvals:\n((?:  .*\n)*)", s, re.M)
if not m:
    s += "approvals:\n  mode: manual\n  deny: []\n"
    m = re.search(r"^approvals:\n((?:  .*\n)*)", s, re.M)
block = m.group(1)
block = re.sub(r"^  single_query_mode:.*\n", "", block, flags=re.M)
extra = "".join(f"  - '{d}'\n" for d in denies)
if re.search(r"^  deny: \[\]\n", block, re.M):
    block = re.sub(r"^  deny: \[\]\n", "  deny:\n" + extra, block, flags=re.M)
elif re.search(r"^  deny:\n", block, re.M):
    block = re.sub(r"^  deny:\n", "  deny:\n" + extra, block, count=1, flags=re.M)
else:
    block += "  deny:\n" + extra
block = "  single_query_mode: deny\n" + block
s = s[: m.start(1)] + block + s[m.end(1):]
open(path, "w").write(s)
EOF
  grep -q "single_query_mode: deny" "$snap/config.yaml" || die "config patch failed"
}

sha() { if [ -e "$1" ]; then (cd "$(dirname "$1")" && find "$(basename "$1")" -type f -print0 | sort -z | xargs -0 -r sha256sum | sha256sum | cut -c1-16); else echo none; fi; }

HV="n/a" MODEL="n/a" CFG="n/a" SOUL="n/a" MEM="n/a"
if [ "$TAKER" = hermes ]; then
  snapshot_home
  HV=$(hermes --version 2>/dev/null | head -1 | sed 's/^Hermes Agent //')
  MODEL=$(curl -fsS --max-time 5 "${HC_LLAMA_URL:-http://127.0.0.1:8080}/v1/models" 2>/dev/null | jq -r '.data[0].id // empty' || true)
  MODEL="${MODEL:-$(grep -m1 '^  default:' "$LIVE_HOME/config.yaml" | awk '{print $2}')}"
  MODEL=$(basename "$MODEL")
  CFG=$(sha "$LIVE_HOME/config.yaml"); SOUL=$(sha "$LIVE_HOME/SOUL.md")
  MEM=$( (sha "$LIVE_HOME/memories"; sha "$LIVE_HOME/mnemosyne") | sha256sum | cut -c1-16)
elif [ "$TAKER" = claude ]; then
  MODEL="claude ${HC_CALIBRATION_MODEL:-sonnet}"
fi

build_pristine "$RUN/pristine.tar"

jq -n --arg id "$ID" --arg mode "$MODE" --arg taker "$TAKER" --argjson repeats "$REPEATS" \
  --arg date "$(date -Iseconds)" --arg hv "$HV" --arg model "$MODEL" --arg cfg "$CFG" --arg soul "$SOUL" \
  --arg mem "$MEM" --arg manifest "$RUN/manifest.json" --arg cal "${HC_CALIBRATION_MODEL:-sonnet}" \
  --arg suite "$(jq -r .version "$MANIFEST")" --arg head "$(git -C "$REPO_DIR" rev-parse --short HEAD)" \
  '{run_id:$id, mode:$mode, taker:$taker, repeats:$repeats, date:$date, hermes_version:$hv, model:$model,
    suite_version:$suite, repo_head:$head, manifest_path:$manifest, calibration_model:$cal,
    supervised_net:"not_offered", hashes:{config:$cfg, soul:$soul, memory:$mem}}' >"$RUN/meta.json"

# Whole-run guard on the live home: compared again by finish-run.sh.
hash_paths "$LIVE_HOME" "${LIVE_GUARD_PATHS[@]}" >"$RUN/live-home.before" 2>/dev/null
echo "$RUN"
