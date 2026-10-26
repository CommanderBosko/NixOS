---
name: add-flatpak
description: Triggers when user says "add a flatpak", "install a flatpak", "add flatpak app", "add X as a flatpak", or "add X to flatpaks". Interactively adds a Flatpak app to either the shared declarative Flatpak list in modules/flatpak.nix (every desktop host) or a single host's list in its environment.nix, following the nix-flatpak module format used in this repo.
model: haiku
version: 0.2.0
---

# Add Flatpak App

Interactively add a Flatpak app to a declarative Flatpak list: the shared `services.flatpak.packages` list in `modules/flatpak.nix` (imported on every desktop host via `desktopModules` in `flake.nix`), or one desktop host's own list in its `environment.nix`. Follow all steps exactly — do not skip ahead.

## Arguments

Parse from the user's request:

- **`<app-id>`** (required) — the Flathub app ID in reverse-domain style, e.g. `com.spotify.Client`. If the user gave only a friendly name, the app ID still has to be resolved before proceeding (see Step 1).
- **`<host>`** (optional) — one of the **desktop hosts** (the hosts with `"desktop": true` in `.claude/hosts.json`). If omitted, ask in Step 1.

## Step 1 — Gather information

Ask the user the following (batch into one message if both are unknown). Do not proceed until you have both answers.

1. **App** — The app name or Flathub app ID (e.g. `com.spotify.Client`). If the user gave a name but no app ID, note that the Flathub app ID is required and suggest they check [flathub.org](https://flathub.org) to find it. The format is always `com.Publisher.AppName` or similar reverse-domain style.

2. **Host(s)** — Which host(s) to add it to. Valid desktop hosts are those with `"desktop": true` in `.claude/hosts.json`. If the user did not already name a host in their request, present this pick via the **AskUserQuestion tool** with one option per desktop host plus an `All desktop hosts` option, rather than asking in free-form prose. If the user already supplied the host, skip the question. If the user names a non-desktop host (`vpn-server`), stop and explain that headless hosts do not support Flatpak — do not proceed for those hosts.

## Step 2 — Check the shared list, pick the placement, read the target list

There are two places a Flatpak can go. Both are `services.flatpak.packages` lists, and NixOS
merges them, so a host gets the shared list plus its own extras:

- **Shared** — `modules/flatpak.nix`, imported into every desktop host via `desktopModules` in
  `flake.nix`.
- **Host-only** — the host's config file, its `envFile` in `.claude/hosts.json` (relative to the
  repo root `/home/bosko/NixOS`). For the desktop hosts this resolves to
  `hosts/<host>/environment.nix`.

**First, check whether the app is already listed anywhere:**

```bash
grep -nF '"<app-id>"' /home/bosko/NixOS/modules/flatpak.nix /home/bosko/NixOS/hosts/*/environment.nix
```

- Already in `modules/flatpak.nix` → it's already on every desktop host. Tell the user and stop.
- Already in a host's `environment.nix` → it's already on that host; drop that host from the
  request (and say so).

**Then pick the placement** via the **AskUserQuestion tool**, with two options:

- **Shared (every desktop host)** → `modules/flatpak.nix`. List this first if the user picked
  `All desktop hosts` (or more than one host) in Step 1.
- **Host-only** → each chosen host's `envFile`. List this first if the user picked a single host.

Skip the question if the user's request already made the placement clear ("on all my
desktops" → Shared; "just on laptop" → Host-only). If the user picks Shared and some hosts
already list the app host-only, offer to remove those now-redundant host entries in the same
change.

**Read the target file** and show the user the current `services.flatpak.packages` list and the
proposed new entry so they can confirm before any edit is made. Not every host has a host-only
list: if the host's `envFile` has no `services.flatpak.packages` block (check live — at the time
of writing only gaming's has one), show the new block that Step 4 will create instead.

## Step 3 — Confirm the addition

Present the exact line that will be added:

```
"com.Publisher.AppName" # App Name
```

Ask the user to confirm via the **AskUserQuestion tool**, with one option `Confirm` (write the entry) and one option `Cancel` (make no change), rather than free-form prose. Do not write anything until the user selects `Confirm`. If they gave only a bare app ID with no friendly name, use a shortened version of the app ID as the comment (e.g. `# AppName` from the last segment).

## Step 4 — Edit the file

Add the new entry to `services.flatpak.packages` in the target file chosen in Step 2 (`modules/flatpak.nix` or the host's `environment.nix`).

**Format rules (match exactly what is already in the file):**
- Entries are plain strings: `"com.Publisher.AppName"` — NOT attrsets with `appId`/`origin` fields.
- Each entry is followed by a `#` comment with the friendly app name.
- Match the indentation of the existing entries: 4 spaces in a host's `environment.nix` (2 for the outer block, 2 more for the list items), 6 in `modules/flatpak.nix` (its list sits inside a `services.flatpak = { … };` block).
- Append the new entry at the end of the list. The lists are **not** sorted (`modules/flatpak.nix` is in the order entries were added, not alphabetical by app ID or by comment), so don't try to insert alphabetically and don't reorder existing entries.
- Do not add a trailing comma after the last entry — Nix list syntax does not use commas.

**Example of correct format (from gaming/environment.nix):**

```nix
  services.flatpak.packages = [
    "com.albiononline.AlbionOnline" # Albion Online
  ];
```

**Host-only target with no `services.flatpak.packages` block yet:** create one as the last
top-level entry of the host's `environment.nix` (just before the closing `}`), using gaming's
block as the template:

```nix
  # Host-specific flatpaks, on top of the shared modules/flatpak.nix list
  services.flatpak.packages = [
    "com.Publisher.AppName" # App Name
  ];
```

Don't add `services.flatpak.enable` or anything else — `modules/flatpak.nix` already enables
Flatpak on every desktop host; the host block only adds entries to the merged list.

Use the Edit tool to insert the new line (or block) in the correct position. Do not rewrite the whole file — make a minimal, targeted edit.

## Step 5 — Remind the user of next steps

After the edit is written, tell the user:

1. Run `/nixos-dry-run` to preview the change before applying.
2. Run `/git-commit` to commit the change.

Do not stage or commit — that is handled by the `/git-commit` skill.

---

## Key constraints

- Only the `"desktop": true` hosts in `.claude/hosts.json` support Flatpak. Warn and stop if the user requests a headless host (`vpn-server`).
- The entry format is a bare string with an inline comment — never an attrset.
- 2-space indentation throughout the file; list entries match the existing entries' indentation (4 spaces in a host's `environment.nix`, 6 in `modules/flatpak.nix`).
- Always check `modules/flatpak.nix` before adding a host-only entry — an app in the shared list is already on every desktop host.
- Do not stage or commit changes — leave that to `/git-commit`.
- Do not add `origin = "flathub";` or any other attributes — the nix-flatpak module in this repo resolves origin from the plain string format automatically.
- If the user wants to add the same app to multiple hosts host-only, process each host's file in sequence, confirming each edit.
