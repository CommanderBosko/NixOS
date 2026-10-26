#!/usr/bin/env bash
set -euo pipefail

# Rotate project-state.md for the session-closer skill.
#
# Three sections gain one unit per session and nothing ever removed them. Each
# is rotated into its OWN archive file (most-recent-first, created on first
# use); the live file keeps only the newest units plus a pointer line:
#
#   section                    unit starts at a line beginning   keep  archive
#   ## Current Project State   `**`          (bold-headline block)   5   project-state-archive.md
#   ## Recent Decisions        `- `          (top-level bullet)     10   project-state-decisions-archive.md
#   ## Next Steps              `**Session N` (a session block)       5   project-state-next-steps-archive.md
#
# Only the Next Steps style is that strict on purpose: a stray `**Note:** ...`
# paragraph there is NOT a unit boundary, it travels with the session block above
# it. Lines inside fenced code blocks (``` or ~~~) are never headings or unit
# starts, so a `## ` line in a code sample can't end a section scan early.
#
# ## Current Goals and ## Known Issues / Tech Debt are deliberately NOT rotated
# (they are curated in place, not appended to), and neither is the file header.
#
# A unit runs from its first line to the line before the next unit (or the end
# of the section), so continuation lines, tables and blank lines travel with it.
# Anything between the section heading and the first unit (blank lines, the
# archive pointer) is preamble and is always kept. Blank lines that close the
# section stay in the live file so the next `## ` heading keeps its spacing.
#
# Lossless by construction: the file is split by position into kept / old /
# trailing-blank / tail pieces, the byte counts of the pieces must add up to the
# original or the script aborts before touching anything, and the archive is
# written BEFORE the live file so an interrupted run leaves a duplicate (which
# the next run's output makes obvious), never a loss.
#
# Idempotent: a section with <= its keep count is left alone.
#
# Run from the repo root (or pass it as $1).
#   KEEP=<n>             Current Project State blocks to keep   (default 5)
#   KEEP_DECISIONS=<n>   Recent Decisions entries to keep       (default 10,
#                        roughly the last 5 sessions' worth)
#   KEEP_NEXT_STEPS=<n>  Next Steps session blocks to keep      (default 5)
#   DRY_RUN=1            report what would move (line range + bytes), change nothing

root="${1:-.}"
dry="${DRY_RUN:-0}"
active="${root%/}/project-state.md"

keep_state="${KEEP:-5}"
keep_decisions="${KEEP_DECISIONS:-10}"
keep_steps="${KEEP_NEXT_STEPS:-5}"

want_int() { # want_int <name> <value>
  case "$2" in
    ''|*[!0-9]*|0) echo "$1 must be a positive integer (got '$2')." >&2; exit 2 ;;
  esac
}
want_int KEEP "$keep_state"
want_int KEEP_DECISIONS "$keep_decisions"
want_int KEEP_NEXT_STEPS "$keep_steps"

if [ ! -f "$active" ]; then
  echo "No $active to rotate; nothing to do."
  exit 0
fi

# Refuse input the line-oriented scan would misread, loudly, before touching anything.
if grep -q $'\r$' "$active"; then
  echo "$active has CRLF line endings; this script only handles LF. Convert it (e.g. sed -i 's/\\r\$//' $active) and re-run. Nothing was changed." >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# awk helpers shared by every scan: fenced-code tracking and the per-section
# "does this line start a unit?" test. `style` is bold | bullet | session.
awk_lib='
function fence_toggle(   c) {
  if ($0 ~ /^ ? ? ?[`][`][`]/) c = "`"; else if ($0 ~ /^ ? ? ?~~~/) c = "~"; else return
  if (fence == "") fence = c; else if (fence == c) fence = ""
}
function isunit() {
  if (fence != "") return 0
  if (style == "bullet")  return index($0, "- ") == 1
  if (style == "session") return $0 ~ /^\*\*Session [0-9]+/
  return index($0, "**") == 1
}
function isheading() { return fence == "" && $0 ~ /^## / }
'

# An unclosed code fence would hide every later heading from the scan.
if ! awk "$awk_lib"'{ fence_toggle() } END { if (fence != "") exit 3 }' "$active"; then
  echo "$active has an unclosed fenced code block (a line starting with three backticks or tildes with no matching close); the section scan can't be trusted. Fix the fence and re-run. Nothing was changed." >&2
  exit 1
fi

is_blank() { # is_blank <line> — true for empty / whitespace-only
  [ -z "${1//[[:space:]]/}" ]
}

# rotate_section <heading> <unit-style bold|bullet|session> <keep> <archive-file> <archive-title> <noun> <blank-between-units 0|1> <pointer>
rotate_section() {
  local heading="$1" style="$2" keep="$3" archive_name="$4" title="$5" noun="$6" sep="$7" pointer="$8"
  local archive="${root%/}/$archive_name"
  local d="$work/${archive_name%.md}"
  mkdir -p "$d"

  # Is the heading there (outside any code fence), and how many units follow it
  # before the next '## ' heading?
  local counts found total
  counts="$(awk -v h="$heading" -v style="$style" "$awk_lib"'
    { fence_toggle() }
    state == 0 && fence == "" && $0 == h { state = 1; found = 1; next }
    state == 1 && isheading() { state = 2 }
    state == 1 && isunit() { n++ }
    END { print found + 0, n + 0 }
  ' "$active")"
  found="${counts% *}"; total="${counts#* }"

  if [ "$found" -eq 0 ]; then
    echo "No '$heading' section in $active; skipping."
    return 0
  fi
  if [ "$total" -le "$keep" ]; then
    echo "'$heading': only $total $noun (<= $keep) — no rotation needed."
    return 0
  fi

  # Split by position: .kept = everything up to and including the first $keep
  # units, .old = the units beyond that, .trail = blank lines closing the
  # section, .tail = from the next '## ' heading on. .range = first/last
  # original line number of the archived units.
  : > "$d/kept"; : > "$d/old"; : > "$d/trail"; : > "$d/tail"
  awk -v h="$heading" -v style="$style" -v keep="$keep" \
      -v kept="$d/kept" -v old="$d/old" -v trail="$d/trail" -v tail="$d/tail" -v range="$d/range" "$awk_lib"'
    { fence_toggle() }
    state == 0 { print > kept; if (fence == "" && $0 == h) state = 1; next }
    state == 1 && isheading() { state = 2 }
    state == 2 { print > tail; next }
    isunit() { n++ }
    n <= keep { print > kept; next }
    /^[ \t]*$/ { held[++nh] = $0; next }          # hold blanks: they only join .old if more content follows
    {
      for (i = 1; i <= nh; i++) print held[i] > old
      nh = 0
      if (!first) first = NR
      last = NR
      print > old
    }
    END {
      for (i = 1; i <= nh; i++) print held[i] > trail
      print first + 0, last + 0 > range
    }
  ' "$active"

  # Where do the section-closing blank lines go? If the kept part already ends
  # on a blank line they ride with the archive; otherwise they stay live so the
  # next heading keeps a blank line above it.
  local live_trail=0 last_kept
  if [ -s "$d/trail" ]; then
    last_kept="$(tail -n1 "$d/kept")"
    if is_blank "$last_kept"; then
      cat "$d/trail" >> "$d/old"
      : > "$d/trail"   # now part of .old; don't count (or re-emit) it twice
    else
      live_trail=1
    fi
  fi

  # Safety net: nothing may go missing in the split. awk re-terminates a final
  # unterminated line, so allow +1 byte for that one case.
  local orig_bytes parts_bytes
  orig_bytes="$(wc -c < "$active" | tr -d ' ')"
  if [ -n "$(tail -c1 "$active")" ]; then orig_bytes=$((orig_bytes + 1)); fi
  parts_bytes=$(( $(wc -c < "$d/kept") + $(wc -c < "$d/old") + $(wc -c < "$d/trail") + $(wc -c < "$d/tail") ))
  if [ "$parts_bytes" -ne "$orig_bytes" ]; then
    echo "INTERNAL ERROR rotating '$heading': split pieces total $parts_bytes bytes, original is $orig_bytes. Nothing was changed." >&2
    return 1
  fi

  local first last old_bytes moved plural
  read -r first last < "$d/range"
  old_bytes="$(wc -c < "$d/old" | tr -d ' ')"
  moved=$((total - keep))
  plural="$noun"
  if [ "$moved" -eq 1 ]; then
    case "$noun" in entries) plural="entry" ;; *) plural="${noun%s}" ;; esac
  fi

  if [ "$dry" = "1" ]; then
    echo "DRY RUN '$heading' — would rotate $moved older $plural (lines $first-$last of $active, $old_bytes bytes) into $archive; would keep $keep."
    return 0
  fi

  # --- archive first: an interrupted run must duplicate, never lose ---------
  local first_unit=""
  if [ -f "$archive" ]; then
    first_unit="$(awk -v style="$style" "$awk_lib"'{ fence_toggle() } isunit() { print NR; exit }' "$archive")"
  fi
  if [ -n "$first_unit" ]; then
    # Prepend ahead of the existing units, keeping the archive's own header on
    # top. Block-style units get a blank line between them if this chunk
    # doesn't already end on one.
    if [ "$sep" = "1" ] && ! is_blank "$(tail -n1 "$d/old")"; then echo >> "$d/old"; fi
    { head -n "$((first_unit - 1))" "$archive"; cat "$d/old"; tail -n "+$first_unit" "$archive"; } > "$d/archive.new"
  elif [ -f "$archive" ]; then
    { cat "$archive"; if ! is_blank "$(tail -n1 "$archive")"; then echo; fi; cat "$d/old"; } > "$d/archive.new"
  else
    {
      printf '# %s\n\n' "$title"
      printf 'Older `%s` %s rotated out of [project-state.md](project-state.md) by session-closer, most recent first. Git history holds every pre-rotation version of that file.\n\n' "${heading#\#\# }" "$noun"
      cat "$d/old"
    } > "$d/archive.new"
  fi
  if [ -f "$archive" ]; then chmod --reference="$archive" "$d/archive.new"; else chmod 644 "$d/archive.new"; fi
  mv "$d/archive.new" "$archive"

  # --- then the live file: kept + pointer + (closing blanks) + tail ---------
  {
    if grep -qxF -- "$pointer" "$d/kept"; then
      cat "$d/kept"
    else
      awk -v h="$heading" -v p="$pointer" '
        need { if ($0 != "") print ""; need = 0 }
        { print }
        $0 == h && !done { print ""; print p; done = 1; need = 1 }
      ' "$d/kept"
    fi
    if [ "$live_trail" = "1" ]; then cat "$d/trail"; fi
    cat "$d/tail"
  } > "$d/active.new"
  chmod --reference="$active" "$d/active.new"
  mv "$d/active.new" "$active"

  echo "Rotated '$heading': $moved older $plural (lines $first-$last, $old_bytes bytes) into $archive; kept $keep in $active."
}

# Bottom-up, so the line numbers each message reports refer to the original file.
rotate_section '## Next Steps' session "$keep_steps" \
  'project-state-next-steps-archive.md' 'Project State Archive — Next Steps' 'session blocks' 1 \
  '_Older session blocks are in [project-state-next-steps-archive.md](project-state-next-steps-archive.md); a "still stands" note below may refer to one of them._'

rotate_section '## Recent Decisions' bullet "$keep_decisions" \
  'project-state-decisions-archive.md' 'Project State Archive — Recent Decisions' 'entries' 0 \
  '_Older entries are in [project-state-decisions-archive.md](project-state-decisions-archive.md)._'

rotate_section '## Current Project State' bold "$keep_state" \
  'project-state-archive.md' 'Project State Archive' 'blocks' 1 \
  '_Older blocks are in [project-state-archive.md](project-state-archive.md)._'
