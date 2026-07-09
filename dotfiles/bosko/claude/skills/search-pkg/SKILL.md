---
name: search-pkg
description: Triggers when user says "search for a package", "find a package", "look up a package", "search nixpkgs", "search-pkg", or "what's the package name for X". Searches nixpkgs for a package by name or keyword and presents clean, actionable output.
version: 0.1.0
---

# Search nixpkgs Workflow

Search nixpkgs for a package by name or keyword and present the results clearly so the user can act on them (e.g. with `/add-package`).

## Arguments

- **`<query>`** (optional) — the package name or keyword to search for, e.g. `/search-pkg firefox`. If omitted, Step 1 asks the user for it before proceeding.

## Step 1 — Get the search query

If the user invoked `/search-pkg <query>`, use `<query>` directly. If no argument was given, ask:

> What package or keyword would you like to search for?

Do not proceed until you have a non-empty query string.

## Step 2 — Run the search (PRIMARY: `nixos` MCP)

The `nixos` MCP server is the preferred path for every nixpkgs / option / version
question — it queries live APIs (search.nixos.org, NixHub) and is faster and more current
than `nix search`, which is slow (10–30 s) on a cold cache. **Use it first.**

```jsonc
// Package search — primary
mcp__nixos__nix  {"action":"search","query":"<query>","type":"packages"}
```

This returns attribute names, versions, and descriptions directly — no text munging needed.

For **version history** (which nixpkgs commit shipped version X, on which platforms), pair
it with:

```jsonc
mcp__nixos__nix_versions  {"package":"<name>","version":"<ver>"}
```

If the MCP returns no matches, tell the user no packages matched and suggest:
- Trying a shorter or different keyword
- Checking spelling
- Searching on https://search.nixos.org

### Offline fallback: `nix search`

Only when the `nixos` MCP is unavailable (offline, server down), fall back to the local
`nix search`. The mechanical part — run the search, strip the
`legacyPackages.<system>.` prefix, reformat each hit into a `pkgs.<name> (ver)` block, and
truncate to ~80 lines — is handled by the script:

```bash
scripts/search-pkg.sh "<query>"
```

It already emits the `Search results for "<query>":` header, the formatted blocks, and the
truncation note, so you can relay its output as-is. (The script suppresses nix's stderr
eval-progress spam and warns when results are cut off.) If you run `nix search` by hand
instead, the same formatting rules in Step 3 apply.

## Step 3 — Present the results

Whether the data came from the MCP or the fallback script, present it in this format. Raw
`nix search` output (what the fallback script consumes) looks like:

```
* legacyPackages.x86_64-linux.firefox (131.0)
  A web browser built from Firefox source tree

* legacyPackages.x86_64-linux.firefox-esr (128.5.1esr)
  Firefox Extended Support Release
```

Strip the `legacyPackages.x86_64-linux.` prefix from every attribute name. Present results in this format:

```
Search results for "<query>":

  pkgs.firefox (131.0)
  A web browser built from Firefox source tree

  pkgs.firefox-esr (128.5.1esr)
  Firefox Extended Support Release
```

Key formatting rules:
- Attribute names become `pkgs.<name>` — that is exactly what the user passes to `/add-package`.
- Show version in parentheses on the same line as the attribute name.
- Show description on the next line, indented.
- Separate each result with a blank line.
- If results were truncated, append: `(Results truncated — use a more specific query to narrow down.)`

## Step 4 — Next-step hint

After the results, always output this footer (substituting the real attribute name of the most relevant result if obvious):

```
To install a package, use /add-package and provide the pkgs.<name> attribute shown above.
```

---

## Key constraints

- Never run `nix build`, `nix-env`, or any command that writes to the store.
- Do not guess attribute names — only report what the `nixos` MCP (or the `nix search` fallback) actually returns.
- Prefer the `nixos` MCP; only reach for the `nix search` fallback when the MCP is unavailable. `nix search` can be slow (10–30 s) on a cold cache — that slowness is the reason the MCP is primary.
- This search always targets `nixpkgs` (the flake input), not a local overlay or a specific channel.
- Do not suggest packages from `nur` or other non-nixpkgs sources unless the user explicitly asks.
