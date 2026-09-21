# Shell snippets shared by the Claude Code activation scripts (settings.nix,
# mcp.nix, plugins.nix). Every activation entry is spliced into one script, but
# each entry is kept self-contained by interpolating the helper itself rather
# than relying on DAG order to have defined it first.
{ pkgs }:

{
  # claude_jq_edit FILE JQ_ARGS... — rewrite FILE in place with the output of
  # `jq JQ_ARGS... FILE`. Goes through a temp file so FILE is only replaced when
  # jq succeeds. Keeps the semantics of the `jq > tmp && mv` idiom it replaces:
  # a jq failure is non-fatal (HM activation runs under `set -e`, and an abort
  # would skip linkGeneration, leaving every home.file symlink uncreated),
  # while a failed `mv` still aborts.
  jqEdit = ''
    claude_jq_edit() {
      local file="$1" tmp
      shift
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      if ${pkgs.jq}/bin/jq "$@" "$file" > "$tmp"; then
        ${pkgs.coreutils}/bin/mv "$tmp" "$file"
      fi
    }
  '';
}
