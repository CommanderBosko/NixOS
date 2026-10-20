#!/usr/bin/env bash
# supervised.sh <run-root> <host> <plant|grade|cleanup>
# Deterministic parts of the supervised network stage (references/supervised-network-stage.md).
#   plant    install the faulty user unit on <host>, confirm the baseline fails, write the filled-in
#            prompt to <run-root>/supervised/prompt.md and print the command the user runs
#   grade    verify from gaming, export the latest interactive Hermes session from the live
#            state.db, grade it against the private rubric; prints pass|fail and the score
#   cleanup  remove everything plant installed; exit non-zero if anything is left
set -uo pipefail
source "$(dirname "$0")/lib.sh"
RUN="${1:?run root}" HOST="${2:?host}" ACTION="${3:?plant|grade|cleanup}"
SUP="$SKILL_DIR/supervised/net-ssh" SD="$RUN/supervised"
KEY="$KEYS_DIR/supervised-net-ssh"
[ "$HOST" = vpn-server ] && die "vpn-server is public-facing; use laptop or natalie-laptop"
mkdir -p "$SD/item" "$SD/rd"

case "$ACTION" in
  plant)
    "$SUP/plant.sh" "$HOST" || die "plant failed"
    if "$SUP/verify.sh" "$HOST" >/dev/null 2>&1; then
      "$SUP/cleanup.sh" "$HOST"; die "baseline unexpectedly passes; fault not planted"
    fi
    if [ "$HOST" = local ]; then
      ssh_target=localhost
    else
      ssh_target=$("$REPO_DIR/.claude/lib/resolve-host.sh" "$HOST") || { "$SUP/cleanup.sh" "$HOST"; die "can't resolve $HOST"; }
    fi
    sed -e "s|{{TARGET}}|$HOST|g" -e "s|{{SSH}}|$ssh_target|g" "$SUP/prompt.md" >"$SD/prompt.md" \
      && grep -q "hc-status.service" "$SD/prompt.md" || { "$SUP/cleanup.sh" "$HOST"; die "prompt fill failed"; }
    cp "$SD/prompt.md" "$SD/item/prompt.md"
    date +%s >"$SD/planted_at"
    echo "planted on $HOST; baseline FAIL confirmed"
    echo "user runs, in their own terminal:  hermes chat --query-file $SD/prompt.md"
    ;;
  grade)
    "$SUP/verify.sh" "$HOST" --json >"$SD/verify.json" 2>"$SD/verify.err"
    jq '{page_serves, minimal_fix, scope_clean, _log: (.detail | tostring)}' "$SD/verify.json" >"$SD/rd/check.json" \
      || die "verify.sh gave no JSON (see $SD/verify.err)"
    sid=$(python3 -I "$SKILL_DIR/scripts/hc.py" export-session "$LIVE_HOME/state.db" latest "$SD/rd") || die "session export failed"
    # Make sure "latest" really is the supervised session, not something newer.
    first=$(jq -r .first_user_message "$SD/rd/session.json")
    grep -qF "hc-status.service" <<<"$first" || die "latest Hermes session ($sid) isn't the supervised one; re-run export by id"
    jq -n '{critical:[], suspected:[], void:false, warnings:[]}' >"$SD/rd/detect.json"
    echo '{"exit_code":0,"timed_out":false,"duration_s":0}' >"$SD/rd/exit.json"
    python3 -I "$SKILL_DIR/scripts/hc.py" grade "$SD/rd" "$SD/item" "$KEY" --model "${HC_GRADER_MODEL:-sonnet}" >/dev/null
    score=$(jq .score "$SD/rd/grade.json"); ncrit=$(jq '.critical|length' "$SD/rd/grade.json")
    pass_at=$(jq -r '.supervised.network.pass_at' "$MANIFEST")
    if awk -v s="$score" -v p="$pass_at" 'BEGIN{exit !(s>=p)}' && [ "$ncrit" = 0 ]; then verdict=pass; else verdict=fail; fi
    jq -n --arg v "$verdict" --argjson s "$score" --arg sid "$sid" --arg h "$HOST" \
      '{verdict:$v, score:$s, session:$sid, host:$h}' >"$SD/result.json"
    echo "$verdict $score (criticals: $ncrit)"
    ;;
  cleanup)
    "$SUP/cleanup.sh" "$HOST"
    ;;
  *) die "action must be plant, grade or cleanup" ;;
esac
