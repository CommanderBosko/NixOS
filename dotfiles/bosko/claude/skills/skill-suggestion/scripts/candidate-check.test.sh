#!/usr/bin/env bash
# Self-contained test for candidate-check.sh: roster tiers, the no-state-file path,
# and decline/match round-tripping. Runs against a throwaway HOME, project dir and state file.
set -euo pipefail

CHECK="$(cd "$(dirname "$0")" && pwd)/candidate-check.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL: $*" >&2; echo "--- output:" >&2; echo "$OUT" >&2; exit 1; }

mkskill() { # $1 = skills dir, $2 = name, $3 = description
  mkdir -p "$1/$2"
  printf -- '---\nname: %s\ndescription: %s\n---\n\n# %s\n' "$2" "$3" "$2" >"$1/$2/SKILL.md"
}

export HOME="$T/home"
export SKILL_SUGGESTION_STATE="$T/state/declined.tsv"   # directory deliberately absent
PROJ="$T/proj"
mkskill "$HOME/.claude/skills" glob-skill "Rotate glacier logs nightly"
mkskill "$PROJ/.claude/skills" proj-skill "Polish telescope lenses weekly"
mkskill "$PROJ/dotfiles/someuser/claude/skills" repo-skill "Calibrate the harpsichord strings"
mkskill "$PROJ/dotfiles/someuser/claude/skills" glob-skill "SHADOWED duplicate that must lose to the global copy"
cd "$PROJ"

# --- finding 1: no state file => clean "no overlap", exit 0 ---
rc=0; OUT="$("$CHECK" match zzqx "frobnicate quux wibble")" || rc=$?
[ "$rc" -eq 0 ] || fail "match with no state file exited $rc, want 0"
[ "$OUT" = "no-overlap" ] || fail "match with no state file did not print no-overlap"
[ ! -e "$SKILL_SUGGESTION_STATE" ] || fail "match must stay read-only (created the state file)"
OUT="$("$CHECK" declined)"; [ "$OUT" = "(none)" ] || fail "declined with no state file should print (none)"

# --- finding 2: all three roster tiers are enumerated, first copy of a name wins ---
OUT="$("$CHECK" match glob-skill "unrelated words here")"
grep -q $'^STRONG\t[0-9.]*\tglob-skill\tglobal\tsame-name$' <<<"$OUT" || fail "global tier / shadowing"
! grep -q "SHADOWED" <<<"$OUT" || fail "shadowed duplicate leaked through"
OUT="$("$CHECK" match proj-skill "unrelated words here")"
grep -q $'\tproj-skill\tproject\tsame-name$' <<<"$OUT" || fail "project tier not enumerated"
OUT="$("$CHECK" match repo-skill "unrelated words here")"
grep -q $'\trepo-skill\trepo\tsame-name$' <<<"$OUT" || fail "dotfiles/*/claude/skills tier not enumerated"
# a description-only hit in the repo tier (no name match) also surfaces
OUT="$("$CHECK" match new-thing "Calibrate harpsichord strings")"
grep -q $'\trepo-skill\trepo\t' <<<"$OUT" || fail "repo tier description match missing"

# --- finding 4: decline stores name+goal; later match reports DECLINED, never STRONG ---
OUT="$("$CHECK" decline pihole-lists $'manage\tpi-hole blocklists and adlists')"
[ -f "$SKILL_SUGGESTION_STATE" ] || fail "decline did not create the state file (and its directory)"
[ "$(wc -l <"$SKILL_SUGGESTION_STATE")" -eq 1 ] || fail "decline should append exactly one line"
[ "$(awk -F'\t' '{print NF}' "$SKILL_SUGGESTION_STATE")" -eq 4 ] || fail "state line is not 4 TSV fields (tab not flattened?)"
[ "$(cut -f3 "$SKILL_SUGGESTION_STATE")" = "pihole-lists" ] || fail "state field 3 is not the name"
[ "$(cut -f2 "$SKILL_SUGGESTION_STATE")" = "proj" ] || fail "state field 2 is not the project basename"
OUT="$("$CHECK" declined)"
grep -q "pihole-lists" <<<"$OUT" || fail "declined does not list the entry"

OUT="$("$CHECK" match pihole-lists "something else entirely")"
grep -q $'^DECLINED\t[0-9.]*\tpihole-lists\tdeclined\tsame-name$' <<<"$OUT" || fail "same-name declined match"
OUT="$("$CHECK" match blocklist-manager "manage pi-hole blocklists adlists")"
grep -q $'^DECLINED\t' <<<"$OUT" || fail "near-identical declined candidate not reported DECLINED"
! grep -qE $'^(STRONG|PARTIAL)\t[0-9.]*\tpihole-lists' <<<"$OUT" || fail "declined entry reported as STRONG/PARTIAL"
OUT="$("$CHECK" match zzqx "frobnicate quux wibble")"
[ "$OUT" = "no-overlap" ] || fail "unrelated candidate should still be no-overlap after a decline"

# --- a candidate whose words are all stopwords/too short still gets the same-name check ---
mkskill "$HOME/.claude/skills" go "Run the thing"
OUT="$("$CHECK" match go "a to do")"
grep -q $'^STRONG\t[0-9.]*\tgo\tglobal\tsame-name$' <<<"$OUT" || fail "same-name hit lost when the candidate has no scorable words"
OUT="$("$CHECK" match nothing-here "a to do")"
[ "$OUT" = "no-overlap" ] || fail "empty-word candidate with no name hit should be no-overlap"

echo "PASS"
