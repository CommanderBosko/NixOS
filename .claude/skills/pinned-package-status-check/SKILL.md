---
name: pinned-package-status-check
description: Check whether a package tracked in the pinned-packages registry as held back pending an upstream fix has landed yet, and report whether the pin can be lifted. Use when the user says "check if the xwayland-satellite pin can be lifted", "has X been fixed upstream yet", "check pinned package status", "is the xwayland-satellite bug fixed yet", or "can we unpin X".
---

# Pinned Package Status Check

Given a package tracked in the pinned-packages registry as pinned/waived pending an upstream fix, check whether that fix has landed and report a lift/keep verdict. (Bucket: Data Enrichment)

## Arguments

- **package** (optional) — the specific pinned package to check (e.g. "xwayland-satellite"). If not given, list every `CURRENT` entry from the registry and ask which to check, or check all of them if the user asked generically ("check the pins").

## Steps

1. **Read the registry.** Find this project's memory dir (`~/.claude/skills/lib/find-transcript-dir.sh`) and read `memory/project_pinned_packages.md`. Locate the requested package's `CURRENT` entry: the version pinned, the mechanism, and the tracked upstream issue/PR URL. If the entry links to a dedicated narrative memory (e.g. `[[project_steam_dropdown_menu_bug]]`), read that too for the full removal condition.

2. **Check nixpkgs' current version.** Use the `nixos` MCP server (`nix_versions`, or `nix` with `action: info`) to get the package's current version in the channel this repo tracks, and compare it against the pinned version.

3. **Check the upstream issue/PR.** `WebFetch` the tracked URL from Step 1 — read its open/closed status and skim the latest comments for a fix landing, a maintainer confirmation, or a newer release called out as good.

4. **Report a verdict:**
   - **Fix landed** (issue closed, or a newer release is confirmed good) — recommend lifting the pin, and offer to hand off to `bump-input`/`pin-input` to actually do it.
   - **Still open** — keep the pin as-is; note anything new since the registry was last touched (a maintainer comment, an ETA, a workaround).

5. **If the verdict differs from what's recorded** in the registry (status flipped either direction since it was last checked), update the tracking memory via the `save-memory` skill — don't hand-edit the memory file directly.

6. **Report back:** the package checked, pinned vs. current upstream version, the issue's status, and the verdict (lift / keep).
