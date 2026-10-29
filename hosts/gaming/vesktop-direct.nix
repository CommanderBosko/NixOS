{ config, pkgs, ... }:

# Vesktop outside the Proton VPN tunnel (gaming only).
#
# Why: Discord's edge answers browser-style API requests from Proton's exit
#      IPs with 403 / code 40333, so no messages load while the VPN is up
#      (checked on two exits, US-VA#190 and US-NY#672; the same requests from
#      the home IP return 200). Everything else stays on the VPN.
# How:  1. The `vesktop` binary is wrapped to start with primary group `novpn`
#          (via `sg`, which bosko may use without a password as a member).
#       2. Packets from sockets owned by that group get fwmark 0x2000 (mangle
#          OUTPUT), which an `ip rule` sends through the main table — i.e. out
#          the LAN instead of proton0 — and are masqueraded to the LAN
#          address, because the socket already picked proton0's source IP at
#          connect().
#       3. Replies come back on enp4s0 while the reverse route points at
#          proton0, so the NixOS firewall's strict rpfilter would drop them;
#          a PREROUTING exemption for connections carrying the mark avoids
#          loosening checkReversePath for the whole host.
#       4. IPv6 from the group is rejected so Chromium falls straight back
#          to IPv4 (Proton's v6 exit is blocked too, and there is no v6
#          route out the LAN while the VPN kill switch is up).
# Why a group and not a cgroup: Electron 43 moves its own process into a
#      fresh app-vesktop-<pid>.scope under app.slice (StartTransientUnit)
#      right after launch, which left app-novpn.slice empty and sent Vesktop
#      back through Proton (2026-10-29). The group is inherited by every
#      child and survives that move. It also drops the boot-time cgroup race
#      (`xt_cgroup: invalid path` took firewall.service down on 2026-10-23),
#      so the rules no longer wait for the user manager.
# Limits: new connections only — restart Vesktop after a rebuild. Discord
#         sees the home IP. Anything Vesktop spawns (a browser opened from a
#         link, if none is running) inherits the group and bypasses too, and
#         its files in ~/.config/vesktop are group novpn. Only bosko is a
#         member; other users get a plain, tunnelled Vesktop.
let
  group = "novpn";
  mark = "0x2000/0x2000";
  # After Tailscale's 5210–5270 rules so tailnet routes still win.
  rulePref = "5280";
  ip = "${pkgs.iproute2}/bin/ip";
  ipt = "${config.networking.firewall.package}/bin/iptables";
  ip6t = "${config.networking.firewall.package}/bin/ip6tables";

  # Removal tolerates absent rules, so `up` can start by clearing leftovers
  # (a reload, or rules from an older generation) and never stacks duplicates.
  down = pkgs.writeShellScript "vesktop-direct-down" ''
    ${ipt} -t mangle -D OUTPUT -m owner --gid-owner ${group} -j MARK --set-xmark ${mark} 2>/dev/null || true
    ${ipt} -t mangle -D OUTPUT -m mark --mark ${mark} -j CONNMARK --save-mark --nfmask 0x2000 --ctmask 0x2000 2>/dev/null || true
    ${ipt} -t mangle -D PREROUTING -m connmark --mark ${mark} -j ACCEPT 2>/dev/null || true
    ${ipt} -t nat -D POSTROUTING -m mark --mark ${mark} ! -o lo -j MASQUERADE 2>/dev/null || true
    ${ip} rule del fwmark ${mark} lookup main pref ${rulePref} 2>/dev/null || true
    ${ip6t} -t filter -D OUTPUT -m owner --gid-owner ${group} ! -o lo -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null || true
  '';

  up = pkgs.writeShellScript "vesktop-direct-up" ''
    set -eu
    ${down}

    # IPv4: mark the group's packets, remember it on the connection.
    ${ipt} -t mangle -A OUTPUT -m owner --gid-owner ${group} -j MARK --set-xmark ${mark}
    ${ipt} -t mangle -A OUTPUT -m mark --mark ${mark} -j CONNMARK --save-mark --nfmask 0x2000 --ctmask 0x2000
    # Replies skip the strict rpfilter (must sit above the nixos-fw-rpfilter jump).
    ${ipt} -t mangle -I PREROUTING 1 -m connmark --mark ${mark} -j ACCEPT
    ${ipt} -t nat -A POSTROUTING -m mark --mark ${mark} ! -o lo -j MASQUERADE
    ${ip} rule add fwmark ${mark} lookup main pref ${rulePref}

    # IPv6: refuse so the app retries over IPv4.
    ${ip6t} -t filter -I OUTPUT 1 -m owner --gid-owner ${group} ! -o lo -j REJECT --reject-with icmp6-adm-prohibited
  '';
in
{
  users.groups.${group} = { };
  users.users.bosko.extraGroups = [ group ];

  nixpkgs.overlays = [
    (final: prev: {
      vesktop =
        let
          launcher = prev.writeShellScript "vesktop-direct" ''
            # sg only works for group members; otherwise run as-is rather than
            # not at all.
            if /run/wrappers/bin/sg ${group} -c true 2>/dev/null; then
              exec /run/wrappers/bin/sg ${group} -c "exec ${prev.vesktop}/bin/vesktop $(printf '%q ' "$@")"
            fi
            exec ${prev.vesktop}/bin/vesktop "$@"
          '';
        in
        prev.symlinkJoin {
          name = "vesktop-direct-${prev.vesktop.version}";
          paths = [ prev.vesktop ];
          postBuild = ''
            rm $out/bin/vesktop
            ln -s ${launcher} $out/bin/vesktop
          '';
          meta = prev.vesktop.meta;
        };
    })
  ];

  systemd.services.vesktop-direct = {
    description = "Route group ${group} outside the Proton VPN tunnel";
    wantedBy = [ "multi-user.target" ];
    after = [ "firewall.service" ];
    # Re-apply when the firewall restarts or reloads, since both can drop or
    # reorder rules.
    partOf = [ "firewall.service" ];
    unitConfig.ReloadPropagatedFrom = "firewall.service";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = up;
      ExecReload = up;
      ExecStop = down;
    };
  };
}
