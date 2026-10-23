{ config, pkgs, ... }:

# Vesktop outside the Proton VPN tunnel (gaming only).
#
# Why: Discord's edge answers browser-style API requests from Proton's exit
#      IPs with 403 / code 40333, so no messages load while the VPN is up
#      (checked on two exits, US-VA#190 and US-NY#672; the same requests from
#      the home IP return 200). Everything else stays on the VPN.
# How:  1. The `vesktop` binary is wrapped to start inside app-novpn.slice,
#          which is a real user unit started at login (see below).
#       2. Packets from that cgroup get fwmark 0x2000 (mangle OUTPUT), which
#          an `ip rule` sends through the main table — i.e. out the LAN
#          instead of proton0 — and are masqueraded to the LAN address,
#          because the socket already picked proton0's source IP at connect().
#       3. Replies come back on enp4s0 while the reverse route points at
#          proton0, so the NixOS firewall's strict rpfilter would drop them;
#          a PREROUTING exemption for connections carrying the mark avoids
#          loosening checkReversePath for the whole host.
#       4. IPv6 from the slice is rejected so Chromium falls straight back
#          to IPv4 (Proton's v6 exit is blocked too, and there is no v6
#          route out the LAN while the VPN kill switch is up).
# Why a service and not firewall.extraCommands: xt_cgroup resolves the path
#      and pins that exact cgroup when the rule is added. At boot the firewall
#      starts ~15 s before the user manager creates the slice, so the rule
#      failed (`xt_cgroup: invalid path, errno=-2`) and took the whole
#      firewall.service down with it (2026-10-23). The slice must also live
#      for the whole session: a transient slice is removed when Vesktop exits,
#      and a rule pinned to the removed cgroup never matches its successor.
# Limits: new connections only — restart Vesktop after a rebuild. Discord
#         sees the home IP. The cgroup path is hard-wired to bosko's uid.
let
  uid = config.users.users.bosko.uid;
  userUnit = "user@${toString uid}.service";
  slice = "app-novpn.slice";
  cgroupPath = "user.slice/user-${toString uid}.slice/user@${toString uid}.service/app.slice/${slice}";
  mark = "0x2000/0x2000";
  # After Tailscale's 5210–5270 rules so tailnet routes still win.
  rulePref = "5280";
  ip = "${pkgs.iproute2}/bin/ip";
  ipt = "${config.networking.firewall.package}/bin/iptables";
  ip6t = "${config.networking.firewall.package}/bin/ip6tables";

  # Removal tolerates absent rules, so `up` can start by clearing leftovers
  # (a reload, or rules from an older generation) and never stacks duplicates.
  down = pkgs.writeShellScript "vesktop-direct-down" ''
    ${ipt} -t mangle -D OUTPUT -m cgroup --path ${cgroupPath} -j MARK --set-xmark ${mark} 2>/dev/null || true
    ${ipt} -t mangle -D OUTPUT -m mark --mark ${mark} -j CONNMARK --save-mark --nfmask 0x2000 --ctmask 0x2000 2>/dev/null || true
    ${ipt} -t mangle -D PREROUTING -m connmark --mark ${mark} -j ACCEPT 2>/dev/null || true
    ${ipt} -t nat -D POSTROUTING -m mark --mark ${mark} ! -o lo -j MASQUERADE 2>/dev/null || true
    ${ip} rule del fwmark ${mark} lookup main pref ${rulePref} 2>/dev/null || true
    ${ip6t} -t filter -D OUTPUT -m cgroup --path ${cgroupPath} ! -o lo -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null || true
  '';

  up = pkgs.writeShellScript "vesktop-direct-up" ''
    set -eu
    # The slice unit is started with the user manager; this only covers the
    # gap between the manager reporting ready and the cgroup showing up.
    for _ in $(seq 60); do
      [ -d /sys/fs/cgroup/${cgroupPath} ] && break
      sleep 1
    done
    [ -d /sys/fs/cgroup/${cgroupPath} ] || { echo "${slice} cgroup never appeared" >&2; exit 1; }

    ${down}

    # IPv4: mark the slice's packets, remember it on the connection.
    ${ipt} -t mangle -A OUTPUT -m cgroup --path ${cgroupPath} -j MARK --set-xmark ${mark}
    ${ipt} -t mangle -A OUTPUT -m mark --mark ${mark} -j CONNMARK --save-mark --nfmask 0x2000 --ctmask 0x2000
    # Replies skip the strict rpfilter (must sit above the nixos-fw-rpfilter jump).
    ${ipt} -t mangle -I PREROUTING 1 -m connmark --mark ${mark} -j ACCEPT
    ${ipt} -t nat -A POSTROUTING -m mark --mark ${mark} ! -o lo -j MASQUERADE
    ${ip} rule add fwmark ${mark} lookup main pref ${rulePref}

    # IPv6: refuse so the app retries over IPv4.
    ${ip6t} -t filter -I OUTPUT 1 -m cgroup --path ${cgroupPath} ! -o lo -j REJECT --reject-with icmp6-adm-prohibited
  '';
in
{
  # Pin the uid the cgroup path depends on. It is already 1000 (first normal
  # user); this just makes a change fail loudly instead of silently breaking.
  users.users.bosko.uid = 1000;

  nixpkgs.overlays = [
    (final: prev: {
      vesktop =
        let
          launcher = prev.writeShellScript "vesktop-direct" ''
            # Without a user bus (ssh, tty) systemd-run can't work; run as-is.
            if [ -S "''${XDG_RUNTIME_DIR:-/nonexistent}/bus" ]; then
              exec ${prev.systemd}/bin/systemd-run --user --scope --quiet \
                --slice=${slice} -- ${prev.vesktop}/bin/vesktop "$@"
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

  # Same cgroup path the transient slice used (app.slice/app-novpn.slice), but
  # started at login so it exists before the rules and outlives Vesktop.
  systemd.user.slices."app-novpn" = {
    description = "Apps that bypass the Proton VPN tunnel";
    wantedBy = [ "default.target" ];
  };

  systemd.services.vesktop-direct = {
    description = "Route app-novpn.slice outside the Proton VPN tunnel";
    wantedBy = [ userUnit ];
    after = [ "firewall.service" userUnit ];
    # Stop with the session (the slice's cgroup goes away) and re-apply when
    # the firewall restarts or reloads, since both can drop or reorder rules.
    partOf = [ "firewall.service" userUnit ];
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
