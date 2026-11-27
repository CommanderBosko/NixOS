#!/usr/bin/env bash
# extract-clients.sh - build the Pi-hole client list from a Teleporter backup.
#
# hosts/pi-hole/clients.nix applies a JSON array of clients (piHole.clients.file)
# from an encrypted secret. This script produces that array from a Pi-hole v6
# Teleporter .zip: it extracts only gravity.db, reads the client table and each
# client's group, and writes [{ "name", "mac", "group" }, ...] with mode 0600.
# Names and MACs are personal data, so the script never prints them: stdout
# carries counts only, and it refuses to write inside a git work tree.
#
# Needs: bash, unzip, sqlite3 (3.33+ for -json), jq, git.
#   nix shell nixpkgs#unzip nixpkgs#sqlite nixpkgs#jq nixpkgs#git \
#     -c ./extract-clients.sh backup.zip /path/outside/the/repo/clients.json
set -euo pipefail

prog="${0##*/}"

usage() {
  cat <<EOF
Usage: $prog [--force] TELEPORTER_ZIP OUTPUT_JSON
       $prog --help

Extract the Pi-hole clients from a Teleporter backup into the JSON file that
piHole.clients.file points at (put it in the encrypted secrets afterwards).

  TELEPORTER_ZIP  Pi-hole v6 Teleporter export (.zip). Only its gravity.db
                  member is extracted, to a private temporary directory that is
                  removed on exit; the database is opened read-only.
  OUTPUT_JSON     Where to write [{"name": ..., "mac": ..., "group": ...}, ...]
                  (created with mode 0600). Its directory must exist and must
                  not be inside a git work tree.

Field mapping: "mac" is the client identifier Pi-hole stores (client.ip, which
holds a MAC address, IP or hostname), "name" is the client's comment (empty when
it has none), "group" is the name of the single group the client belongs to.
A client in no group or in several groups is an error: the file format holds
exactly one group per client.

  -f, --force     Overwrite OUTPUT_JSON if it already exists.
  -h, --help      Show this text.

Only counts are printed (clients, groups); names and addresses never are.
EOF
}

die() {
  echo "$prog: $*" >&2
  exit 1
}

force=0
positional=()
while (($# > 0)); do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    -f | --force) force=1 ;;
    --)
      shift
      positional+=("$@")
      break
      ;;
    -*)
      usage >&2
      die "unknown option: $1"
      ;;
    *) positional+=("$1") ;;
  esac
  shift
done
if ((${#positional[@]} != 2)); then
  usage >&2
  exit 2
fi
zip_arg="${positional[0]}"
out_arg="${positional[1]}"

for tool in unzip sqlite3 jq git; do
  command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
done

[[ -f $zip_arg && -r $zip_arg ]] || die "cannot read the backup archive"
zip_path="$(readlink -f -- "$zip_arg")"

# Resolve the output location without creating anything yet.
out_dir_arg="$(dirname -- "$out_arg")"
[[ -d $out_dir_arg ]] || die "the output directory does not exist"
out_dir="$(cd -- "$out_dir_arg" && pwd -P)"
out_base="${out_arg##*/}"
[[ -n $out_base && $out_base != . && $out_base != .. ]] || die "OUTPUT_JSON must name a file"
out_path="$out_dir/$out_base"
[[ ! -d $out_path ]] || die "OUTPUT_JSON is a directory"

# Fail closed: only git's own "not a git repository" counts as outside a work
# tree. Success (inside a work tree or a .git directory) and any other error
# (dubious ownership, corrupt repository) both refuse.
if git_out="$(cd -- "$out_dir" && env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE LC_ALL=C git rev-parse --is-inside-work-tree 2>&1)"; then
  die "refusing to write inside a git work tree (the file holds personal data)"
fi
case $git_out in
  *"not a git repository"*) ;;
  *) die "cannot tell whether the output directory is in a git work tree: refusing" ;;
esac

if [[ (-e $out_path || -L $out_path) && $force -eq 0 ]]; then
  die "OUTPUT_JSON already exists (use --force to overwrite)"
fi

umask 077
tmp="$(mktemp -d "${TMPDIR:-/tmp}/extract-clients.XXXXXX")"
partial=""
cleanup() {
  rm -rf "$tmp"
  if [[ -n $partial ]]; then
    rm -f "$partial"
  fi
}
trap cleanup EXIT

listing="$(unzip -Z1 "$zip_path" 2>/dev/null)" || die "the backup is not a readable zip archive"
if grep -Fxq 'etc/pihole/gravity.db' <<<"$listing"; then
  member="etc/pihole/gravity.db"
else
  member="$(grep -E '(^|/)gravity\.db$' <<<"$listing" | head -n 1)" || true
fi
[[ -n $member ]] || die "no gravity.db in the backup archive"

db="$tmp/gravity.db"
unzip -p "$zip_path" "$member" >"$db" 2>/dev/null || die "could not extract gravity.db from the archive"
[[ "$(head -c 15 "$db")" == "SQLite format 3" ]] || die "gravity.db in the archive is not an SQLite database"

q() { sqlite3 -readonly "$db" "$1"; }

n_clients="$(q 'SELECT count(*) FROM client;' 2>/dev/null)" || die "gravity.db has no client table"
n_odd="$(q 'SELECT count(*) FROM client c WHERE (SELECT count(*) FROM client_by_group b WHERE b.client_id = c.id) <> 1;')"
if ((n_odd > 0)); then
  die "$n_odd of $n_clients client(s) are in no group or in several; the client file holds exactly one group per client"
fi

rows="$(sqlite3 -readonly -json "$db" 'SELECT c.comment AS name, c.ip AS mac, g.name AS "group" FROM client c JOIN client_by_group b ON b.client_id = c.id JOIN "group" g ON g.id = b.group_id ORDER BY c.id;')"
if [[ -z $rows ]]; then
  rows='[]'
fi

partial="$(mktemp "$out_dir/.${out_base}.XXXXXX")"
chmod 600 "$partial"
jq '[.[] | {name: (.name // ""), mac: .mac, group: .group}]' <<<"$rows" >"$partial"

n_written="$(jq length "$partial")"
if ((n_written != n_clients)); then
  die "$((n_clients - n_written)) of $n_clients client(s) refer to a group that does not exist"
fi
n_groups="$(jq '[.[].group] | unique | length' "$partial")"

mv -f "$partial" "$out_path"
partial=""

echo "clients: $n_written"
echo "groups: $n_groups"
