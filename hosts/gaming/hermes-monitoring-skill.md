---
name: homelab-monitoring
description: "Status of the user's home network and machines (gaming, laptop, natalie-laptop, pi-hole, famdash, Jellyfin, internet). Use for any question about network health, whether something is down, alerts, disk, memory or failed services."
version: 1.0.0
author: managed by the user's NixOS config (hosts/gaming/monitoring.nix)
platforms: [linux]
metadata:
  hermes:
    tags: [Monitoring, Network, Prometheus]
prerequisites:
  commands: [hermes-monitor]
---

# Homelab monitoring (read-only)

A Prometheus stack on the gaming host watches the network. You can only read it, through one command.

## Commands

```bash
hermes-monitor status          # start here: target health + pending/firing alerts
hermes-monitor alerts          # alerts as JSON
hermes-monitor targets         # every scrape target as JSON
hermes-monitor query 'up'      # one PromQL instant query
```

Useful queries:

```bash
hermes-monitor query 'probe_success'                                           # 1 = reachable, 0 = down
hermes-monitor query '100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)'
hermes-monitor query 'node_load1'
hermes-monitor query 'nvidia_smi_memory_used_bytes / 1024 / 1024 / 1024'      # VRAM used, GiB (total: nvidia_smi_memory_total_bytes)
hermes-monitor query 'nvidia_smi_utilization_gpu_ratio'                        # 0..1
hermes-monitor query 'nvidia_smi_temperature_gpu'                              # degrees C
hermes-monitor query 'node_systemd_unit_state{state="failed"} == 1'
```

## What is watched

- **Pings:** pi-hole, famdash and the internet (1.1.1.1). **DNS lookups** through pi-hole. **Jellyfin** HTTP.
- **Host metrics** (CPU, memory, disk, failed systemd units) for gaming, laptop and natalie-laptop.
- **Gaming's GPU** (RTX 3070, 8 GB): VRAM, load, temperature, power draw. Check VRAM before the user starts the local LLM (it needs about 7.5 GB free).

## Reading the results

- The laptops are often switched off. A missing or stale laptop series is normal, not an outage.
- The monitoring stack runs on gaming, so it only sees things while gaming is on. It sends **no notifications**; you see alerts only when asked.
- `llama-cpp` being stopped is normal (the user starts it on demand) and is not a failed unit.
- If `hermes-monitor` can't connect, tell the user the monitoring stack is down. Don't try to start it.

## Safety rules

- This is read-only. Never restart services, edit config, run sudo, or try to reach Prometheus, Alertmanager or any exporter by any other route than `hermes-monitor`.
- Report what you observed and what you think it means. Suggest fixes as text for the user to apply. Say so when you're unsure.
- Don't save metric values or alert states to memory. They go stale within minutes.
