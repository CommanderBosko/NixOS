# Herdr: terminal agent multiplexer (per-pane agent state for Claude Code, Codex,
# etc.). Desktop-only (desktopModules, not commonModules).
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    herdr
  ];

  # Panes inherit the herdr *server's* environment, and the server is usually
  # not started from the graphical session: a saved herdr machine on another
  # host reconnects over SSH within a minute of boot and starts the server
  # here, long before the niri login, so it has no WAYLAND_DISPLAY / DISPLAY.
  # Claude Code then can't read the clipboard (Ctrl+V image paste: wl-paste
  # needs WAYLAND_DISPLAY). A server unit ordered after graphical-session.target
  # would lose that race, so fix it per pane instead: niri imports its variables
  # into the systemd user manager, so a new pane shell copies them from there.
  # Only inside herdr panes, only when the graphical session exists, and never
  # overriding a WAYLAND_DISPLAY the pane already has.
  programs.zsh.interactiveShellInit = ''
    if [[ -n $HERDR_ENV && -z $WAYLAND_DISPLAY ]]; then
      local _hg_env _hg_line
      _hg_env=$(systemctl --user show-environment 2>/dev/null)
      if [[ $'\n'$_hg_env == *$'\nWAYLAND_DISPLAY='* ]]; then
        for _hg_line in ''${(f)_hg_env}; do
          case $_hg_line in
            WAYLAND_DISPLAY=*|DISPLAY=*|XDG_CURRENT_DESKTOP=*|XDG_SESSION_TYPE=*|NIRI_SOCKET=*)
              export "''${_hg_line%%=*}=''${_hg_line#*=}"
              ;;
          esac
        done
      fi
      unset _hg_env _hg_line
    fi
  '';
}
