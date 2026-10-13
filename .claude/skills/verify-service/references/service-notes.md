# verify-service: per-service notes

Service-specific expectations behind the generic Step 2 rules in SKILL.md.

## Ports

- **Jellyfin** binds `0.0.0.0:8096` but is only reachable on `enp4s0` (LAN) + `tailscale0` (`wg0` is also allowed but its module is currently pulled) — the firewall scopes access per-interface, so the `0.0.0.0` bind is **fine**. Note this rather than flagging it.
- **qBittorrent** — the *GUI app* has no Web UI daemon, so there is **no listening socket by design**. Say "no listening port expected", not a FAIL.

## Mount and data-dir layout

- `/mnt/media` should be `/dev/sda1 ext4 rw`.
- Reference layout from this repo: `/mnt/media`, `/mnt/media/Movies`, `/mnt/media/Shows`, `/mnt/media/downloads` are all expected to be `bosko:media`, mode `2775` (setgid) so the `jellyfin` user (in the `media` group) can read manually-dropped files.
