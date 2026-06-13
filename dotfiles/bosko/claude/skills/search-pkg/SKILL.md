---
name: search-pkg
description: Triggers when user says "search for a package", "find a package", "look up a package", "search nixpkgs", "search-pkg", or "what's the package name for X". Searches nixpkgs for a package by name or keyword and presents clean, actionable output.
version: 0.1.0
---

# Search nixpkgs Workflow

Search nixpkgs for a package by name or keyword and present the results clearly so the user can act on them (e.g. with `/add-package`).

## Step 1 — Get the search query

If the user invoked `/search-pkg <query>`, use `<query>` directly. If no argument was given, ask:

> What package or keyword would you like to search for?

Do not proceed until you have a non-empty query string.

## Step 2 — Run the search

```bash
nix search nixpkgs#<query> 2>/dev/null
```

The `2>/dev/null` suppresses the evaluation progress spam that nix prints to stderr.

If the output exceeds 80 lines, truncate at 80 lines and note that results were cut off:

```bash
nix search nixpkgs#<query> 2>/dev/null | head -80
```

If the command returns no output (zero results), tell the user no packages matched and suggest:
- Trying a shorter or different keyword
- Checking spelling
- Searching on https://search.nixos.org

## Step 3 — Present the results

The raw output from `nix search` looks like:

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
- Do not guess attribute names — only report what `nix search` actually returns.
- `nix search` can be slow (10–30 s) on a cold cache; warn the user if it seems to be taking a while.
- This search always targets `nixpkgs` (the flake input), not a local overlay or a specific channel.
- Do not suggest packages from `nur` or other non-nixpkgs sources unless the user explicitly asks.
