# Pi-hole v6 (FTL) with a local recursive unbound: the pi-hole host's DNS
# service, a replacement for a Raspberry Pi OS install.
#
# Query path: clients -> pihole-ftl (:53, filtering and cache) -> unbound
# (127.0.0.1:5335, recursive, DNSSEC-validating) -> the root and authoritative
# servers. Pi-hole's own DNSSEC stays off because unbound already validates.
#
# This file is only the services. Networking, nameservers, the firewall, Tailscale
# and the sops secrets belong to the host file (configuration.nix), which also
# sets services.pihole-ftl.openFirewall* and piHole.webEnvFile.
#
# Everything under services.pihole-ftl.settings and the list of blocklists is
# set with mkDefault, so a host or test can override a single key with a plain
# assignment instead of mkForce (without it a list such as dns.upstreams would be
# concatenated rather than replaced).
{ config, lib, pkgs, ... }:

let
  cfg = config.piHole;
  ftl = config.services.pihole-ftl;

  # Oneshot that blocks until chrony has set the clock, see below.
  clockWait = "pihole-wait-for-clock.service";

  # What FTL, its setup unit and gravity start after. time-sync.target alone
  # only means chronyd has started, not that it has stepped the clock, hence the
  # extra unit when chrony is in use.
  clockDeps = [ "time-sync.target" ] ++ lib.optional cfg.waitForClock clockWait;

  # Gravity (the blocklist rebuild) is batch work on a 1 GB board that also has
  # to answer DNS: it downloads ~25 lists and builds a ~2.3M-domain SQLite index,
  # which is the only thing here that can hurt FTL and unbound.
  #  - Nice, CPUWeight and IOSchedulingClass keep it behind them. Each systemd
  #    service has its own cgroup, so Nice alone does not order two services;
  #    CPUWeight does. The IO class is honoured by BFQ-style schedulers only and
  #    is harmless on the SD card's default one.
  #  - OOMScoreAdjust makes gravity the kernel's first victim under memory
  #    pressure instead of FTL or unbound. Only gravity is raised: protecting
  #    FTL would instead let a leak in it take sshd and tailscaled down first.
  #  - TimeoutStartSec is a ceiling for a stalled download (gravity's curl has a
  #    connect timeout but no total one). A normal run is minutes, and gravity.db
  #    is only replaced by an atomic move at the very end, so killing it is safe.
  #  - No MemoryHigh/MemoryMax: throttling or killing gravity part-way through an
  #    index build is worse than letting it use swap (zram, see the shared Pi
  #    module), and its peak is not measured here.
  gravityLimits = {
    Nice = 19;
    CPUWeight = 20;
    IOSchedulingClass = "idle";
    OOMScoreAdjust = 500;
    TimeoutStartSec = "30min";
  };
in
{
  options.piHole = {
    webEnvFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/pihole-web-env";
      description = ''
        Environment file added to pihole-ftl.service, for the dashboard password.
        FTL turns any FTLCONF_<key with dots as underscores> variable into a
        setting, so the file holds one line:
        FTLCONF_webserver_api_pwhash=<hash>. It keeps the hash out of the world
        readable Nix store and out of pihole.toml, which is a read-only store
        link. Point it at a sops secret. systemd reads it as root before dropping
        privileges and does not expand $ in it, so the hash needs no escaping.

        The file is required (no "-" prefix): with it missing FTL fails to start,
        which is loud, instead of coming up with an unauthenticated dashboard.
        While this is null the dashboard has no password at all.
        Restart pihole-ftl.service when the secret changes (sops
        restartUnits).
      '';
    };

    waitForClock = lib.mkOption {
      type = lib.types.bool;
      default = config.services.chrony.enable;
      defaultText = lib.literalExpression "config.services.chrony.enable";
      description = ''
        Hold FTL, its setup unit and gravity back until chrony has synchronised
        the clock (or 90 s have passed). The Pi has no RTC, so it boots with a
        clock years in the past: blocklist downloads would fail TLS validation
        ("certificate not yet valid") and FTL would write 1970s timestamps into
        its long-term query database. Needs chrony; turn it off on a host (or
        test) where the clock cannot sync.
      '';
    };

    gravitySchedule = lib.mkOption {
      type = lib.types.str;
      default = "Sun *-*-* 04:00:00";
      description = ''
        systemd calendar expression for the weekly gravity update (blocklist
        refresh), which replaces the old install's cron job. Persistent, so a
        run missed while the Pi was off happens at the next boot.
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion = !cfg.waitForClock || config.services.chrony.enable;
        message = "piHole.waitForClock needs services.chrony.enable (it runs chronyc waitsync).";
      }
    ];

    # --- Pi-hole -------------------------------------------------------------

    services.pihole-ftl = {
      enable = true;

      # Blocklists. Additive only, see adlists.nix.
      lists = lib.mkDefault (import ./adlists.nix);

      privacyLevel = lib.mkDefault 0; # show everything, as before

      # The values of the install this one replaces. Keys are FTL 6.9's real
      # names (the template shipped with nixpkgs is older); settings is not
      # validated, so a misspelt key is silently ignored. Several are also FTL's
      # own defaults and are pinned anyway, so a future FTL default change cannot
      # alter the household's DNS behaviour unnoticed.
      settings = lib.mapAttrsRecursive (_: lib.mkDefault) {
        dns = {
          # Local unbound, not a public resolver.
          upstreams = [ "127.0.0.1#5335" ];

          # ALL, not the default LOCAL: LOCAL only answers hosts on a subnet an
          # interface is attached to and silently drops queries from Tailscale's
          # point-to-point /32 addresses, which is how phones and laptops off the
          # LAN reach this resolver. Safe only because the firewall decides who can
          # reach port 53.
          listeningMode = "ALL";

          domain.name = "lan";
          blocking.mode = "NULL"; # blocked names answer 0.0.0.0 / ::
          dnssec = false; # unbound validates, validating twice only costs time
          queryLogging = true;
        };

        # FTL's long-term query database is pruned after this many days.
        database.maxDBdays = 91;

        # No NTP in FTL: chrony sets the clock (modules/desktop-networking.nix).
        # Two independent things: ntp.sync is FTL setting the system clock, and
        # ntp.ipv4/ipv6 is FTL serving NTP on UDP 123 to clients (default on).
        ntp = {
          sync.active = false;
          ipv4.active = false;
          ipv6.active = false;
        };

        webserver.interface.theme = "high-contrast-dark";
      };
    };

    # Dashboard and API. pihole-web also moves the dashboard to / (instead of
    # /admin/) and sets the web server's port list. The list is FTL's default,
    # spelled out because the NixOS module would otherwise leave the web server
    # off: o = skip a port that cannot be bound, s = TLS, the module's
    # self-signed certificate is created on first start.
    services.pihole-web = {
      enable = true;
      ports = lib.mkDefault [
        "80o"
        "443os"
        "[::]:80o"
        "[::]:443os"
      ];
    };

    # --- unbound -------------------------------------------------------------

    # Recursive resolver for FTL only: loopback, port 5335, IPv4 only (as on the
    # install this replaces). resolveLocalQueries stays off so unbound does not
    # take over /etc/resolv.conf; the host file decides what the box itself uses.
    # Passes unbound-checkconf (the module skips its own build-time check because
    # its default remote-control block is present, so it was run by hand).
    services.unbound = {
      enable = true;
      resolveLocalQueries = false;
      settings.server = {
        verbosity = 0;
        interface = [ "127.0.0.1" ];
        port = 5335;
        access-control = [ "127.0.0.0/8 allow" ];
        do-ip4 = true;
        do-udp = true;
        do-tcp = true;
        do-ip6 = false;
        prefer-ip6 = false;
        harden-glue = true;
        harden-dnssec-stripped = true;
        # Off: 0x20 randomisation breaks lookups for a few badly behaved
        # authoritative servers, and DNSSEC already covers what it protects.
        use-caps-for-id = false;
        # 1232 avoids IP fragmentation (DNS flag day 2020).
        edns-buffer-size = 1232;
        prefetch = true; # refresh popular cache entries before they expire
        # One thread and a 1 MB receive buffer: right-sized for a quad-core
        # board with 1 GB, and a household's query rate.
        num-threads = 1;
        so-rcvbuf = "1m";
        # Never let a public name resolve to a private address (DNS rebinding).
        private-address = [
          "192.168.0.0/16"
          "169.254.0.0/16"
          "172.16.0.0/12"
          "10.0.0.0/8"
          "fd00::/8"
          "fe80::/10"
        ];
      };
    };

    # --- Ordering and limits -------------------------------------------------

    systemd.services = {
      # chrony starts as soon as chronyd is up, long before it has the time, and
      # time-sync.target does not wait for that. waitsync returns once chronyd
      # has a source and the remaining correction is under 1 s (it steps a
      # years-wrong clock on the first sample: makestep in desktop-networking.nix),
      # checking every second, at most 90 times.
      #
      # The dependents only want and order after it, never require it: when it
      # times out (no network, NTP unreachable) it shows up as failed, but DNS
      # still comes up, which beats an outage. Ordering after chronyd also puts FTL
      # after nss-lookup.target and so after unbound; unbound is deliberately NOT
      # ordered after chrony, that would be a cycle (chronyd starts after
      # nss-lookup.target, which unbound is before).
      pihole-wait-for-clock = lib.mkIf cfg.waitForClock {
        description = "Wait for chrony to set the clock before Pi-hole starts";
        wants = [ "chronyd.service" ];
        after = [ "chronyd.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true; # a later FTL restart does not wait again
          ExecStart = "${config.services.chrony.package}/bin/chronyc -n waitsync 90 1 0 1";
          TimeoutStartSec = "2min";
          # Light sandbox. Not strict, as chronyc may bind a client socket under /run/chrony.
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "full";
        };
      };

      # FTL: after unbound so its first queries are not SERVFAIL, and after the
      # clock so its database does not get bogus timestamps. wants (not requires)
      # on unbound: FTL still starts and serves cached or blocked answers while
      # unbound is down.
      pihole-ftl = {
        after = [ "unbound.service" ] ++ clockDeps;
        wants = [ "unbound.service" ] ++ clockDeps;
        serviceConfig = lib.mkIf (cfg.webEnvFile != null) {
          EnvironmentFile = [ cfg.webEnvFile ];
        };
      };

      # The module's setup unit runs on every FTL start (every boot and every
      # config change): it registers the lists through the API and then runs
      # gravity, which resolves each list's host through FTL and downloads it over
      # TLS, hence unbound and the clock. FTL is already ordered before it.
      pihole-ftl-setup = {
        after = [ "unbound.service" ] ++ clockDeps;
        wants = [ "unbound.service" ] ++ clockDeps;
        serviceConfig = gravityLimits;
      };

      # Weekly blocklist refresh (the timer is below). Same user and sandbox as
      # the module's setup unit, whose upstream definition it mirrors: gravity
      # writes gravity.db and its list cache under the state directory and reads
      # the pihole.toml in /etc/pihole. It needs FTL up (it resolves list hosts
      # through it) but not the API: FTL notices the swapped gravity.db and
      # reloads it by itself, so no signal is sent.
      #
      # Ordered after the setup unit so the two never run gravity at once (both
      # write gravity.db_temp); a run of this unit during an FTL restart is
      # stopped by Requires= and is simply redone by the setup unit.
      pihole-gravity = {
        description = "Pi-hole gravity update (blocklist refresh)";
        after = [
          "network-online.target"
          "pihole-ftl.service"
          "pihole-ftl-setup.service"
          "unbound.service"
        ] ++ clockDeps;
        wants = [ "network-online.target" ] ++ clockDeps;
        requires = [ "pihole-ftl.service" ];
        serviceConfig = gravityLimits // {
          Type = "oneshot";
          User = ftl.user;
          Group = ftl.group;
          ExecStart = "${lib.getExe ftl.piholePackage} -g";

          # Hardening, as in the module's setup unit.
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          DevicePolicy = "closed";
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          ProtectControlGroups = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ReadWritePaths = [
            ftl.configDirectory
            ftl.stateDirectory
            ftl.logDirectory
          ];
          RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6 AF_NETLINK";
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          MemoryDenyWriteExecute = true;
          LockPersonality = true;
        };
      };
    };

    systemd.timers.pihole-gravity = {
      description = "Weekly Pi-hole gravity update";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.gravitySchedule;
        Persistent = true;
      };
    };
  };
}
