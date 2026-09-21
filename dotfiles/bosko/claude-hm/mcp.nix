# Declaratively register user-scope MCP servers in ~/.claude.json, making
# each available in every project rather than only this repo.
# ~/.claude.json is mutable state Claude Code rewrites constantly, so we
# can't symlink it read-only; instead we reconcile one .mcpServers.<name>
# key per server with jq. Idempotent: only rewrites when an entry is
# missing or differs, leaving the rest of the file (project history, auth,
# toggles) untouched.
{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  shell = import ./shell.nix { inherit pkgs; };

  servers = {
    # mcp-nixos needs no auth — plain stdio command.
    nixos = {
      type = "stdio";
      command = "mcp-nixos"; # package installed by modules/claude-code.nix
      args = [ ];
      env = { };
    };
    # tailscale-mcp authenticates via an OAuth client (secrets/common.yaml,
    # declared in modules/claude-code.nix) whose two KEY=VALUE lines must
    # never sit in ~/.claude.json in plaintext — command runs a wrapper that
    # sources them from the sops-decrypted file at launch time instead of
    # passing them through the `env` object.
    tailscale = {
      type = "stdio";
      command = "${pkgs.bash}/bin/bash";
      args = [
        "-c"
        "set -a; source ${osConfig.sops.secrets."tailscale-mcp-env".path}; set +a; exec tailscale-mcp"
      ];
      env = { };
    };
  };
in
{
  home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${shell.jqEdit}
    claudejson="$HOME/.claude.json"
    jq="${pkgs.jq}/bin/jq"
    if [ -f "$claudejson" ]; then
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: desired: ''
          desired='${builtins.toJSON desired}'
          if ! $jq -e --argjson d "$desired" \
            '.mcpServers.${name} == $d' "$claudejson" >/dev/null 2>&1; then
            claude_jq_edit "$claudejson" --argjson d "$desired" '.mcpServers.${name} = $d'
            $VERBOSE_ECHO "Registered user-scope ${name} MCP server in $claudejson"
          fi
        '') servers
      )}
    fi
  '';
}
