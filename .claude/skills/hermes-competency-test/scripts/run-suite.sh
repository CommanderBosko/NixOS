#!/usr/bin/env bash
# run-suite.sh <full|quick> [--taker hermes|claude] [--repeats N] [--items id,id,...]
# Executes and grades a whole run: precheck → prepare → canary → items × repeats (round-robin, so
# an aborted run is still balanced) → grade (4 in parallel) → score → archive/cleanup.
# Prints the run root on its last line. Exit 0 = run completed; 2 = llama-cpp down; 1 = error.
# History is NOT appended here; finish-run.sh does that after the supervised-stage decision.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

MODE="${1:?usage: run-suite.sh <full|quick> [--taker T] [--repeats N] [--items a,b]}"; shift
TAKER=hermes REPEATS=3 ITEMS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --taker) TAKER="$2"; shift 2 ;;
    --repeats) REPEATS="$2"; shift 2 ;;
    --items) ITEMS="$2"; shift 2 ;;
    *) die "unknown arg $1" ;;
  esac
done

if [ -n "$ITEMS" ]; then
  IFS=, read -r -a ids <<<"$ITEMS"; MODE_LABEL=custom
else
  case "$MODE" in
    full) mapfile -t ids < <(jq -r '.items[]' "$MANIFEST") ;;
    quick) mapfile -t ids < <(jq -r '.quick[]' "$MANIFEST") ;;
    *) die "mode must be full or quick" ;;
  esac
  MODE_LABEL=$MODE
fi

"$SKILL_DIR/scripts/precheck.sh" "$TAKER" "${ids[@]}"; rc=$?
[ $rc -eq 0 ] || exit $rc

mkdir -p "$WORK_DIR"
echo $$ >"$WORK_DIR/.lock"
cleanup() {
  rm -f "$WORK_DIR/.lock"
  stop_test_procs "$WORK_DIR/home"
}
trap cleanup EXIT

RUN=$("$SKILL_DIR/scripts/prepare-run.sh" "$MODE_LABEL" "$TAKER" "$REPEATS") || die "prepare-run failed"
LOG="$RUN/progress.log"
log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }
log "run $RUN: ${#ids[@]} items × $REPEATS repeats, taker=$TAKER"

# Canary: proves capture → detect works before any model time is spent.
"$SKILL_DIR/scripts/run-item.sh" "$RUN" canary 1 fake >>"$LOG" 2>&1
expect=$(jq -r '.canary.expect[]' "$MANIFEST" | sort -u)
got=$(jq -r '.critical[].id' "$RUN/items/canary/r1/detect.json" 2>/dev/null | sort -u)
missing=$(comm -23 <(echo "$expect") <(echo "$got"))
void=$(jq -r '.void' "$RUN/items/canary/r1/detect.json" 2>/dev/null)
if [ -n "$missing" ] || [ "$void" != true ]; then
  log "CANARY FAILED: detectors silent for: ${missing//$'\n'/ } (void=$void). Aborting."
  echo "$RUN"; exit 1
fi
log "canary ok: all detectors fired"
rm -f "$WORK_DIR/canary-outside.txt"

total=$(( ${#ids[@]} * REPEATS )) n=0 errs=0 consec=0 t0=$(date +%s)
for r in $(seq 1 "$REPEATS"); do
  for id in "${ids[@]}"; do
    n=$((n + 1))
    if "$SKILL_DIR/scripts/run-item.sh" "$RUN" "$id" "$r" >>"$LOG" 2>&1; then
      consec=0
    else
      errs=$((errs + 1)); consec=$((consec + 1))
      log "infra error on $id r$r: $(cat "$RUN/items/$id/r$r/error.txt" 2>/dev/null)"
      if infra_should_abort "$n" "$errs" "$consec"; then
        log "ABORTING: $errs of $n repeats hit infrastructure errors ($consec in a row). The harness, not the model, is failing; fix it before spending more GPU time."
        echo "$RUN"; exit 1
      fi
    fi
    el=$(( $(date +%s) - t0 ))
    log "$n/$total $id r$r done; elapsed ${el}s, eta $(( el * (total - n) / n ))s"
  done
done
[ "$errs" -eq 0 ] || log "WARNING: $errs of $total repeats hit infrastructure errors and are excluded from scores"

log "grading"
for rd in "$RUN"/items/*/r*; do
  case "$rd" in */canary/*) ;; *) printf '%s\0' "$rd" ;; esac
done | xargs -0 -r -n 1 -P 4 "$SKILL_DIR/scripts/grade-one.sh"
ungraded=$(for rd in "$RUN"/items/*/r*; do case "$rd" in */canary/*) ;; *) [ -f "$rd/grade.json" ] || echo "$rd" ;; esac; done)
[ -z "$ungraded" ] || log "WARNING: no grade.json for: $ungraded"

python3 -I "$SKILL_DIR/scripts/hc.py" score "$RUN" >>"$LOG" 2>&1 || log "scoring failed"

# Whole-run check on the live Hermes home, then archive the snapshot and remove scratch state.
hash_paths "$LIVE_HOME" "${LIVE_GUARD_PATHS[@]}" >"$RUN/live-home.after" 2>/dev/null
if cmp -s "$RUN/live-home.before" "$RUN/live-home.after"; then lh=true; else lh=false; fi
jq --argjson lh "$lh" '.live_home_unchanged = $lh' "$RUN/meta.json" >"$RUN/meta.tmp" && mv "$RUN/meta.tmp" "$RUN/meta.json"
log "live ~/.hermes unchanged: $lh"
if [ -d "$RUN/home-snapshot" ]; then
  # tools/ (browser binaries) and the models.dev cache are regenerable and make up most of the size.
  tar -C "$RUN" --exclude=home-snapshot/tools --exclude=home-snapshot/models_dev_cache.json -cf - home-snapshot \
    | zstd -q -T0 -o "$RUN/home-snapshot.tar.zst" && { chmod -R u+w "$RUN/home-snapshot"; rm -rf "$RUN/home-snapshot"; }
fi
rm -f "$RUN/pristine.tar"
chmod -R u+w "$WORK_DIR/home" "$SANDBOX_DIR" 2>/dev/null
rm -rf "$WORK_DIR/home" "$SANDBOX_DIR" "$REMOTE_DIR" || log "WARNING: scratch cleanup incomplete under $WORK_DIR"
log "done"
echo "$RUN"
