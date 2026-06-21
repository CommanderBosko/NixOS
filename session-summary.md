# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-06-20 (session 15) — `/create-loop` meta-skill

**Focus**: Build a global `/create-loop` skill that interviews the user and generates custom, self-orchestrating loop skills.

### What changed (and why)
- Added `dotfiles/bosko/claude/skills/create-loop/SKILL.md` and wired it into `bosko-claude.nix` (`b6e5d9d`). It's a *meta-skill*: it interviews for a loop's goal/steps/done-rule, then writes a project-local standalone loop to `.claude/skills/<loop>/SKILL.md` that runs as one command.
- Every generated loop has Loop Training Mode (top-of-file toggle, ON by default), a retry cap (default 3), dual-file per-run output (`output-<date>.md` + `memory-<date>.md` under `.claude/loops/<loop>/`), and a built-in verification plan.

### Decisions
- **Generated loops are project-local, not repo-global** — repo-global needs a rebuild per loop (read-only `/nix/store` symlinks); project-local is writable and instant. `/create-loop` itself stays global.
- **Loops are standalone/self-orchestrating**, not thin `/loop` wrappers — a loop is a complete, inspectable artifact; `/loop` can still wrap it for intervals.
- **Per-loop log dir** for the two output files, kept separate from the curated `~/.claude/.../memory/` system.

### Issues / surprises
- `nh os boot` can't run from the agent (no TTY for sudo) — the user activates. For an HM symlink-only change like this, `nh os switch` works with no reboot; a fresh session is needed before `/create-loop` resolves as a command.

### Next session
- Verify `/create-loop` resolves after `switch` + new session; run it once to generate a real loop and confirm the dual-file output + Training Mode behave as documented.

**Commits**: `b6e5d9d` (1 commit)

---

## Session: 2026-06-18 (session 14) — make the Parallelize rule actually trigger

**Focus**: Fix the `Parallelize with Sub-Agents` standing rule so it fires reliably instead of being silently ignored.

### What changed (and why)
- Rewrote the rule in both the repo `CLAUDE.md` and the global `claude-rules` skill source (`ea77515`). The old wording was an aspirational value with no trigger; the new version is a mandatory pre-task gate with concrete, observable trigger conditions.

### Decisions
- **Grant explicit standing authorization to spawn agents** ("you do not need to ask first") — the harness's built-in default is "don't spawn unless asked," which was silently suppressing the rule. The standing rule *is* the persistent ask, so make that explicit.
- **Trigger on independence, not file count** — multi-file edits here are usually coupled (module + its `flake.nix` import + `environment.nix`), which is correctly serial. Named that exception in the rule so it doesn't read as self-contradictory and get ignored wholesale.
- **Apply to both files** — `CLAUDE.md` for immediate effect in this repo; the skill canonical text so future projects inherit it (after a rebuild reaches `~/.claude`).

### Issues / surprises
- None. Docs-only change; no rebuild needed for the Markdown itself.

### Next session
- After the next `rebuild`, the strengthened `claude-rules` skill text reaches `~/.claude` — new projects then inherit the stronger wording.
- Observe whether parallelization actually fires more often in practice; tune the trigger wording if it over- or under-fires.

**Commits**: `ea77515` (1 commit)

---

## Session: 2026-06-17 (session 13) — nixpkgs-stable → 25.11; vpn-server redeployed

**Focus**: Move the EOL `nixos-25.05` stable input to current stable `nixos-25.11` and get vpn-server running on it.

### What changed (and why)
- **`nixpkgs-stable` bumped `nixos-25.05` → `nixos-25.11`** (`d2a245d`). 25.05 reached EOL; the live channels API confirmed 25.11 (Xantusia) is current stable (the proposed "26.05" doesn't exist yet). vpn-server is the only consumer; stateVersion was already 25.11.
- **`wg0 mtu = 1380` clamp** (`eb69c43`) — the Oracle tunnel path carries only ~1400-byte inner packets; wg-quick's default 1420 + black-holed PMTUD silently dropped full-size packets, corrupting large cache.nixos.org downloads. Fixed in shared `vpn.nix`.
- **`remote-rebuild` skill hardened** (`80c5b9c`, `8b3429e`) — `--use-remote-sudo` → `--elevate=sudo`, added `--build-host` for the aarch64 target, and a Gotchas section for the two failure modes below.
- **vpn-server redeployed to 25.11 via `boot` + reboot** and verified live (no failed units, forwarding/NAT/wg all healthy; user confirmed VPN works).

### Decisions
- **Deploy vpn-server with `boot` + reboot, not `switch`** — `switch` over SSH ties activation to the SSH pipe (`systemd-run --pipe`); the network restart drops SSH and corrupts the half-applied firewall/NAT. `boot` + reboot does a clean boot-time activation.
- **Rolled back via detached `systemd-run --collect`** to restore service fast, then redeployed — rather than debugging 25.11 live while the fleet was down.

### Issues / surprises
- The first `switch` deploy's `exit 255` (SSH drop mid-activation) — not a sudo issue — corrupted the firewall/NAT and took the whole VPN down. Static-diffing gen 17 vs gen 18 proved 25.11 was **not** the culprit (configs byte-identical bar store paths); the interrupted activation was.
- Rebooting vpn-server drops every client's WireGuard handshake — each client must restart `wg-quick-wg0`. Bit us mid-session when a push couldn't resolve DNS through a stale tunnel.
- Cross-arch: x86_64 laptop can't build the aarch64 closure → needs `--build-host`.

### Next session
- `rebuild` desktop clients (laptop first) to make `wg0 mtu = 1380` permanent.
- Continue pending laptop/natalie-laptop rebuild activations (Claude policy, Plasma, FinanceGuru).

**Commits**: `d2a245d..8b3429e` (4 commits)

---

## Session: 2026-06-17 (session 12) — promote nixos MCP server to user scope (reproducible)

**Focus**: Confirm the freshly-installed mcp-nixos server works post-reboot, then make it global and reproducible.

### What changed (and why)
- **Verified mcp-nixos is live** — after the reboot, a live `stats` call returned 134,973 packages, confirming the session-11 project-scoped server connects.
- **Promoted the server from project scope to user scope** (`f9a66e8`) so it's available in every project, not just this repo. `claude mcp add nixos mcp-nixos --scope user` writes the entry to `~/.claude.json`; the redundant project `.mcp.json` was `git rm`'d.
- **Made it reproducible** — added `home.activation.claudeMcpServers` to `dotfiles/bosko/bosko-claude.nix`: an idempotent jq reconcile of `.mcpServers.nixos` in `~/.claude.json` on every rebuild, mirroring the existing `claudeAllowList`/`claudeNixdPlugin` activation pattern. Repointed the `mcp-nixos` comment in `users.nix` at the new location.

### Decisions
- **Reconcile `~/.claude.json` with jq rather than symlink it read-only** — Claude Code rewrites that file constantly (auth, project history, toggles), so a `/nix/store` symlink would break it. The activation block touches only the single `.mcpServers.nixos` key, leaving everything else intact. Same trade-off already made for `settings.json` in this module.
- **User scope over project scope** — the value of live NixOS data isn't repo-specific; one global registration beats per-repo `.mcp.json` files.

### Issues / surprises
- None. Dry-run clean (1.80 KiB diff). The `enabledMcpjsonServers` entry in `.claude/settings.local.json` from session 11 is now a harmless no-op (it only gated the deleted `.mcp.json`).

### Next session
- It's global now via the `claude mcp add` write; a `rebuild` makes the activation block the source of truth (survives a `~/.claude.json` reset). No blocker.
- Standing backlog unchanged: laptop + natalie-laptop rebuild activations; interface-scope the Avahi mDNS firewall.

**Commits**: `f9a66e8` (1 commit)

---

## Session: 2026-06-17 (session 11) — wg-quick failure from leftover `::/0`; mcp-nixos server

**Focus**: A `rebuild` on gaming failed with `wg-quick-wg0.service` erroring out — diagnose and fix.

### What changed (and why)
- **Dropped `::/0` from the WireGuard peer's `allowedIPs` in `dotfiles/common/modules/vpn.nix`** (`2f67083`), leaving `[ "0.0.0.0/0" ]`. Session 10 disabled IPv6 but kept `::/0`; wg-quick installs a route per allowedIP, so `ip -6 route add ::/0 dev wg0` failed ("IPv6 is disabled on nexthop device") and wg-quick tore the interface down — the tunnel had been failing on every boot since session 10, not just warning. Added a `NOTE:` comment so `::/0` isn't re-added while IPv6 is off.
- **Added project-scoped mcp-nixos MCP server** (`720fe36`) — `pkgs.mcp-nixos` in bosko's packages + `.mcp.json` so Claude Code can query live NixOS package/option data; plus a routine `nix flake update` (`56983dd`). _(Both predate this conversation in the session-11 range.)_

### Decisions
- **The IPv6 disable and the `::/0` removal belong together** — this corrects session 10's recorded decision to keep `::/0`. With IPv6 off there's no stack to leak, so v4-only `0.0.0.0/0` is still a full tunnel. If IPv6 is ever restored on the server, flip `enableIPv6 = true` *and* re-add `::/0` as a pair, never one alone.

### Issues / surprises
- The rebuild "succeeded" (config activated) but reported the unit as failed — easy to misread as cosmetic. The journal's `ip link delete dev wg0` was the tell that the tunnel was actually down, not merely warning.

### Next session
- **gaming `rebuild` + reboot (user doing this next)** — then confirm `wg-quick-wg0` is *active* and the handshake is live (`/vpn-status`), and re-check Jellyfin artwork.
- Standing backlog unchanged: laptop + natalie-laptop rebuild activations; interface-scope the Avahi mDNS firewall.

**Commits**: `9c31511..2f67083` (3 commits: `56983dd`, `720fe36`, `2f67083`)

---
