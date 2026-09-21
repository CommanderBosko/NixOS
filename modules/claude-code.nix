# Claude Code policy — enforced via system-level managed settings.
#
# Deployed to /etc/claude-code/managed-settings.json on every host. Managed
# settings are the highest-precedence scope and cannot be overridden; deny/ask
# rules and hooks MERGE on top of each user's personal ~/.claude/settings.json,
# which stays fully writable for personal prefs (model, theme, plugins, allow).
#
# Contents:
#   - deny: filesystem-destruction and disk/partition commands (incl. sudo variants)
#   - ask:  git history/remote, NixOS gc/rollback, and system/process commands
#   - PreToolUse hooks (both matcher: "Bash", both fire independently):
#       - blocks the classic self-recursive fork bomb
#       - routes commands through rtk (installed below) to cut token usage;
#         rtk itself defers to Claude's native deny/ask rules on match, so the
#         two hooks don't fight each other
#
# Deliberately NOT set up via `rtk init -g`: that writes the hook straight into
# ~/.claude/settings.json, which the trimClaudeSettings HM activation
# (dotfiles/bosko/claude-hm/settings.nix) strips clean on every rebuild once this managed file
# exists. Declaring it here is the only form that survives a rebuild.
#
# Also owns bosko's claude-code binary and rtk on every host. The MCP servers
# and their sops secrets are desktop-only — see claude-mcp.nix.
{ pkgs, ... }:

let
  # rtk isn't in nixpkgs-25.11 (stable) yet, only unstable — vpn-server pins
  # stable, so guard on attribute existence rather than hardcoding it and
  # breaking that host's eval. Picks itself up automatically once a future
  # stable point-release backports the package. Used both for the package and
  # for the PreToolUse hook below (the hook must only exist where the binary
  # does, or `claude` would hit "command not found" on every Bash call).
  hasRtk = pkgs ? rtk;

  # jq inspects the Bash command and denies the fork bomb pattern
  # `name(){ ... | ... & }; name`. Pinned to the store path so it resolves
  # regardless of the user's PATH. Backslashes are doubled for jq string escaping.
  forkBombGuard = ''
    ${pkgs.jq}/bin/jq -c 'if (.tool_input.command // "") | test("([\\w:]+)\\s*\\(\\)\\s*\\{[^}]*\\|[^}]*&[^}]*\\}\\s*;\\s*\\1") then {hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"fork bomb pattern blocked"}} else empty end' 2>/dev/null || true
  '';

  managedSettings = {
    permissions = {
      deny = [
        "Bash(rm -rf /)"
        "Bash(rm -rf /*)"
        "Bash(rm -rf ~)"
        "Bash(rm -rf ~/*)"
        "Bash(rm -rf /home/*)"
        "Bash(shred *)"
        "Bash(wipe *)"
        "Bash(find * -delete*)"
        "Bash(find * -exec rm*)"
        "Bash(dd *)"
        "Bash(mkfs*)"
        "Bash(wipefs*)"
        "Bash(sgdisk*)"
        "Bash(parted*)"
        "Bash(fdisk*)"
        "Bash(cfdisk*)"
        "Bash(cryptsetup luksFormat*)"
        "Bash(sudo rm -rf /)"
        "Bash(sudo rm -rf /*)"
        "Bash(sudo rm -rf ~)"
        "Bash(sudo rm -rf ~/*)"
        "Bash(sudo rm -rf /home/*)"
        "Bash(sudo shred *)"
        "Bash(sudo wipe *)"
        "Bash(sudo find * -delete*)"
        "Bash(sudo find * -exec rm*)"
        "Bash(sudo dd *)"
        "Bash(sudo mkfs*)"
        "Bash(sudo wipefs*)"
        "Bash(sudo sgdisk*)"
        "Bash(sudo parted*)"
        "Bash(sudo fdisk*)"
        "Bash(sudo cfdisk*)"
        "Bash(sudo cryptsetup luksFormat*)"
      ];
      ask = [
        "Bash(git push --force*)"
        "Bash(git push -f*)"
        "Bash(git reset --hard*)"
        "Bash(git clean *)"
        "Bash(git branch -D*)"
        "Bash(nix-collect-garbage*)"
        "Bash(nix-store --gc*)"
        "Bash(nix store delete*)"
        "Bash(nixos-rebuild --rollback*)"
        "Bash(nixos-rebuild * --rollback*)"
        "Bash(shutdown*)"
        "Bash(reboot*)"
        "Bash(poweroff*)"
        "Bash(halt*)"
        "Bash(pkill *)"
        "Bash(kill -9 *)"
        "Bash(chmod -R *)"
        "Bash(chown -R *)"
      ];
    };

    hooks = {
      PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = forkBombGuard;
              statusMessage = "Checking for fork bomb";
            }
          ];
        }
      ]
      ++ pkgs.lib.optional hasRtk {
        matcher = "Bash";
        hooks = [
          {
            type = "command";
            command = "rtk hook claude";
            statusMessage = "Routing through rtk";
          }
        ];
      };
    };
  };
in
{
  environment.etc."claude-code/managed-settings.json".text =
    builtins.toJSON managedSettings;

  users.users.bosko.packages = with pkgs; [
    claude-code
  ]
  # TEMPORARY (added 2026-07-24): rtk-0.43.0's checkPhase fails upstream —
  # `cargo test` runs with -D warnings and the rtk crate has dead-code
  # warnings that get promoted to hard errors, breaking the nixpkgs build
  # outright. This skips rtk's own test suite so the package still builds;
  # REMOVE this override once nixpkgs ships an rtk revision whose tests
  # pass cleanly (i.e. `nh os boot --dry` builds rtk without doCheck=false).
  ++ pkgs.lib.optional hasRtk (pkgs.rtk.overrideAttrs (_: { doCheck = false; })); # Claude Code token-optimizing Bash proxy (hook above)
}
