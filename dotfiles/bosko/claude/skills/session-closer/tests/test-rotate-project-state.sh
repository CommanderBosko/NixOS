#!/usr/bin/env bash
# test-rotate-project-state.sh — tests for scripts/rotate-project-state.sh.
# Runs only on temp copies; never touches a real project-state.md. Proves:
#   - bash -n on the script and this test
#   - LOSSLESS: for every rotated section, the live section (minus the pointer)
#     plus the archive's units reassemble byte-for-byte to the original section,
#     in order, with no duplicates (synthetic fixtures in several shapes)
#   - ## Current Goals, ## Known Issues / Tech Debt and the file header come out
#     byte-identical
#   - idempotence: a second run changes nothing
#   - multi-round: the next close's new units rotate in ahead of older archived ones
#   - KEEP* overrides, DRY_RUN, bad input, missing section / file, unterminated file
#   - optionally the REAL file: REAL_STATE=<a pre-rotation project-state.md>
#     [REAL_ARCHIVE=<its project-state-archive.md>]; defaults to the repo root's
#     copies (then the reassembly checks are skipped for sections that are
#     already rotated)
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROTATE="$SKILL_DIR/scripts/rotate-project-state.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
ok()  { pass=$((pass + 1)); echo "PASS  $1"; }
bad() { fail=$((fail + 1)); echo "FAIL  $1"; if [ -n "${2:-}" ]; then echo "      $2"; fi; }
check_eq() { # check_eq <name> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected: '$2'  actual: '$3'"; fi
}
check_cmp() { # check_cmp <name> <file-a> <file-b>
  if cmp -s "$2" "$3"; then ok "$1"; else bad "$1" "files differ: $(diff "$2" "$3" | head -6 | tr '\n' '|')"; fi
}

# --- text helpers (stdin/file -> stdout; exact bytes preserved) ------------------
section()      { awk -v h="$2" 'st == 0 && $0 == h { st = 1; print; next } st == 1 && /^## / { st = 2 } st == 1 { print }' "$1"; }
header_of()    { awk '/^## / { exit } { print }' "$1"; }
from_unit()    { awk -v pre="$2" 'on || index($0, pre) == 1 { on = 1; print }' "$1"; }   # first unit line -> EOF
strip_tb()     { awk '/^[ \t]*$/ { held[++n] = $0; next } { for (i = 1; i <= n; i++) print held[i]; n = 0; print }'; }
trailing_bl()  { awk '/^[ \t]*$/ { n++; next } { n = 0 } END { for (i = 1; i <= n; i++) print "" }'; }
drop_pointer() { awk '{ l[NR] = $0 } END { for (i = 1; i <= NR; i++) if (l[i] ~ /^_Older /) { skip[i] = 1; if (i > 1 && l[i-1] == "") skip[i-1] = 1 } for (i = 1; i <= NR; i++) if (!skip[i]) print l[i] }'; }
nb_lines()     { grep -v '^[[:space:]]*$' || true; }
count_units()  { awk -v h="$2" -v pre="$3" 'st == 0 && $0 == h { st = 1; next } st == 1 && /^## / { st = 2 } st == 1 && index($0, pre) == 1 { n++ } END { print n + 0 }' "$1"; }
sorted_counts(){ sort | uniq -c | sort; }   # multiset of lines

# lossless <label> <orig-file> <live-after-file> <heading> <unit-prefix> <archive-file>
lossless() {
  local label="$1" orig="$2" live="$3" heading="$4" pre="$5" arch="$6" d="$WORK/ll" k ln
  rm -rf "$d"; mkdir -p "$d"
  section "$orig" "$heading" > "$d/orig_sec"
  section "$live" "$heading" | drop_pointer > "$d/live_body"
  from_unit "$arch" "$pre" > "$d/arch_units"
  k="$(count_units "$live" "$heading" "$pre")"
  ln="$(awk -v pre="$pre" -v k="$k" 'index($0, pre) == 1 && ++n == k + 1 { print NR; exit }' "$d/orig_sec")"
  if [ -z "$ln" ]; then bad "$label: original has no unit number $((k + 1)) — nothing was rotated?"; return; fi
  head -n "$((ln - 1))" "$d/orig_sec" > "$d/e_live"                 # original: heading + kept units
  tail -n "+$ln" "$d/orig_sec" > "$d/e_old"                         # original: archived units (+ closing blanks)
  strip_tb < "$d/e_old" > "$d/e_old_core"
  trailing_bl < "$d/e_old" > "$d/closing"
  cat "$d/e_live" "$d/closing" > "$d/e_live_closing"
  # the section-closing blank lines go to exactly one place: live or archive
  if cmp -s "$d/e_old" "$d/arch_units"; then
    check_cmp "$label: archive == original archived units, byte-for-byte, in order" "$d/e_old" "$d/arch_units"
    check_cmp "$label: live section (minus pointer) == original kept units, byte-for-byte" "$d/e_live" "$d/live_body"
  else
    check_cmp "$label: archive == original archived units, byte-for-byte, in order" "$d/e_old_core" "$d/arch_units"
    check_cmp "$label: live section (minus pointer) == original kept units + closing blanks, byte-for-byte" "$d/e_live_closing" "$d/live_body"
  fi
  check_eq "$label: bytes conserved (live body + archive units == original section)" \
    "$(wc -c < "$d/orig_sec" | tr -d ' ')" "$(( $(wc -c < "$d/live_body") + $(wc -c < "$d/arch_units") ))"
  { nb_lines < "$d/live_body"; nb_lines < "$d/arch_units"; } | sorted_counts > "$d/c_new"
  nb_lines < "$d/orig_sec" | sorted_counts > "$d/c_orig"
  check_cmp "$label: no line lost or duplicated (line multiset equal)" "$d/c_orig" "$d/c_new"
}

untouched() { # untouched <label> <orig> <after> — header + Goals + Known Issues byte-identical
  local label="$1" orig="$2" after="$3" d="$WORK/un"
  rm -rf "$d"; mkdir -p "$d"
  header_of "$orig" > "$d/h1";                                 header_of "$after" > "$d/h2"
  section "$orig" '## Current Goals' > "$d/g1";                section "$after" '## Current Goals' > "$d/g2"
  section "$orig" '## Known Issues / Tech Debt' > "$d/k1";     section "$after" '## Known Issues / Tech Debt' > "$d/k2"
  check_cmp "$label: file header byte-identical" "$d/h1" "$d/h2"
  check_cmp "$label: Current Goals byte-identical" "$d/g1" "$d/g2"
  check_cmp "$label: Known Issues byte-identical" "$d/k1" "$d/k2"
  if [ -s "$d/g1" ] && [ -s "$d/k1" ]; then ok "$label: Goals and Known Issues are non-empty (so the comparison means something)"; else bad "$label: Goals/Known Issues empty"; fi
}

# --- 1. syntax ---------------------------------------------------------------------
for s in "$ROTATE" "$0"; do
  if bash -n "$s"; then ok "bash -n $(basename "$s")"; else bad "bash -n $(basename "$s")"; fi
done

# --- fixture generator ---------------------------------------------------------------
# gen <out> <n_state> <n_decisions> <n_steps> <dec_style: tight|spaced|mixed> <next_steps_tail: plain|legacy>
gen() {
  local out="$1" ns="$2" nd="$3" nx="$4" style="$5" tailstyle="$6" i
  {
    printf '# Test Project State\n\n_Last updated: fixture_\n\n'
    printf '## Current Project State\n\n'
    for i in $(seq "$ns" -1 1); do
      printf '**2026-01-%02d state headline %d**\n- state bullet A for %d — unicode ✓ `code`\n- state bullet B for %d\n\n' "$i" "$i" "$i" "$i"
    done
    printf '## Current Goals\n\n- **Goal one** — text\n- **Goal two** — more text\n\n### Long-term\n\n- **Far goal** — much later\n\n'
    printf '## Recent Decisions\n\n'
    for i in $(seq "$nd" -1 1); do
      printf -- '- **Decision %d (2026-02-%02d, session %d)** — chosen because reasons ✓; rejected alternative X\n' "$i" "$((i % 28 + 1))" "$i"
      if [ $((i % 7)) -eq 3 ]; then printf '  continuation line of decision %d\n  - nested detail of %d\n' "$i" "$i"; fi
      if [ "$i" -eq 4 ]; then printf -- '- ~~struck-through decision (2026-01-01)~~ — **REVERSED** later\n'; fi
      case "$style" in
        spaced) printf '\n' ;;
        mixed)  if [ $((i % 4)) -eq 0 ]; then printf '\n'; fi ;;
      esac
    done
    if [ "$style" = tight ]; then printf '\n'; fi
    printf '## Known Issues / Tech Debt\n\n- **Issue one** — text\n- **Issue two** — text\n\n'
    printf '## Next Steps\n\n'
    for i in $(seq "$nx" -1 1); do
      printf '**Session %d next steps:**\n1. first item of %d\n2. ~~done item~~ — **DONE**\n\n' "$i" "$i"
    done
    if [ "$tailstyle" = legacy ]; then
      printf '~~0000000a. old struck item~~ — **RESOLVED**\n\n> **Stale-content note (session 50):** most numbered items below overlap.\n\n00000. **old numbered item** — text\n1. **Rebuild** — text\n10. **Optional: last item, no blank line after**\n'
    fi
  } > "$out"
}

headings=('## Current Project State' '## Recent Decisions' '## Next Steps')
prefixes=('**' '- ' '**')
archives=(project-state-archive.md project-state-decisions-archive.md project-state-next-steps-archive.md)

run_rotate() { (cd "$WORK" && "$ROTATE" "$1" 2>&1); }

# --- 2. synthetic fixtures: lossless + untouched + idempotent --------------------------
for variant in "tight legacy" "spaced plain" "mixed legacy"; do
  set -- $variant
  style="$1"; tailstyle="$2"
  name="synthetic[$style/$tailstyle]"
  dir="$WORK/syn-$style-$tailstyle"; mkdir -p "$dir"
  gen "$dir/project-state.md" 8 25 9 "$style" "$tailstyle"
  cp "$dir/project-state.md" "$dir/ORIG.md"
  run_rotate "$dir" > /dev/null; rc=$?
  check_eq "$name: exit 0" "0" "$rc"
  for k in 0 1 2; do
    lossless "$name / ${headings[$k]}" "$dir/ORIG.md" "$dir/project-state.md" "${headings[$k]}" "${prefixes[$k]}" "$dir/${archives[$k]}"
  done
  untouched "$name" "$dir/ORIG.md" "$dir/project-state.md"
  check_eq "$name: Current Project State keeps 5 blocks" "5" "$(count_units "$dir/project-state.md" '## Current Project State' '**')"
  check_eq "$name: Recent Decisions keeps 10 entries" "10" "$(count_units "$dir/project-state.md" '## Recent Decisions' '- ')"
  check_eq "$name: Next Steps keeps 5 session blocks" "5" "$(count_units "$dir/project-state.md" '## Next Steps' '**')"
  for k in 0 1 2; do
    check_eq "$name: pointer to ${archives[$k]} present exactly once" "1" "$(grep -cF "(${archives[$k]})" "$dir/project-state.md")"
  done
  check_eq "$name: decisions archive holds 16 top-level entries (15 + the struck-through one)" "16" "$(grep -c '^- ' "$dir/project-state-decisions-archive.md")"
  check_eq "$name: next-steps archive holds 4 session blocks" "4" "$(grep -c '^\*\*Session' "$dir/project-state-next-steps-archive.md")"
  if head -n1 "$dir/project-state-decisions-archive.md" | grep -q '^# '; then ok "$name: new archive has a title header"; else bad "$name: archive header missing"; fi
  # idempotence
  cp "$dir/project-state.md" "$dir/s1"
  for a in "${archives[@]}"; do cp "$dir/$a" "$dir/s1.$a"; done
  out2="$(run_rotate "$dir")"; rc2=$?
  check_eq "$name: second run exit 0" "0" "$rc2"
  check_eq "$name: second run reports no rotation for all 3 sections" "3" "$(printf '%s\n' "$out2" | grep -c 'no rotation needed')"
  check_cmp "$name: second run left project-state.md untouched" "$dir/s1" "$dir/project-state.md"
  for a in "${archives[@]}"; do check_cmp "$name: second run left $a untouched" "$dir/s1.$a" "$dir/$a"; done
done

# --- 3. multi-round: a later close's new units rotate in ahead of the older ones -------------
dir="$WORK/multi"; mkdir -p "$dir"
gen "$dir/project-state.md" 8 25 9 mixed legacy
run_rotate "$dir" > /dev/null
for a in "${archives[@]}"; do head -n 3 "$dir/$a" > "$dir/hdr.$a"; done
# Simulate the next session close: new units go in as the NEWEST units of each section.
awk '
  /^## / { sec = $0 }
  sec == "## Current Project State" && !d1 && index($0, "**") == 1 {
    print "**2026-03-02 NEW state block B**"; print "- new bullet"; print ""
    print "**2026-03-01 NEW state block A**"; print "- new bullet"; print ""; d1 = 1 }
  sec == "## Recent Decisions" && !d2 && index($0, "- ") == 1 {
    print "- **NEW decision 3**"; print "- **NEW decision 2**"; print "- **NEW decision 1**"; d2 = 1 }
  sec == "## Next Steps" && !d3 && index($0, "**") == 1 {
    print "**Session 99 next steps:**"; print "1. brand new item"; print ""; d3 = 1 }
  { print }
' "$dir/project-state.md" > "$dir/ROUND2_IN.md"
cp "$dir/ROUND2_IN.md" "$dir/project-state.md"
for k in 0 1 2; do cp "$dir/${archives[$k]}" "$dir/before.${archives[$k]}"; done
run_rotate "$dir" > /dev/null; rc=$?
check_eq "multi-round: exit 0" "0" "$rc"
check_eq "multi-round: state live back to 5 blocks" "5" "$(count_units "$dir/project-state.md" '## Current Project State' '**')"
check_eq "multi-round: decisions live back to 10" "10" "$(count_units "$dir/project-state.md" '## Recent Decisions' '- ')"
check_eq "multi-round: next steps live back to 5" "5" "$(count_units "$dir/project-state.md" '## Next Steps' '**')"
untouched "multi-round" "$dir/ROUND2_IN.md" "$dir/project-state.md"
for k in 0 1 2; do
  pre="${prefixes[$k]}"; h="${headings[$k]}"; a="${archives[$k]}"
  # ideal order = round-2 input's live units, then the archive as it stood before round 2
  { section "$dir/ROUND2_IN.md" "$h" | drop_pointer | awk -v pre="$pre" 'on || index($0, pre) == 1 { on = 1; print }' | nb_lines
    from_unit "$dir/before.$a" "$pre" | nb_lines; } > "$dir/ideal_all"
  { section "$dir/project-state.md" "$h" | drop_pointer | awk -v pre="$pre" 'on || index($0, pre) == 1 { on = 1; print }' | nb_lines
    from_unit "$dir/$a" "$pre" | nb_lines; } > "$dir/act_all"
  check_cmp "multi-round / $h: live units + archive units == previous live + previous archive, same order, nothing duplicated" "$dir/ideal_all" "$dir/act_all"
  head -n 3 "$dir/$a" > "$dir/hdr_after"
  check_cmp "multi-round / $h: archive header still on top" "$dir/hdr.$a" "$dir/hdr_after"
  # the older archive content must survive verbatim at the end of the new archive
  from_unit "$dir/before.$a" "$pre" > "$dir/old_units"
  tail -n "$(wc -l < "$dir/old_units")" "$dir/$a" > "$dir/new_tail"
  check_cmp "multi-round / $h: previously archived units survive verbatim at the archive's end" "$dir/old_units" "$dir/new_tail"
done
check_eq "multi-round: newest rotated-out decision (18) is the first entry in the archive" \
  "1" "$(from_unit "$dir/project-state-decisions-archive.md" '- ' | head -n1 | grep -c '^- \*\*Decision 18 ')"

# --- 4. knobs and bad input ----------------------------------------------------------------
dir="$WORK/knobs"; mkdir -p "$dir"
gen "$dir/project-state.md" 8 25 9 tight legacy
cp "$dir/project-state.md" "$dir/ORIG.md"
out="$(DRY_RUN=1 run_rotate "$dir")"
check_eq "DRY_RUN=1 reports all three sections as would-rotate" "3" "$(printf '%s\n' "$out" | grep -c '^DRY RUN')"
check_cmp "DRY_RUN=1 changes nothing" "$dir/ORIG.md" "$dir/project-state.md"
check_eq "DRY_RUN=1 creates no archive file" "0" "$(ls "$dir" | grep -c 'archive')"
(cd "$WORK" && KEEP_DECISIONS=3 KEEP_NEXT_STEPS=2 KEEP=4 "$ROTATE" "$dir" > /dev/null 2>&1)
check_eq "KEEP_DECISIONS=3 keeps 3 entries" "3" "$(count_units "$dir/project-state.md" '## Recent Decisions' '- ')"
check_eq "KEEP_NEXT_STEPS=2 keeps 2 session blocks" "2" "$(count_units "$dir/project-state.md" '## Next Steps' '**')"
check_eq "KEEP=4 keeps 4 state blocks" "4" "$(count_units "$dir/project-state.md" '## Current Project State' '**')"
lossless "knobs / decisions keep 3" "$dir/ORIG.md" "$dir/project-state.md" '## Recent Decisions' '- ' "$dir/project-state-decisions-archive.md"
lossless "knobs / next steps keep 2" "$dir/ORIG.md" "$dir/project-state.md" '## Next Steps' '**' "$dir/project-state-next-steps-archive.md"
lossless "knobs / state keep 4" "$dir/ORIG.md" "$dir/project-state.md" '## Current Project State' '**' "$dir/project-state-archive.md"
untouched "knobs" "$dir/ORIG.md" "$dir/project-state.md"

dir="$WORK/small"; mkdir -p "$dir"
gen "$dir/project-state.md" 3 6 2 tight plain
cp "$dir/project-state.md" "$dir/ORIG.md"
run_rotate "$dir" > /dev/null
check_cmp "fewer units than KEEP: file untouched" "$dir/ORIG.md" "$dir/project-state.md"
check_eq "fewer units than KEEP: no archive files created" "0" "$(ls "$dir" | grep -c 'archive')"

dir="$WORK/nosection"; mkdir -p "$dir"
gen "$dir/project-state.md" 8 25 9 tight plain
awk '/^## Next Steps$/ { exit } { print }' "$dir/project-state.md" > "$dir/ps.new" && mv "$dir/ps.new" "$dir/project-state.md"
out="$(run_rotate "$dir")"; rc=$?
check_eq "missing section: exit 0" "0" "$rc"
if printf '%s\n' "$out" | grep -q "No '## Next Steps' section"; then ok "missing section: reported and skipped"; else bad "missing section: not reported" "$out"; fi
check_eq "missing section: other sections still rotated" "10" "$(count_units "$dir/project-state.md" '## Recent Decisions' '- ')"

out="$(cd "$WORK" && KEEP_DECISIONS=abc "$ROTATE" "$dir" 2>&1)"; rc=$?
check_eq "KEEP_DECISIONS=abc rejected with exit 2" "2" "$rc"
out="$(cd "$WORK" && KEEP=0 "$ROTATE" "$dir" 2>&1)"; rc=$?
check_eq "KEEP=0 rejected with exit 2" "2" "$rc"
out="$(run_rotate "$WORK/does-not-exist")"; rc=$?
check_eq "missing project-state.md: exit 0, nothing to do" "0" "$rc"

# a last line with no newline must not be lost (awk re-terminates it; the byte-sum check allows +1)
dir="$WORK/noeol"; mkdir -p "$dir"
gen "$dir/project-state.md" 8 25 9 tight legacy
printf '%s' "$(cat "$dir/project-state.md")" > "$dir/ps.noeol" && mv "$dir/ps.noeol" "$dir/project-state.md"
run_rotate "$dir" > /dev/null; rc=$?
check_eq "no trailing newline: exit 0" "0" "$rc"
check_eq "no trailing newline: last original line survives in the archive" "1" "$(grep -c 'Optional: last item, no blank line after' "$dir/project-state-next-steps-archive.md")"

# --- 5. the real file (pre-rotation copy via REAL_STATE, else the repo's) ---------------------------
REPO_ROOT="$(cd "$SKILL_DIR/../../../../.." 2>/dev/null && pwd || true)"
real_state="${REAL_STATE:-$REPO_ROOT/project-state.md}"
real_archive="${REAL_ARCHIVE:-$REPO_ROOT/project-state-archive.md}"
if [ -f "$real_state" ]; then
  dir="$WORK/real"; mkdir -p "$dir"
  cp "$real_state" "$dir/project-state.md"; cp "$real_state" "$dir/ORIG.md"
  if [ -f "$real_archive" ]; then cp "$real_archive" "$dir/project-state-archive.md"; fi
  before_bytes="$(wc -c < "$dir/project-state.md" | tr -d ' ')"
  run_rotate "$dir" > "$dir/run.out"; rc=$?
  check_eq "real file: exit 0" "0" "$rc"
  after_bytes="$(wc -c < "$dir/project-state.md" | tr -d ' ')"
  echo "      real file: project-state.md $before_bytes -> $after_bytes bytes"
  sed "s#$dir#<tmp>#g; s/^/      | /" "$dir/run.out" | cut -c1-220
  untouched "real file" "$dir/ORIG.md" "$dir/project-state.md"
  for k in 1 2; do
    if grep -qF "(${archives[$k]})" "$dir/ORIG.md"; then
      echo "      real file: ${headings[$k]} already rotated in the input — reassembly check skipped"
    else
      lossless "real file / ${headings[$k]}" "$dir/ORIG.md" "$dir/project-state.md" "${headings[$k]}" "${prefixes[$k]}" "$dir/${archives[$k]}"
    fi
  done
  if [ -f "$real_archive" ]; then
    check_cmp "real file: pre-existing project-state-archive.md untouched (Current Project State was within its window)" "$real_archive" "$dir/project-state-archive.md"
  fi
  cp "$dir/project-state.md" "$dir/s1"
  for a in "${archives[@]}"; do if [ -f "$dir/$a" ]; then cp "$dir/$a" "$dir/s1.$a"; fi; done
  run_rotate "$dir" > /dev/null
  check_cmp "real file: second run left project-state.md untouched (idempotent)" "$dir/s1" "$dir/project-state.md"
  for a in "${archives[@]}"; do if [ -f "$dir/s1.$a" ]; then check_cmp "real file: second run left $a untouched" "$dir/s1.$a" "$dir/$a"; fi; done
else
  echo "      (no real project-state.md found — set REAL_STATE to exercise it)"
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
