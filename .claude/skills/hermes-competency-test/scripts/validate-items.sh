#!/usr/bin/env bash
# validate-items.sh [item-id...]: structural + answer-key validation for suite items.
# For each item (default: every items/*/ except the canary): checks item.json, prompt.md and the
# private rubric, then runs check.sh against the private reference solution (must score 1.0 on
# every check criterion) and against the untouched fixture (must score below 1.0 somewhere).
# Prints one PASS/FAIL line per item; exit 0 only if every item passed.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

VALID_CATS="coding network research safety nixos writing organization"
VDIR=$(mktemp -d "${TMPDIR:-/tmp}/hc-validate.XXXXXX")
trap 'rm -rf "$VDIR"' EXIT
build_pristine "$VDIR/pristine.tar" || die "could not build pristine tarball"

ids=("$@")
if [ ${#ids[@]} -eq 0 ]; then
  for d in "$SKILL_DIR"/items/*/; do
    id=$(basename "$d"); [ "$id" = canary ] || ids+=("$id")
  done
fi

# run_checks <id> <mode: reference|untouched> → prints check.sh JSON (or ERROR:...)
run_checks() {
  local id="$1" mode="$2" key="$KEYS_DIR/$1" item="$SKILL_DIR/items/$1"
  local sb="$VDIR/sb-$id-$mode" rd="$VDIR/rd-$id-$mode"
  rm -rf "$rd"; mkdir -p "$rd/truth"
  make_sandbox "$VDIR/pristine.tar" "$sb" "$id" >/dev/null 2>&1 || { echo "ERROR:sandbox"; return; }
  export SANDBOX="$sb" RUN_DIR="$rd" ITEM_DIR="$item" KEY_DIR="$key" TAKER=fake
  export HERMES_TEST_HOME="$rd/home"; mkdir -p "$HERMES_TEST_HOME/memories"
  [ -x "$item/setup.sh" ] && (cd "$sb" && "$item/setup.sh") >"$rd/setup.log" 2>&1
  [ -x "$key/truth.sh" ] && "$key/truth.sh" "$rd/truth" >"$rd/truth.log" 2>&1
  echo '[]' >"$rd/events.json"; : >"$rd/final.txt"; : >"$rd/stream.jsonl"
  echo '{"exit_code":0,"timed_out":false,"duration_s":0}' >"$rd/exit.json"
  if [ "$mode" = reference ]; then
    [ -d "$key/reference/overlay" ] && cp -a "$key/reference/overlay/." "$sb/"
    [ -x "$key/reference/make.sh" ] && (cd "$sb" && "$key/reference/make.sh") >"$rd/make.log" 2>&1
    [ -f "$key/reference/final.txt" ] && cp "$key/reference/final.txt" "$rd/final.txt"
    [ -f "$key/reference/events.json" ] && cp "$key/reference/events.json" "$rd/events.json"
    # Reference home: lets memory-hygiene items ship a model memory state.
    [ -d "$key/reference/home" ] && cp -a "$key/reference/home/." "$HERMES_TEST_HOME/"
  fi
  [ -x "$item/teardown.sh" ] && (cd "$sb" && "$item/teardown.sh") >>"$rd/setup.log" 2>&1
  if [ -f "$rd/pids" ]; then xargs -r kill <"$rd/pids" 2>/dev/null; fi
  local out
  if out=$("$key/check.sh" 2>"$rd/check.err"); then
    echo "$out"
  else
    echo "ERROR:check.sh exit $? ($(tail -c 300 "$rd/check.err" | tr '\n' ' '))"
  fi
}

fails=0
for id in "${ids[@]}"; do
  item="$SKILL_DIR/items/$id" key="$KEYS_DIR/$id" errs=()
  [ -f "$item/item.json" ] || errs+=("missing item.json")
  [ -s "$item/prompt.md" ] || errs+=("missing prompt.md")
  [ -f "$key/rubric.json" ] || errs+=("missing private rubric.json")
  if [ ${#errs[@]} -eq 0 ]; then
    jq -e . "$item/item.json" >/dev/null 2>&1 || errs+=("item.json is not valid JSON")
    jq -e . "$key/rubric.json" >/dev/null 2>&1 || errs+=("rubric.json is not valid JSON")
  fi
  if [ ${#errs[@]} -eq 0 ]; then
    [ "$(jq -r .id "$item/item.json")" = "$id" ] || errs+=("item.json id != directory name")
    cat=$(jq -r .category "$item/item.json")
    [[ " $VALID_CATS " == *" $cat "* ]] || errs+=("bad category '$cat'")
    live=$(jq -r '.live // false' "$item/item.json")
    sum=$(jq '[.criteria[].points] | add' "$key/rubric.json")
    [ "$sum" = 100 ] || errs+=("rubric points sum to $sum, not 100")
    dupes=$(jq -r '[.criteria[].id] | group_by(.) | map(select(length>1)[0]) | join(",")' "$key/rubric.json")
    [ -z "$dupes" ] || errs+=("duplicate criterion ids: $dupes")
    badkind=$(jq -r '[.criteria[] | select(.kind != "check" and .kind != "judge") | .id] | join(",")' "$key/rubric.json")
    [ -z "$badkind" ] || errs+=("bad kind on: $badkind")
    if [ "$cat" = coding ]; then
      jq -e '[.criteria[] | select(.id=="verified" and .kind=="judge" and .points>=15)] | length==1' \
        "$key/rubric.json" >/dev/null || errs+=("coding item lacks a 'verified' judge criterion >=15 pts")
    fi
    [ "$live" = true ] && { [ -x "$key/truth.sh" ] || errs+=("live item without executable truth.sh"); }
    for f in setup.sh teardown.sh; do
      [ -e "$item/$f" ] && { [ -x "$item/$f" ] || errs+=("$f not executable"); }
    done
    for p in $(jq -r '.protected[]?' "$item/item.json"); do
      [ -e "$item/fixture/${p#task/}" ] || [ "${p#task/}" = "$p" ] || errs+=("protected path $p not in fixture")
    done
    checks=$(jq -r '[.criteria[] | select(.kind=="check") | .id] | join(" ")' "$key/rubric.json")
    if [ -n "$checks" ]; then
      [ -x "$key/check.sh" ] || errs+=("check criteria but no executable check.sh")
      [ -d "$key/reference" ] || errs+=("missing reference/")
    fi
    if [ ${#errs[@]} -eq 0 ] && [ -n "$checks" ]; then
      ref=$(run_checks "$id" reference)
      if [[ "$ref" == ERROR:* ]] || ! jq -e 'type=="object"' <<<"$ref" >/dev/null 2>&1; then
        errs+=("reference: ${ref:0:300}")
      else
        for c in $checks; do
          v=$(jq -r --arg c "$c" '.[$c] // "absent"' <<<"$ref")
          [ "$v" = 1 ] || [ "$v" = 1.0 ] || errs+=("reference scores $c=$v (want 1)")
        done
        unt=$(run_checks "$id" untouched)
        if [[ "$unt" == ERROR:* ]] || ! jq -e 'type=="object"' <<<"$unt" >/dev/null 2>&1; then
          errs+=("untouched: ${unt:0:300}")
        else
          # What the untouched fixture already passes; hc.py grade pays only for improvement on it.
          jq 'with_entries(select(.value | type == "number"))' <<<"$unt" >"$key/baseline.json.tmp" \
            && mv "$key/baseline.json.tmp" "$key/baseline.json"
          allone=1
          for c in $checks; do
            v=$(jq -r --arg c "$c" '.[$c] // 0' <<<"$unt")
            awk -v v="$v" 'BEGIN{exit !(v+0 < 1)}' && allone=0
          done
          [ $allone = 0 ] || errs+=("checks don't discriminate: untouched fixture also scores 1.0 everywhere")
        fi
      fi
    fi
  fi
  if [ ${#errs[@]} -eq 0 ]; then
    echo "PASS $id"
  else
    fails=$((fails + 1))
    printf 'FAIL %s: %s\n' "$id" "$(IFS='; '; echo "${errs[*]}")"
  fi
done
echo "validated ${#ids[@]} item(s), $fails failed"
[ $fails -eq 0 ]
