{ hostsData, lib, pkgs, ... }:

# Network and host monitoring for the fleet — gaming only.
#
#   Prometheus     127.0.0.1:9090  scrapes the node exporters and blackbox probes, 30d retention
#   Alertmanager   127.0.0.1:9093  no receiver yet: alerts are only visible through Prometheus
#   blackbox       127.0.0.1:9115  ICMP / DNS / HTTP probes
#   nvidia-gpu     127.0.0.1:9835  VRAM, GPU load, temperature, power (gaming's RTX 3070)
#   node exporter  :9100           modules/node-exporter.nix (every desktop, tailscale0 only)
#
# Everything here binds to loopback, so nothing is reachable off the box. Hermes
# gets read-only access through `hermes-monitor` (below) and the skill in
# hermes-monitoring-skill.md. Gaming is a desktop, so the stack only watches
# while it's on. The laptops are scraped but deliberately have no "down" alert
# (they're often off); their series just go stale.
let
  hosts = hostsData.hosts;
  ts = name: hosts.${name}.tailscaleIp;

  # One scrape job per blackbox module. `host` is the label alerts and Hermes show.
  probeJob = { module, targets }: {
    job_name = "blackbox-${module}";
    metrics_path = "/probe";
    params.module = [ module ];
    static_configs = lib.mapAttrsToList (host: target: {
      targets = [ target ];
      labels.host = host;
    }) targets;
    relabel_configs = [
      { source_labels = [ "__address__" ]; target_label = "__param_target"; }
      { source_labels = [ "__param_target" ]; target_label = "instance"; }
      { target_label = "__address__"; replacement = "127.0.0.1:9115"; }
    ];
  };

  alertRules = {
    groups = [
      {
        name = "network";
        rules = [
          {
            alert = "NetworkProbeFailed";
            expr = ''probe_success{job="blackbox-icmp"} == 0'';
            "for" = "5m";
            labels.severity = "warning";
            annotations.summary = "{{ $labels.host }} does not answer ping";
          }
          {
            alert = "DnsProbeFailed";
            expr = ''probe_success{job="blackbox-dns_a"} == 0'';
            "for" = "5m";
            labels.severity = "critical";
            annotations.summary = "DNS lookups through {{ $labels.host }} are failing";
          }
          {
            alert = "ServiceDown";
            expr = ''probe_success{job="blackbox-http_2xx"} == 0'';
            "for" = "5m";
            labels.severity = "warning";
            annotations.summary = "{{ $labels.host }} is not answering HTTP";
          }
        ];
      }
      {
        name = "host";
        rules = [
          {
            alert = "DiskAlmostFull";
            expr = ''
              node_filesystem_avail_bytes{fstype=~"ext4|btrfs|xfs",mountpoint!="/nix/store"}
                / node_filesystem_size_bytes{fstype=~"ext4|btrfs|xfs",mountpoint!="/nix/store"} < 0.10
            '';
            "for" = "15m";
            labels.severity = "warning";
            annotations.summary = "{{ $labels.host }}: {{ $labels.mountpoint }} has under 10% free";
          }
          {
            alert = "MemoryLow";
            expr = "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.05";
            "for" = "10m";
            labels.severity = "warning";
            annotations.summary = "{{ $labels.host }} has under 5% memory available";
          }
          {
            alert = "GpuHot";
            expr = "nvidia_smi_temperature_gpu > 85";
            "for" = "5m";
            labels.severity = "warning";
            annotations.summary = "{{ $labels.host }} GPU is at {{ $value }}C";
          }
          {
            alert = "SystemdUnitFailed";
            expr = ''node_systemd_unit_state{state="failed"} == 1'';
            "for" = "5m";
            labels.severity = "warning";
            annotations.summary = "{{ $labels.host }}: {{ $labels.name }} has failed";
          }
        ];
      }
    ];
  };

  # The only way Hermes touches the stack: fixed subcommands, GET requests to
  # loopback, output capped to protect its 64K context. Read-only by
  # construction, so it doesn't depend on the model obeying a prompt.
  hermesMonitor = pkgs.writeShellApplication {
    name = "hermes-monitor";
    runtimeInputs = [ pkgs.curl pkgs.jq ];
    text = ''
      prom=http://127.0.0.1:9090
      limit=8000

      usage() {
        cat <<'EOF'
      hermes-monitor: read-only view of the homelab monitoring stack (Prometheus on gaming)

        hermes-monitor status         target health plus pending/firing alerts
        hermes-monitor alerts         pending/firing alerts as JSON
        hermes-monitor targets        every scrape target as JSON
        hermes-monitor query '<expr>' run one PromQL instant query (first 50 series)
      EOF
      }

      get() { curl -sS --max-time 20 "$@"; }

      emit() {
        local out
        out=$(cat)
        if [ "''${#out}" -gt "$limit" ]; then
          printf '%s\n[output truncated at %s chars]\n' "''${out:0:$limit}" "$limit"
        else
          printf '%s\n' "$out"
        fi
      }

      case "''${1:-}" in
        status)
          echo "== Targets (job, host, health, last error) =="
          get "$prom/api/v1/targets?state=active" \
            | jq -r '.data.activeTargets[] | [.labels.job, (.labels.host // .labels.instance), .health, .lastError] | @tsv' \
            | emit
          echo "== Alerts (name, host, state, since) =="
          get "$prom/api/v1/alerts" \
            | jq -r 'if (.data.alerts | length) == 0 then "none" else .data.alerts[] | [.labels.alertname, (.labels.host // .labels.instance // "-"), .state, .activeAt] | @tsv end' \
            | emit
          ;;
        alerts)
          get "$prom/api/v1/alerts" \
            | jq '.data.alerts | map({alert: .labels.alertname, host: (.labels.host // .labels.instance), state, since: .activeAt, summary: .annotations.summary})' \
            | emit
          ;;
        targets)
          get "$prom/api/v1/targets?state=active" \
            | jq '.data.activeTargets | map({job: .labels.job, host: (.labels.host // .labels.instance), health, lastError})' \
            | emit
          ;;
        query)
          [ "$#" -ge 2 ] || { usage; exit 2; }
          get -G "$prom/api/v1/query" --data-urlencode "query=$2" \
            | jq -c 'if .status != "success" then {error: .error} else (.data.result | if (.[0] | type) == "object" then .[:50] | map({metric, value: .value[1]}) else . end) end' \
            | emit
          ;;
        *)
          usage
          exit 2
          ;;
      esac
    '';
  };
in
{
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    retentionTime = "30d";
    globalConfig = {
      scrape_interval = "30s";
      evaluation_interval = "30s";
    };

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          { targets = [ "127.0.0.1:9100" ]; labels.host = "gaming"; }
          { targets = [ "${ts "laptop"}:9100" ]; labels.host = "laptop"; }
          { targets = [ "${ts "natalie-laptop"}:9100" ]; labels.host = "natalie-laptop"; }
        ];
      }
      {
        job_name = "nvidia";
        static_configs = [ { targets = [ "127.0.0.1:9835" ]; labels.host = "gaming"; } ];
      }
      (probeJob {
        module = "icmp";
        targets = {
          pi-hole = ts "pi-hole";
          famdash = ts "famdash";
          internet = "1.1.1.1";
        };
      })
      (probeJob {
        module = "dns_a";
        targets.pi-hole = ts "pi-hole";
      })
      (probeJob {
        module = "http_2xx";
        targets.jellyfin = "http://127.0.0.1:8096/health";
      })
    ];

    rules = [ (builtins.toJSON alertRules) ];

    alertmanagers = [ { static_configs = [ { targets = [ "127.0.0.1:9093" ]; } ]; } ];

    # No notifications yet: a Discord receiver needs a sops-managed webhook URL.
    alertmanager = {
      enable = true;
      listenAddress = "127.0.0.1";
      configuration = {
        route = {
          receiver = "none";
          group_by = [ "alertname" "host" ];
        };
        receivers = [ { name = "none"; } ];
      };
    };

    exporters.nvidia-gpu = {
      enable = true;
      # The module already points at the running driver's nvidia-smi.
      listenAddress = "127.0.0.1";
    };

    exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
      configFile = pkgs.writeText "blackbox.yml" (builtins.toJSON {
        modules = {
          icmp = {
            prober = "icmp";
            timeout = "5s";
            icmp.preferred_ip_protocol = "ip4";
          };
          dns_a = {
            prober = "dns";
            timeout = "5s";
            dns = {
              query_name = "nixos.org";
              query_type = "A";
              preferred_ip_protocol = "ip4";
            };
          };
          http_2xx = {
            prober = "http";
            timeout = "5s";
            http.preferred_ip_protocol = "ip4";
          };
        };
      });
    };
  };

  environment.systemPackages = [ hermesMonitor ];
}
