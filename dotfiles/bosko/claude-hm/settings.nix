# Reconciles ~/.claude/settings.json on every rebuild. The file is mutable state
# Claude Code rewrites (interactive /model, plugin toggles), so it is never a
# read-only symlink — each piece below edits just its own keys with jq.
{ pkgs, lib, ... }:

let
  shell = import ./shell.nix { inherit pkgs; };
in
{
  # Once the NixOS-managed Claude Code policy is active
  # (/etc/claude-code/managed-settings.json enforces deny/ask + the fork bomb
  # hook globally), the matching keys in the personal ~/.claude/settings.json are
  # redundant — keeping them just runs the hook twice. This trims them on every
  # rebuild while leaving the file writable, so interactive /model and plugin
  # toggles still persist. Idempotent and a no-op until the managed file exists.
  home.activation.trimClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${shell.jqEdit}
    managed=/etc/claude-code/managed-settings.json
    settings="$HOME/.claude/settings.json"
    if [ -f "$managed" ] && [ -f "$settings" ]; then
      if ${pkgs.jq}/bin/jq -e \
        '(.permissions.deny? // .permissions.ask? // .hooks?) != null' \
        "$settings" >/dev/null 2>&1; then
        claude_jq_edit "$settings" 'del(.permissions.deny, .permissions.ask, .hooks)'
        $VERBOSE_ECHO "Trimmed redundant deny/ask/hooks from $settings"
      fi
    fi
  '';

  # Declaratively reconcile the personal permissions.allow list in
  # ~/.claude/settings.json. The managed policy (/etc/claude-code/managed-settings.json,
  # see modules/claude-code.nix) owns deny/ask/hooks system-wide; the allow list is a
  # per-user convenience that belongs here, not in the system policy. We reconcile
  # additively (rather than symlinking the file read-only) so interactive /model and
  # plugin toggles still persist and the plugin-management scripts (plugins.nix) keep working.
  # Idempotent: only rewrites when a desired entry is missing; preserves hand-added ones.
  home.activation.claudeAllowList = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    let
      allowList = [
        "Skill"
        "Bash(*)"
        "Read"
        "Edit"
        "Write"
        "Glob"
        "Grep"
        "WebFetch"
        "WebSearch"
        "Agent"
        "NotebookEdit"
        "TaskCreate"
        "TaskGet"
        "TaskList"
        "TaskOutput"
        "TaskStop"
        "TaskUpdate"
        "Monitor"
        "CronCreate"
        "CronList"
        "CronDelete"
        "PushNotification"
        "RemoteTrigger"
        "LSP"
        "AskUserQuestion"
        "EnterPlanMode"
        "ExitPlanMode"
      ];
    in
    ''
      ${shell.jqEdit}
      settings="$HOME/.claude/settings.json"
      jq="${pkgs.jq}/bin/jq"
      desired='${builtins.toJSON allowList}'
      if [ -f "$settings" ]; then
        missing="$($jq --argjson d "$desired" \
          '($d - (.permissions.allow // [])) | length' "$settings" 2>/dev/null || echo 0)"
        if [ "$missing" != "0" ]; then
          claude_jq_edit "$settings" --argjson d "$desired" \
            '.permissions.allow = ((.permissions.allow // []) + ($d - (.permissions.allow // [])))'
          $VERBOSE_ECHO "Reconciled permissions.allow in $settings"
        fi
      fi
    ''
  );

  # Declaratively reconcile Auto Mode (permissions.defaultMode + the autoMode
  # policy block) in ~/.claude/settings.json, so every host running this
  # config (gaming, laptop, natalie-laptop — vpn-server has no home-manager
  # bosko user) starts up with the same Auto Mode ruleset instead of needing
  # a manual `/auto-mode-setup` pass per machine. Full-reconcile (like
  # claudeMcpServers in mcp.nix), not additive like claudeAllowList: autoMode is
  # canonical repo policy, so a divergent value gets overwritten back to this.
  # See memory `auto-mode-global` for why this lives here globally rather
  # than per-project.
  home.activation.claudeAutoMode = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    let
      # The policy is plain JSON, read back with `jq --slurpfile` rather than
      # interpolated into a shell single-quoted string: several entries contain
      # apostrophes (e.g. "this repo's stated normal flow") that would close
      # the quoting. Parsing it here too makes a syntax error fail the build
      # instead of silently no-op'ing at activation (jq's error is swallowed).
      autoModeFile = builtins.seq (builtins.fromJSON (builtins.readFile ./auto-mode.json)) ./auto-mode.json;
    in
    ''
      ${shell.jqEdit}
      settings="$HOME/.claude/settings.json"
      jq="${pkgs.jq}/bin/jq"
      desiredMode="auto"
      autoModeFile="${autoModeFile}"
      if [ -f "$settings" ]; then
        needs_update=0
        $jq -e --arg m "$desiredMode" \
          '.permissions.defaultMode == $m' "$settings" >/dev/null 2>&1 \
          || needs_update=1
        $jq -e --slurpfile d "$autoModeFile" \
          '.autoMode == $d[0]' "$settings" >/dev/null 2>&1 \
          || needs_update=1
        if [ "$needs_update" = "1" ]; then
          claude_jq_edit "$settings" --arg m "$desiredMode" --slurpfile d "$autoModeFile" \
            '.permissions.defaultMode = $m | .autoMode = $d[0]'
          $VERBOSE_ECHO "Reconciled Auto Mode defaultMode + policy in $settings"
        fi
      fi
    ''
  );
}
