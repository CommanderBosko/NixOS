#!/usr/bin/env bash
# Deterministic de-dup + decline-memory mechanics for the `skill-suggestion` skill.
# Keeps "does a skill like this already exist?" and "did the user already say no to
# this?" out of model judgement: the model hands over a candidate, this script scores it
# against every installed skill description and every previously declined candidate.
#
# Usage:
#   candidate-check.sh match <name> <goal> [trigger-phrase ...]
#     Scores the candidate against every skill under ~/.claude/skills,
#     ./.claude/skills and ./dotfiles/*/claude/skills (relative to the current directory;
#     de-duplicated by skill name, first copy wins in that order), plus every declined
#     candidate. Read-only. Prints one TSV line per hit, strongest first:
#       <STRONG|PARTIAL|DECLINED>  <score>  <name>  <scope>  <reason>
#     or the single line `no-overlap` if nothing clears the PARTIAL bar. Exit 0 either way
#     (a missing state file just means nothing has been declined yet); non-zero is a real error.
#       STRONG   same name, a trigger phrase already in a skill's description, or
#                >= 50% of the candidate's rarity-weighted words already covered
#       PARTIAL  >= 30% covered -- extend/upgrade that skill instead of a new one
#       DECLINED the candidate hits a declined entry: same name, a trigger phrase (>= 6
#                chars) inside the entry's name+goal, or >= 30% of its words covered. A
#                declined entry is never reported as STRONG or PARTIAL; the scope column
#                reads `declined` and the name column is the declined candidate's name.
#   candidate-check.sh decline <name> <goal>
#     Appends ONE line to the state file: <date> TAB <project dir basename> TAB <name> TAB
#     <goal> (tabs/newlines in name and goal flattened to spaces). Only name and goal are
#     kept, never trigger phrases or steps. There is no expiry and no per-project
#     scoping: later `match` runs in any project compare against it. To revive a declined
#     candidate, delete its line from the state file.
#   candidate-check.sh declined
#     Lists the declined candidates (date, project, name, goal), or `(none)`.
#
# State file: ${SKILL_SUGGESTION_STATE:-$HOME/.claude/state/skill-suggestion-declined.tsv}
# (override only exists so the script can be tested against a throwaway file).
set -uo pipefail

STATE="${SKILL_SUGGESTION_STATE:-$HOME/.claude/state/skill-suggestion-declined.tsv}"
CMD="${1:?usage: candidate-check.sh <match|decline|declined> [...]}"
shift || true

clean() { printf '%s' "$1" | tr '\t\r\n' '   '; }

# Prints "<name>\t<scope>\t<description>" for every installed skill, first copy of a
# name wins (global ~/.claude/skills, then project-local, then repo-owned dotfiles).
list_skills() {
  local entry scope base f name desc d
  local -a roots=("global:$HOME/.claude/skills" "project:.claude/skills")
  # The repo tier needs a real glob: it has to expand as its own word, not inside a
  # "scope:path" string (a quoted or suffixed glob never matches and the tier goes dead).
  for d in dotfiles/*/claude/skills; do
    if [ -d "$d" ]; then roots+=("repo:$d"); fi
  done
  for entry in "${roots[@]}"; do
    scope="${entry%%:*}"; base="${entry#*:}"
    [ -d "$base" ] || continue
    for f in "$base"/*/SKILL.md; do
      [ -f "$f" ] || continue
      name="$(awk 'NR>1&&$0=="---"{exit} /^name:/{sub(/^name:[ ]*/,""); print; exit}' "$f")"
      desc="$(awk 'NR>1&&$0=="---"{exit} /^description:/{sub(/^description:[ ]*/,""); print; exit}' "$f")"
      if [ -n "$name" ]; then printf '%s\t%s\t%s\n' "$name" "$scope" "$(clean "$desc")"; fi
    done
  done | awk -F'\t' '!seen[$1]++'
}

case "$CMD" in
  match)
    CAND_NAME="${1:?usage: candidate-check.sh match <name> <goal> [trigger ...]}"
    CAND_GOAL="${2:?usage: candidate-check.sh match <name> <goal> [trigger ...]}"
    shift 2
    CAND_TRIGGERS="$(printf '%s\n' "$@")"
    {
      list_skills
      # `if`, not `[ -f ] && awk`: a missing state file must leave the group's status 0, or
      # pipefail turns "nothing declined yet" into a non-zero exit from the whole pipeline.
      if [ -f "$STATE" ]; then
        awk -F'\t' 'NF>=4{printf "%s\tdeclined\t%s\n", $3, $4}' "$STATE"
      fi
    } | awk -F'\t' -v cname="$CAND_NAME" -v cgoal="$CAND_GOAL" -v ctrig="$CAND_TRIGGERS" '
      function toks(s, out,   n, i, w, parts) {
        s = tolower(s); gsub(/[^a-z0-9]+/, " ", s)
        n = split(s, parts, " ")
        for (i = 1; i <= n; i++) {
          w = parts[i]
          if (length(w) < 3 || (w in STOP)) continue
          sub(/(ing|es|s)$/, "", w)      # crude stem: run/runs/running, rule/rules
          if (length(w) >= 3) out[w] = 1
        }
      }
      BEGIN {
        n = split("the and for with from that this when use user says say any all are can has have not but you your new add get \
into onto each per via its out one two how what why who run runs make makes made skill skills claude code file files \
want wants then than them they will would should could also only over under about after before between", sw, " ")
        for (i = 1; i <= n; i++) STOP[sw[i]] = 1
        toks(cname " " cgoal " " ctrig, C)
        for (w in C) ctotal++
        ntrig = split(ctrig, TR, "\n")
        cname_l = tolower(cname)
      }
      { name[NR] = $1; scope[NR] = $2; text[NR] = tolower($1 " " $3); delete D
        toks($1 " " $3, D); for (w in D) { df[w]++; has[NR, w] = 1 } docs = NR }
      END {
        # No early-out on an empty candidate word set: a same-name or trigger hit must still
        # surface (wtotal stays 0, so every score is 0 and only those two checks can fire).
        for (w in C) wt[w] = log((docs + 1) / (df[w] + 1)) + 0.1
        for (w in C) wtotal += wt[w]
        for (i = 1; i <= docs; i++) {
          cov = 0; shared = ""
          for (w in C) if ((i, w) in has) { cov += wt[w]; shared = shared (shared ? "," : "") w }
          score = wtotal ? cov / wtotal : 0
          reason = "words:" shared
          verdict = ""
          if (tolower(name[i]) == cname_l) { verdict = "STRONG"; reason = "same-name" }
          else {
            for (t = 1; t <= ntrig; t++) {
              p = tolower(TR[t]); gsub(/^[ \t"]+|[ \t"]+$/, "", p)
              if (length(p) >= 6 && index(text[i], p)) { verdict = "STRONG"; reason = "trigger-collision:\"" p "\""; break }
            }
          }
          if (verdict == "") verdict = score >= 0.5 ? "STRONG" : score >= 0.3 ? "PARTIAL" : ""
          if (verdict == "") continue
          if (scope[i] == "declined") verdict = "DECLINED"
          printf "%s\t%.2f\t%s\t%s\t%s\n", verdict, score, name[i], scope[i], reason
          hits++
        }
        if (!hits) print "no-overlap"
      }' | { IFS= read -r first || exit 0
             if [ "$first" = "no-overlap" ]; then echo "$first"; else { echo "$first"; cat; } | sort -t$'\t' -k2,2nr; fi; }
    ;;
  decline)
    NAME="${1:?usage: candidate-check.sh decline <name> <goal>}"
    GOAL="${2:?usage: candidate-check.sh decline <name> <goal>}"
    mkdir -p "$(dirname "$STATE")"
    printf '%s\t%s\t%s\t%s\n' "$(date +%F)" "$(basename "$PWD")" "$(clean "$NAME")" "$(clean "$GOAL")" >>"$STATE"
    echo "declined: $NAME -> $STATE"
    ;;
  declined)
    [ -f "$STATE" ] && cat "$STATE" || echo "(none)"
    ;;
  *)
    echo "usage: candidate-check.sh <match|decline|declined> [...]" >&2
    exit 2
    ;;
esac
