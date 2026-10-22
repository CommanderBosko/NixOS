{ config, pkgs, ... }:

# Vesktop outside the Proton VPN tunnel (gaming only).
#
# Why: Discord's edge answers browser-style API requests from Proton's exit
#      IPs with 403 / code 40333, so no messages load while the VPN is up
#      (checked on two exits, US-VA#190 and US-NY#672; the same requests from
#      the home IP return 200). Everything else stays on the VPN.
# How:  1. The `vesktop` binary is wrapped to start inside app-novpn.slice.
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
# Limits: new connections only — restart Vesktop after a rebuild. Discord
#         sees the home IP. The cgroup path is hard-wired to bosko's uid.
let
  uid = config.users.users.bosko.uid;
  slice = "app-novpn.slice";
  cgroupPath = "user.slice/user-${toString uid}.slice/user@${toString uid}.service/app.slice/${slice}";
  mark = "0x2000/0x2000";
  # After Tailscale's 5210–5270 rules so tailnet routes still win.
  rulePref = "5280";
  ip = "${pkgs.iproute2}/bin/ip";

  # Idempotent insert/append: the firewall re-runs extraCommands on reload,
  # so check before adding to avoid stacking duplicates.
  helpers = ''
    ipt_append() { local tool=$1 table=$2; shift 2; $tool -t "$table" -C "$@" 2>/dev/null || $tool -t "$table" -A "$@"; }
    ipt_insert() { local tool=$1 table=$2 chain=$3 pos=$4; shift 4; $tool -t "$table" -C "$chain" "$@" 2>/dev/null || $tool -t "$table" -I "$chain" "$pos" "$@"; }
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

  networking.firewall.extraCommands = ''
    ${helpers}

    # IPv4: mark the slice's packets, remember it on the connection.
    ipt_append iptables mangle OUTPUT -m cgroup --path ${cgroupPath} -j MARK --set-xmark ${mark}
    ipt_append iptables mangle OUTPUT -m mark --mark ${mark} -j CONNMARK --save-mark --nfmask 0x2000 --ctmask 0x2000
    # Replies skip the strict rpfilter (must sit above the nixos-fw-rpfilter jump).
    ipt_insert iptables mangle PREROUTING 1 -m connmark --mark ${mark} -j ACCEPT
    ipt_append iptables nat POSTROUTING -m mark --mark ${mark} ! -o lo -j MASQUERADE
    ${ip} rule del fwmark ${mark} lookup main pref ${rulePref} 2>/dev/null || true
    ${ip} rule add fwmark ${mark} lookup main pref ${rulePref}

    # IPv6: refuse so the app retries over IPv4.
    ipt_insert ip6tables filter OUTPUT 1 -m cgroup --path ${cgroupPath} ! -o lo -j REJECT --reject-with icmp6-adm-prohibited
  '';

  networking.firewall.extraStopCommands = ''
    iptables -t mangle -D OUTPUT -m cgroup --path ${cgroupPath} -j MARK --set-xmark ${mark} 2>/dev/null || true
    iptables -t mangle -D OUTPUT -m mark --mark ${mark} -j CONNMARK --save-mark --nfmask 0x2000 --ctmask 0x2000 2>/dev/null || true
    iptables -t mangle -D PREROUTING -m connmark --mark ${mark} -j ACCEPT 2>/dev/null || true
    iptables -t nat -D POSTROUTING -m mark --mark ${mark} ! -o lo -j MASQUERADE 2>/dev/null || true
    ${ip} rule del fwmark ${mark} lookup main pref ${rulePref} 2>/dev/null || true
    ip6tables -t filter -D OUTPUT -m cgroup --path ${cgroupPath} ! -o lo -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null || true
  '';
}
