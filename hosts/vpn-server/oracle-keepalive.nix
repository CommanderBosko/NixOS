{ pkgs, ... }:

{
  # Oracle reclaims Always Free compute instances that stay idle over a rolling
  # 7-day window — but only when the 95th-percentile CPU, network, AND memory
  # utilisation are ALL under 20% (memory applies to A1 ARM shapes). WireGuard
  # traffic is far too light to clear any of those bars on its own. Breaking the
  # AND on a single metric is enough, so this timer burns a capped CPU load for
  # 90 min/day: that keeps >5% of the week above 20% CPU, which pins the
  # 95th-percentile figure over the threshold. Nice 19 + idle scheduling means
  # it instantly yields to real VPN traffic and never affects latency.
  #
  # The definitive fix is upgrading the account to Pay As You Go, which exempts
  # it from idle reclamation entirely while staying within the free limits — but
  # this keep-alive covers the strictly-Always-Free case with no card on file.
  systemd.services.oracle-keepalive = {
    description = "Anti-idle CPU load so Oracle doesn't reclaim the Always Free VM";
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
      ExecStart = "${pkgs.stress-ng}/bin/stress-ng --cpu 0 --cpu-load 35 --timeout 90m";
    };
  };

  systemd.timers.oracle-keepalive = {
    description = "Daily anti-idle CPU load for Oracle Cloud reclamation avoidance";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };

  # Weekly reboot, offset 30m past oracle-keepalive's 03:00 run so a reboot
  # doesn't cut its 90m anti-idle stress-ng job short mid-run.
  systemd.services.weekly-reboot = {
    description = "Weekly scheduled reboot";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl reboot";
    };
  };

  systemd.timers.weekly-reboot = {
    description = "Weekly reboot every Sunday at 3:30AM";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 03:30:00";
      Persistent = false;
    };
  };
}
