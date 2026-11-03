#!/usr/bin/env bash
# Shared helpers for android-debloat's scripts. Source it; do not run it.

# norm_list <file>: print package names from a file, one per line, sorted and de-duplicated.
# Accepts `pm list packages` output ("package:com.x", or "package:/path/base.apk=com.x" from -f),
# bare names, CRLF line endings (adb on some devices), blank lines and "# comments".
norm_list() {
  sed -e 's/\r$//' -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1" |
    sed -e 's/^package://' -e 's/^.*=//' |
    grep -E '^[A-Za-z0-9_.]+$' | sort -u
}

# is_never <package> <never-file>: exit 0 when the package matches a never-disable entry.
# Entries are exact package names, or globs ending in `*` (e.g. com.android.providers.*).
is_never() {
  local pkg="$1" file="$2" pat
  while IFS= read -r pat; do
    # shellcheck disable=SC2053  # the unquoted right side is the point: it is a glob
    [[ "$pkg" == $pat ]] && return 0
  done < <(sed -e 's/\r$//' -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$file" | grep -v '^$')
  return 1
}
