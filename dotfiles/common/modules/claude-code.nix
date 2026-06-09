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
#   - PreToolUse hook: blocks the classic self-recursive fork bomb on Bash
{ pkgs, ... }:

let
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
      ];
    };
  };
in
{
  environment.etc."claude-code/managed-settings.json".text =
    builtins.toJSON managedSettings;
}
